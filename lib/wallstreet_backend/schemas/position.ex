defmodule WallstreetBackend.Schemas.Position do
  @moduledoc """
  Position for a single asset inside a wallet.
  """

  @type t :: %__MODULE__{
          asset: String.t(),
          quantity: number(),
          average_price: number()
        }

  defstruct [:asset, :quantity, :average_price]

  @spec new(String.t(), number(), number()) :: {:ok, t()} | {:error, :invalid_position}
  def new(asset, quantity, price)
      when is_binary(asset) and is_number(quantity) and is_number(price) and quantity > 0 and
             price > 0 do
    {:ok, %__MODULE__{asset: asset, quantity: quantity, average_price: price}}
  end

  def new(_, _, _), do: {:error, :invalid_position}

  @spec buy(t(), number(), number()) :: {:ok, t()} | {:error, :invalid_position}
  def buy(%__MODULE__{} = position, quantity, price)
      when is_number(quantity) and is_number(price) and quantity > 0 and price > 0 do
    new_quantity = position.quantity + quantity
    invested = position.quantity * position.average_price + quantity * price
    new_avg_price = invested / new_quantity

    {:ok, %{position | quantity: new_quantity, average_price: new_avg_price}}
  end

  def buy(_, _, _), do: {:error, :invalid_position}

  @spec sell(t(), number()) ::
          {:ok, t() | nil} | {:error, :insufficient_assets | :invalid_position}
  def sell(%__MODULE__{} = position, quantity) when is_number(quantity) and quantity > 0 do
    cond do
      quantity > position.quantity ->
        {:error, :insufficient_assets}

      quantity == position.quantity ->
        {:ok, nil}

      true ->
        {:ok, %{position | quantity: position.quantity - quantity}}
    end
  end

  def sell(_, _), do: {:error, :invalid_position}
end
