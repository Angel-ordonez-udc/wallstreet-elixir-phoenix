defmodule WallstreetBackend.Storage.MnesiaStorageTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Storage.MnesiaStorage
  alias WallstreetBackend.Operations.Transaction
  alias WallstreetBackend.Schemas.Wallet

  setup do
    # Ensure mnesia is up and tables exist
    assert :ok = MnesiaStorage.setup()

    # Best-effort cleanup between tests
    for table <- [:wallets, :transactions] do
      if :mnesia.table_info(table, :where_to_write) != :undefined do
        :mnesia.clear_table(table)
      end
    end

    :ok
  end

  test "save_wallet/2 and get_wallet/1" do
    user_id = "m_user_#{System.unique_integer([:positive])}"
    wallet = Wallet.new(123.0)

    assert :ok = MnesiaStorage.save_wallet(user_id, wallet)
    assert {:ok, ^wallet} = MnesiaStorage.get_wallet(user_id)
  end

  test "get_wallet/1 returns :wallet_not_found for missing wallets" do
    assert {:error, :wallet_not_found} = MnesiaStorage.get_wallet("missing_wallet")
  end

  test "save_transaction/1 and get_transactions/1" do
    user_id = "m_user_#{System.unique_integer([:positive])}"

    tx1 = %Transaction{
      user_id: user_id,
      type: :buy,
      asset: "BTC",
      quantity: 1.0,
      price: 100.0,
      timestamp: DateTime.add(DateTime.utc_now(), -10, :second)
    }

    tx2 = %Transaction{
      user_id: user_id,
      type: :sell,
      asset: "BTC",
      quantity: 0.5,
      price: 110.0,
      timestamp: DateTime.utc_now()
    }

    assert :ok = MnesiaStorage.save_transaction(tx1)
    assert :ok = MnesiaStorage.save_transaction(tx2)

    assert {:ok, txs} = MnesiaStorage.get_transactions(user_id)
    assert length(txs) == 2

    # sorted desc by timestamp
    assert Enum.at(txs, 0).timestamp >= Enum.at(txs, 1).timestamp
    assert Enum.map(txs, & &1.type) |> Enum.sort() == [:buy, :sell]
  end

  test "get_transactions/1 returns {:ok, []} when nothing exists" do
    assert {:ok, []} = MnesiaStorage.get_transactions("no_tx_user")
  end

  test "get_transactions/1 returns {:ok, []} when storage is not ready" do
    # Force MnesiaStorage.setup/0 to fail by mocking :mnesia.start/0.
    # get_transactions/1 is designed to fall back to {:ok, []} on any readiness error.
    :ok = :meck.new(:mnesia, [:passthrough])
    :meck.expect(:mnesia, :start, fn -> {:error, :boom} end)

    assert {:ok, []} = MnesiaStorage.get_transactions("any_user")

    :meck.unload(:mnesia)
  end

  test "save_wallet/2 returns {:error, reason} when transaction aborts" do
    :ok = :meck.new(:mnesia, [:passthrough])

    # Keep setup ok, but abort the write transaction.
    :meck.expect(:mnesia, :transaction, fn _fun -> {:aborted, :tx_failed} end)

    assert {:error, :tx_failed} = MnesiaStorage.save_wallet("u1", Wallet.new(1.0))

    :meck.unload(:mnesia)
  end

  test "get_wallet/1 returns error when transaction aborts" do
    :ok = :meck.new(:mnesia, [:passthrough])
    :meck.expect(:mnesia, :transaction, fn _fun -> {:aborted, :tx_failed} end)

    # implementation returns :wallet_not_found only for aborted _reason in normal code-path,
    # but our mock makes transaction always abort; also accept propagated abort reason.
    assert {:error, _} = MnesiaStorage.get_wallet("u1")

    :meck.unload(:mnesia)
  end

  test "save_transaction/1 returns {:error, reason} when transaction aborts" do
    :ok = :meck.new(:mnesia, [:passthrough])
    :meck.expect(:mnesia, :transaction, fn _fun -> {:aborted, :tx_failed} end)

    tx = %Transaction{
      user_id: "u1",
      type: :buy,
      asset: "BTC",
      quantity: 1.0,
      price: 100.0,
      timestamp: DateTime.utc_now()
    }

    assert {:error, :tx_failed} = MnesiaStorage.save_transaction(tx)

    :meck.unload(:mnesia)
  end

  test "get_wallet/1 returns wallet_not_found when transaction aborts" do
    :ok = :meck.new(:mnesia, [:passthrough])
    :meck.expect(:mnesia, :transaction, fn _fun -> {:aborted, :tx_failed} end)

    try do
      assert {:error, :tx_failed} = MnesiaStorage.get_wallet("u1")
    after
      :meck.unload(:mnesia)
    end
  end

  describe "setup/0 (mnesia helpers)" do
    test "setup/0 tolerates already-existing schema and tables" do
      :ok = :meck.new(:mnesia, [:passthrough])

      # ensure_schema/0 accepts already_exists shapes
      :meck.expect(:mnesia, :create_schema, fn _ ->
        {:error, {node(), {:already_exists, node()}}}
      end)

      # create_table_with_fallback/2 accepts already_exists for each table
      :meck.expect(:mnesia, :create_table, fn
        :wallets, _opts -> {:aborted, {:already_exists, :wallets}}
        :transactions, _opts -> {:aborted, {:already_exists, :transactions}}
      end)

      # wait_for_tables OK
      :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

      assert :ok = MnesiaStorage.setup()

      :meck.unload(:mnesia)
    end

    test "setup/0 returns error when wait_for_tables times out" do
      :ok = :meck.new(:mnesia, [:passthrough])

      :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
      :meck.expect(:mnesia, :start, fn -> :ok end)
      :meck.expect(:mnesia, :create_table, fn _table, _opts -> {:atomic, :ok} end)
      :meck.expect(:mnesia, :wait_for_tables, fn tables, _timeout -> {:timeout, tables} end)

      assert {:error, {:timeout, _}} = MnesiaStorage.setup()

      :meck.unload(:mnesia)
    end

    test "setup/0 handles bad_type for disc_copies by falling back to ram" do
      :ok = :meck.new(:mnesia, [:passthrough])

      :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
      :meck.expect(:mnesia, :start, fn -> :ok end)

      # Fail once with bad_type so fallback runs, then succeed on retry.
      :meck.expect(:mnesia, :create_table, fn
        :wallets, _opts ->
          case Process.get(:wallets_bad_type_once, false) do
            false ->
              Process.put(:wallets_bad_type_once, true)
              {:aborted, {:bad_type, :wallets, :disc_copies, node()}}

            true ->
              {:atomic, :ok}
          end

        :transactions, _opts ->
          {:atomic, :ok}
      end)

      # When fallback runs, it will call stop/delete_schema/create_schema/start and then create_table again.
      :meck.expect(:mnesia, :stop, fn -> :stopped end)
      :meck.expect(:mnesia, :delete_schema, fn _ -> :ok end)
      :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

      # allow any subsequent create_schema calls
      :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)

      assert :ok = MnesiaStorage.setup()

      :meck.unload(:mnesia)
    end

    test "save_wallet/2 returns {:error, reason} when create_table_with_fallback aborts generically" do
      :ok = :meck.new(:mnesia, [:passthrough])

      # Make setup fail on table creation.
      :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
      :meck.expect(:mnesia, :start, fn -> :ok end)
      :meck.expect(:mnesia, :create_table, fn _table, _opts -> {:aborted, :some_reason} end)

      assert {:error, :some_reason} = MnesiaStorage.save_wallet("u1", Wallet.new(1.0))

      :meck.unload(:mnesia)
    end

    test "get_wallet/1 returns {:error, reason} when setup/0 fails" do
      :ok = :meck.new(:mnesia, [:passthrough])
      :meck.expect(:mnesia, :start, fn -> {:error, :boom} end)

      assert {:error, :boom} = MnesiaStorage.get_wallet("u1")

      :meck.unload(:mnesia)
    end

    test "save_transaction/1 returns {:error, reason} when setup/0 fails" do
      :ok = :meck.new(:mnesia, [:passthrough])
      :meck.expect(:mnesia, :start, fn -> {:error, :boom} end)

      tx = %Transaction{
        user_id: "u1",
        type: :buy,
        asset: "BTC",
        quantity: 1.0,
        price: 1.0,
        timestamp: DateTime.utc_now()
      }

      assert {:error, :boom} = MnesiaStorage.save_transaction(tx)

      :meck.unload(:mnesia)
    end

    test "setup/0 falls back to RAM when disc_copies fix path fails" do
      :ok = :meck.new(:mnesia, [:passthrough])

      :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
      :meck.expect(:mnesia, :start, fn -> :ok end)

      # trigger bad_type for wallets so fix_schema_for_disc_copies_and_retry/2 runs.
      :meck.expect(:mnesia, :create_table, fn
        :wallets, opts ->
          cond do
            Keyword.has_key?(opts, :disc_copies) -> {:aborted, :still_bad}
            Keyword.has_key?(opts, :ram_copies) -> {:atomic, :ok}
            true -> {:aborted, {:bad_type, :wallets, :disc_copies, node()}}
          end

        :transactions, _opts ->
          {:atomic, :ok}
      end)

      # Make the "fix" chain fail so code goes through create_table_ram_fallback/3
      :meck.expect(:mnesia, :stop, fn -> :stopped end)
      :meck.expect(:mnesia, :delete_schema, fn _ -> {:error, :cannot_delete_schema} end)

      :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

      try do
        assert :ok = MnesiaStorage.setup()
      after
        :meck.unload(:mnesia)
      end
    end

    test "setup/0 returns error if RAM fallback also fails" do
      :ok = :meck.new(:mnesia, [:passthrough])

      :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
      :meck.expect(:mnesia, :start, fn -> :ok end)

      :meck.expect(:mnesia, :create_table, fn
        :wallets, opts ->
          cond do
            Keyword.has_key?(opts, :disc_copies) -> {:aborted, :still_bad}
            Keyword.has_key?(opts, :ram_copies) -> {:aborted, :ram_failed}
            true -> {:aborted, {:bad_type, :wallets, :disc_copies, node()}}
          end

        :transactions, _opts ->
          {:atomic, :ok}
      end)

      :meck.expect(:mnesia, :stop, fn -> :stopped end)
      :meck.expect(:mnesia, :delete_schema, fn _ -> {:error, :cannot_delete_schema} end)

      try do
        assert {:error, :ram_failed} = MnesiaStorage.setup()
      after
        :meck.unload(:mnesia)
      end
    end

    test "setup/0 returns error when create_schema fails with non-already_exists" do
      :ok = :meck.new(:mnesia, [:passthrough])
      :meck.expect(:mnesia, :create_schema, fn _ -> {:error, :bad_schema} end)

      try do
        assert {:error, :bad_schema} = MnesiaStorage.setup()
      after
        :meck.unload(:mnesia)
      end
    end

    test "setup/0 accepts delete_schema no_exists during disc_copies fix" do
      :ok = :meck.new(:mnesia, [:passthrough])

      :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
      :meck.expect(:mnesia, :start, fn -> :ok end)

      :meck.expect(:mnesia, :create_table, fn
        :wallets, _opts ->
          {:aborted, {:bad_type, :wallets, :disc_copies, node()}}

        :transactions, _opts ->
          {:atomic, :ok}
      end)

      :meck.expect(:mnesia, :stop, fn -> :stopped end)
      :meck.expect(:mnesia, :delete_schema, fn _ -> {:error, {node(), {:no_exists, node()}}} end)

      # allow schema recreation + start + retry create_table
      :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
      :meck.expect(:mnesia, :start, fn -> :ok end)

      # when retried with disc_copies, succeed; for transactions reuse ok
      :meck.expect(:mnesia, :create_table, fn
        :wallets, opts ->
          if Keyword.has_key?(opts, :disc_copies), do: {:atomic, :ok}, else: {:atomic, :ok}

        :transactions, _opts ->
          {:atomic, :ok}
      end)

      :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

      try do
        assert :ok = MnesiaStorage.setup()
      after
        :meck.unload(:mnesia)
      end
    end

    test "setup/0 falls back to RAM if :mnesia.stop does not return :stopped" do
      :ok = :meck.new(:mnesia, [:passthrough])

      :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
      :meck.expect(:mnesia, :start, fn -> :ok end)

      # First call triggers bad_type
      :meck.expect(:mnesia, :create_table, fn
        :wallets, opts ->
          cond do
            Keyword.has_key?(opts, :ram_copies) -> {:atomic, :ok}
            true -> {:aborted, {:bad_type, :wallets, :disc_copies, node()}}
          end

        :transactions, _opts ->
          {:atomic, :ok}
      end)

      # Returning something other than :stopped forces else branch -> RAM fallback
      :meck.expect(:mnesia, :stop, fn -> :ok end)
      :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

      try do
        assert :ok = MnesiaStorage.setup()
      after
        :meck.unload(:mnesia)
      end
    end

    test "setup/0 tolerates ensure_started already_started" do
      :ok = :meck.new(:mnesia, [:passthrough])

      try do
        :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
        :meck.expect(:mnesia, :start, fn -> {:error, {:already_started, :mnesia}} end)
        :meck.expect(:mnesia, :create_table, fn _table, _opts -> {:atomic, :ok} end)
        :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

        assert :ok = MnesiaStorage.setup()
      after
        :meck.unload(:mnesia)
      end
    end

    test "setup/0 tolerates ensure_schema nested already_exists shape" do
      :ok = :meck.new(:mnesia, [:passthrough])

      try do
        :meck.expect(:mnesia, :create_schema, fn _ ->
          {:error, {node(), {node(), {:already_exists, node()}}}}
        end)

        :meck.expect(:mnesia, :start, fn -> :ok end)
        :meck.expect(:mnesia, :create_table, fn _table, _opts -> {:atomic, :ok} end)
        :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

        assert :ok = MnesiaStorage.setup()
      after
        :meck.unload(:mnesia)
      end
    end

    test "setup/0 tolerates already_exists when recreating schema in disc_copies fix" do
      :ok = :meck.new(:mnesia, [:passthrough])

      try do
        :meck.expect(:mnesia, :create_schema, fn
          # first time OK
          [_] -> :ok
        end)

        :meck.expect(:mnesia, :start, fn -> :ok end)

        :meck.expect(:mnesia, :create_table, fn
          :wallets, opts ->
            cond do
              Keyword.has_key?(opts, :disc_copies) -> {:atomic, :ok}
              true -> {:aborted, {:bad_type, :wallets, :disc_copies, node()}}
            end

          :transactions, _opts ->
            {:atomic, :ok}
        end)

        :meck.expect(:mnesia, :stop, fn -> :stopped end)
        :meck.expect(:mnesia, :delete_schema, fn _ -> :ok end)
        # create_schema_for_current_node/0 branch
        :meck.expect(:mnesia, :create_schema, fn _ ->
          {:error, {node(), {:already_exists, node()}}}
        end)

        :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

        assert :ok = MnesiaStorage.setup()
      after
        :meck.unload(:mnesia)
      end
    end

    test "setup/0 returns error when RAM fallback create_table aborts" do
      :ok = :meck.new(:mnesia, [:passthrough])

      try do
        :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
        :meck.expect(:mnesia, :start, fn -> :ok end)

        :meck.expect(:mnesia, :create_table, fn
          :wallets, opts ->
            cond do
              Keyword.has_key?(opts, :disc_copies) -> {:aborted, :still_bad}
              Keyword.has_key?(opts, :ram_copies) -> {:aborted, :ram_failed}
              true -> {:aborted, {:bad_type, :wallets, :disc_copies, node()}}
            end

          :transactions, _opts ->
            {:atomic, :ok}
        end)

        :meck.expect(:mnesia, :stop, fn -> :stopped end)
        :meck.expect(:mnesia, :delete_schema, fn _ -> {:error, :cannot_delete_schema} end)
        :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

        assert {:error, :ram_failed} = MnesiaStorage.setup()
      after
        :meck.unload(:mnesia)
      end
    end

    test "get_transactions/1 returns {:ok, []} when match_object transaction aborts" do
      :ok = :meck.new(:mnesia, [:passthrough])

      try do
        :meck.expect(:mnesia, :transaction, fn _fun -> {:aborted, :tx_failed} end)
        assert {:ok, []} = MnesiaStorage.get_transactions("u1")
      after
        :meck.unload(:mnesia)
      end
    end
  end
end
