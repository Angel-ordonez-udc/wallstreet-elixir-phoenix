defmodule WallstreetBackend.Schemas.PositionTest do
  use ExUnit.Case, async: true

  alias WallstreetBackend.Schemas.Position

  test "new creates valid position" do
    assert {:ok, position} = Position.new("AAPL", 2, 100.0)
    assert position.asset == "AAPL"
    assert position.quantity == 2
    assert position.average_price == 100.0
  end

  test "new with invalid data returns invalid_position" do
    assert {:error, :invalid_position} = Position.new("AAPL", 0, 100.0)
    assert {:error, :invalid_position} = Position.new("AAPL", -1, 100.0)
    assert {:error, :invalid_position} = Position.new("AAPL", 1, 0)
    assert {:error, :invalid_position} = Position.new("AAPL", 1, -10)
  end

  test "buy updates quantity and average price" do
    {:ok, position} = Position.new("AAPL", 2, 100.0)

    assert {:ok, updated} = Position.buy(position, 2, 200.0)
    assert updated.quantity == 4
    assert updated.average_price == 150.0
  end

  test "buy with invalid data returns invalid_position" do
    {:ok, position} = Position.new("AAPL", 2, 100.0)

    assert {:error, :invalid_position} = Position.buy(position, 0, 200.0)
    assert {:error, :invalid_position} = Position.buy(position, -1, 200.0)
    assert {:error, :invalid_position} = Position.buy(position, 1, 0)
    assert {:error, :invalid_position} = Position.buy(position, 1, -5)
  end

  test "sell partial quantity keeps position" do
    {:ok, position} = Position.new("AAPL", 5, 100.0)

    assert {:ok, updated} = Position.sell(position, 2)
    assert updated.quantity == 3
    assert updated.average_price == 100.0
  end

  test "sell full quantity deletes position" do
    {:ok, position} = Position.new("AAPL", 2, 100.0)
    assert {:ok, nil} = Position.sell(position, 2)
  end

  test "sell more than available returns insufficient assets" do
    {:ok, position} = Position.new("AAPL", 2, 100.0)
    assert {:error, :insufficient_assets} = Position.sell(position, 3)
  end

  test "sell with invalid quantity returns invalid_position" do
    {:ok, position} = Position.new("AAPL", 2, 100.0)
    assert {:error, :invalid_position} = Position.sell(position, 0)
    assert {:error, :invalid_position} = Position.sell(position, -1)
  end
end
