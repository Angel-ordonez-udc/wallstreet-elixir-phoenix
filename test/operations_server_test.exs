defmodule WallstreetBackend.Operations.OperationsServerTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Directorio
  alias WallstreetBackend.Repo
  alias WallstreetBackend.Operations.OperationsServer

  setup do
    user_id = "ops_user_#{System.unique_integer([:positive])}"
    credentials = %{"password" => "ops-pass"}

    :ok = Directorio.register(user_id, credentials)
    {:ok, _pid} = Directorio.login(user_id, credentials)

    # Set an initial market price for BTC so buy/sell can work deterministically
    :ok = Repo.update_market_price("BTC", 100.0)

    on_exit(fn ->
      _ = Directorio.logout(user_id)
    end)

    %{user_id: user_id}
  end

  test "returns empty transaction history for new user", %{user_id: user_id} do
    assert {:ok, []} = Directorio.transaction_history(user_id)
  end

  test "buy succeeds, updates wallet and creates a transaction", %{user_id: user_id} do
    assert {:ok, tx} = Directorio.buy(user_id, "BTC", 1)
    assert tx.type == :buy
    assert tx.asset == "BTC"
    assert tx.quantity == 1
    assert tx.price == 100.0

    assert {:ok, wallet} = Repo.get_wallet(user_id)
    assert wallet.balance < 10_000.0

    assert {:ok, history} = Directorio.transaction_history(user_id)
    assert length(history) >= 1
  end

  test "buy fails with insufficient funds when total cost exceeds balance", %{user_id: user_id} do
    # 1 BTC costs 1_000_000 => should exceed default 10_000
    :ok = Repo.update_market_price("BTC", 1_000_000.0)
    assert {:error, :insufficient_funds} = Directorio.buy(user_id, "BTC", 1)
  end

  test "sell fails when asset is not in wallet", %{user_id: user_id} do
    assert {:error, :asset_not_found} = Directorio.sell(user_id, "BTC", 1)
  end

  test "sell succeeds after buy and creates a sell transaction", %{user_id: user_id} do
    assert {:ok, _buy_tx} = Directorio.buy(user_id, "BTC", 1)
    assert {:ok, sell_tx} = Directorio.sell(user_id, "BTC", 1)

    assert sell_tx.type == :sell
    assert sell_tx.asset == "BTC"

    assert {:ok, history} = Directorio.transaction_history(user_id)
    assert Enum.count(history) >= 2
  end

  test "buy fails with invalid quantity", %{user_id: user_id} do
    assert {:error, :invalid_quantity} = Directorio.buy(user_id, "BTC", 0)
    assert {:error, :invalid_quantity} = Directorio.buy(user_id, "BTC", -1)
  end

  test "sell fails with invalid quantity", %{user_id: user_id} do
    assert {:error, :invalid_quantity} = Directorio.sell(user_id, "BTC", 0)
    assert {:error, :invalid_quantity} = Directorio.sell(user_id, "BTC", -1)
  end

  test "transaction history remains empty after failed operations", %{user_id: user_id} do
    assert {:error, :invalid_quantity} = Directorio.buy(user_id, "BTC", 0)
    assert {:error, :asset_not_found} = Directorio.sell(user_id, "BTC", 1)
    assert {:ok, []} = Directorio.transaction_history(user_id)
  end

  describe "OperationsServer direct API (branch coverage)" do
    test "status/0 returns :ok" do
      assert :ok = OperationsServer.status()
    end

    test "buy/3 propagates get_market_price error" do
      user_id = "ops_user_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      assert {:ok, _pid} = Directorio.login(user_id, creds)

      :ok = :meck.new(Repo, [:passthrough])

      try do
        :meck.expect(Repo, :get_market_price, fn "BTC" -> {:error, :market_down} end)
        assert {:error, :market_down} = OperationsServer.buy(user_id, "BTC", 1)
      after
        :meck.unload(Repo)
      end
    end

    test "buy/3 propagates get_wallet error" do
      user_id = "ops_user_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      assert {:ok, _pid} = Directorio.login(user_id, creds)

      :ok = :meck.new(Repo, [:passthrough])

      try do
        :meck.expect(Repo, :get_market_price, fn "BTC" -> {:ok, 100.0} end)
        :meck.expect(Repo, :get_wallet, fn ^user_id -> {:error, :wallet_missing} end)

        assert {:error, :wallet_missing} = OperationsServer.buy(user_id, "BTC", 1)
      after
        :meck.unload(Repo)
      end
    end

    test "sell/3 propagates get_market_price error" do
      user_id = "ops_user_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      assert {:ok, _pid} = Directorio.login(user_id, creds)

      :ok = :meck.new(Repo, [:passthrough])

      try do
        :meck.expect(Repo, :get_market_price, fn "BTC" -> {:error, :market_down} end)
        assert {:error, :market_down} = OperationsServer.sell(user_id, "BTC", 1)
      after
        :meck.unload(Repo)
      end
    end

    test "sell/3 propagates get_wallet error" do
      user_id = "ops_user_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      assert {:ok, _pid} = Directorio.login(user_id, creds)

      :ok = :meck.new(Repo, [:passthrough])

      try do
        :meck.expect(Repo, :get_market_price, fn "BTC" -> {:ok, 100.0} end)
        :meck.expect(Repo, :get_wallet, fn ^user_id -> {:error, :wallet_missing} end)

        assert {:error, :wallet_missing} = OperationsServer.sell(user_id, "BTC", 1)
      after
        :meck.unload(Repo)
      end
    end

    test "transaction_history/1 delegates to Repo.get_transactions/1" do
      user_id = "ops_user_#{System.unique_integer([:positive])}"

      :ok = :meck.new(Repo, [:passthrough])

      try do
        :meck.expect(Repo, :get_transactions, fn ^user_id -> {:ok, [%{id: 1}]} end)
        assert {:ok, [%{id: 1}]} = OperationsServer.transaction_history(user_id)
      after
        :meck.unload(Repo)
      end
    end
  end
end
