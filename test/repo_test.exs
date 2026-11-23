defmodule WallstreetBackend.RepoTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Repo
  alias WallstreetBackend.Storage.MnesiaStorage
  alias WallstreetBackend.Schemas.Wallet
  alias WallstreetBackend.Operations.Transaction

  setup do
    _ = Process.whereis(Repo) || start_supervised!({Repo, []})

    # keep mnesia tables clean for deterministic results
    _ = MnesiaStorage.setup()
    :mnesia.clear_table(:wallets)
    :mnesia.clear_table(:transactions)

    # Repo keeps market prices in memory; if it's already running we need to clear it.
    :sys.replace_state(Repo, fn st -> Map.put(st, :market_prices, %{}) end)

    user_id = "u_#{System.unique_integer([:positive])}"

    %{user_id: user_id}
  end

  test "create_wallet creates a default wallet and rejects duplicates", %{user_id: user_id} do
    assert :ok = Repo.create_wallet(user_id)

    assert {:ok, %Wallet{} = wallet} = Repo.get_wallet(user_id)
    assert wallet.balance > 0

    assert {:error, :wallet_already_exists} = Repo.create_wallet(user_id)
  end

  test "get_wallet and update_wallet", %{user_id: user_id} do
    assert :ok = Repo.create_wallet(user_id)

    assert {:ok, %Wallet{} = wallet} = Repo.get_wallet(user_id)

    updated = %Wallet{wallet | balance: wallet.balance + 10}
    assert :ok = Repo.update_wallet(user_id, updated)

    assert {:ok, %Wallet{balance: new_balance}} = Repo.get_wallet(user_id)
    assert new_balance == updated.balance

    assert {:error, :user_not_found} = Repo.get_wallet("missing")
    assert {:error, :user_not_found} = Repo.update_wallet("missing", updated)
  end

  test "market price update and get_market_price branches" do
    assert {:error, :asset_not_found} = Repo.get_market_price("BTC")

    Repo.update_market_price("BTC", 123.0)
    assert {:ok, 123.0} = Repo.get_market_price("BTC")

    assert ["BTC"] = Repo.get_market_prices()
  end

  test "transactions save and fetch", %{user_id: user_id} do
    assert :ok = Repo.create_wallet(user_id)

    tx = %Transaction{
      user_id: user_id,
      type: :buy,
      asset: "BTC",
      quantity: 1,
      price: 10.0,
      timestamp: DateTime.utc_now()
    }

    assert :ok = Repo.save_transaction(tx)

    assert {:ok, [tx2 | _]} = Repo.get_transactions(user_id)
    assert tx2.user_id == user_id
    assert tx2.type == :buy
  end

  test "update_wallet persists changes", %{user_id: user_id} do
    assert :ok = Repo.create_wallet(user_id)
    assert {:ok, %Wallet{} = wallet} = Repo.get_wallet(user_id)

    updated = %Wallet{wallet | balance: wallet.balance - 123.0}

    assert :ok = Repo.update_wallet(user_id, updated)
    assert {:ok, %Wallet{} = wallet2} = Repo.get_wallet(user_id)
    assert wallet2.balance == updated.balance
  end

  test "update_wallet returns user_not_found for unknown user", %{user_id: user_id} do
    assert :ok = Repo.create_wallet(user_id)
    assert {:ok, wallet} = Repo.get_wallet(user_id)

    assert {:error, :user_not_found} = Repo.update_wallet("missing_user", wallet)
  end
end
