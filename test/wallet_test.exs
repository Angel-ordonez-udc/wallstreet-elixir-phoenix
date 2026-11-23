defmodule WallstreetBackend.Schemas.WalletTest do
  use ExUnit.Case, async: true

  alias WallstreetBackend.Schemas.Wallet

  test "buy creates a new position and discounts balance" do
    wallet = Wallet.new(1_000.0)

    assert {:ok, updated} = Wallet.buy(wallet, "AAPL", 2, 100.0)
    assert updated.balance == 800.0
    assert updated.positions["AAPL"].quantity == 2
    assert updated.positions["AAPL"].average_price == 100.0
  end

  test "buy updates average price on existing position" do
    wallet = Wallet.new(1_000.0)
    {:ok, wallet} = Wallet.buy(wallet, "AAPL", 2, 100.0)

    assert {:ok, updated} = Wallet.buy(wallet, "AAPL", 2, 200.0)
    assert updated.positions["AAPL"].quantity == 4
    assert updated.positions["AAPL"].average_price == 150.0
  end

  test "buy fails when funds are insufficient" do
    wallet = Wallet.new(100.0)
    assert {:error, :insufficient_funds} = Wallet.buy(wallet, "AAPL", 2, 100.0)
  end

  test "sell reduces quantity and increases balance" do
    wallet = Wallet.new(1_000.0)
    {:ok, wallet} = Wallet.buy(wallet, "AAPL", 5, 100.0)

    assert {:ok, updated} = Wallet.sell(wallet, "AAPL", 2, 120.0)
    assert updated.balance == 740.0
    assert updated.positions["AAPL"].quantity == 3
  end

  test "sell full position removes asset from wallet" do
    wallet = Wallet.new(1_000.0)
    {:ok, wallet} = Wallet.buy(wallet, "AAPL", 2, 100.0)

    assert {:ok, updated} = Wallet.sell(wallet, "AAPL", 2, 150.0)
    assert updated.balance == 1_100.0
    refute Map.has_key?(updated.positions, "AAPL")
  end

  test "sell returns error when asset does not exist" do
    wallet = Wallet.new(1_000.0)
    assert {:error, :asset_not_found} = Wallet.sell(wallet, "TSLA", 1, 100.0)
  end

  test "to_quantity_map extracts only quantities" do
    wallet = Wallet.new(1_000.0)
    {:ok, wallet} = Wallet.buy(wallet, "AAPL", 3, 50.0)
    {:ok, wallet} = Wallet.buy(wallet, "TSLA", 2, 100.0)

    assert Wallet.to_quantity_map(wallet) == %{"AAPL" => 3, "TSLA" => 2}
  end

  test "new/0 defaults to 0 balance" do
    wallet = Wallet.new()
    assert wallet.balance == 0.0
    assert wallet.positions == %{}
  end

  test "buy returns invalid_operation for bad args" do
    wallet = Wallet.new(100.0)

    assert {:error, :invalid_operation} = Wallet.buy(wallet, :not_a_string, 1, 1)
    assert {:error, :invalid_operation} = Wallet.buy(wallet, "AAPL", 0, 1)
    assert {:error, :invalid_operation} = Wallet.buy(wallet, "AAPL", 1, 0)
    assert {:error, :invalid_operation} = Wallet.buy(%{balance: 100.0}, "AAPL", 1, 1)
  end

  test "sell returns invalid_operation for bad args" do
    wallet = Wallet.new(100.0)

    assert {:error, :invalid_operation} = Wallet.sell(wallet, :not_a_string, 1, 1)
    assert {:error, :invalid_operation} = Wallet.sell(wallet, "AAPL", 0, 1)
    assert {:error, :invalid_operation} = Wallet.sell(wallet, "AAPL", 1, 0)
    assert {:error, :invalid_operation} = Wallet.sell(%{balance: 100.0}, "AAPL", 1, 1)
  end
end
