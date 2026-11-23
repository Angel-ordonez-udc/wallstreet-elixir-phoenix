defmodule WallstreetBackend.Operations.TransactionTest do
  use ExUnit.Case, async: true

  alias WallstreetBackend.Operations.Transaction

  test "build/1 returns {:ok, struct} for valid values" do
    attrs = %{
      user_id: "u1",
      type: :buy,
      asset: "BTC",
      quantity: 0.5,
      price: 10_000.0,
      timestamp: DateTime.utc_now()
    }

    assert {:ok, %Transaction{} = tx} = Transaction.build(attrs)
    assert tx.user_id == "u1"
    assert tx.type == :buy
    assert tx.asset == "BTC"
    assert tx.quantity == 0.5
    assert tx.price == 10_000.0
  end

  test "build/1 returns {:error, :invalid_data} when quantity is not positive" do
    attrs = %{
      user_id: "u1",
      type: :buy,
      asset: "BTC",
      quantity: 0,
      price: 10_000.0,
      timestamp: DateTime.utc_now()
    }

    assert {:error, :invalid_data} = Transaction.build(attrs)
  end

  test "build/1 returns {:error, :invalid_data} when price is not positive" do
    attrs = %{
      user_id: "u1",
      type: :sell,
      asset: "BTC",
      quantity: 1.0,
      price: 0,
      timestamp: DateTime.utc_now()
    }

    assert {:error, :invalid_data} = Transaction.build(attrs)
  end
end
