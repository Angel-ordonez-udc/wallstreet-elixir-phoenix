defmodule WallstreetBackend.Operations.Transaction do
  @moduledoc """
  Transactions struct.
  Validates quantity and price.
  """

  @enforce_keys [:user_id, :type, :asset, :quantity, :price, :timestamp]
  defstruct [:user_id, :type, :asset, :quantity, :price, :timestamp]

  @type t :: %__MODULE__{
          user_id: String.t(),
          type: :buy | :sell,
          asset: String.t(),
          quantity: number(),
          price: number(),
          timestamp: DateTime.t()
        }

  def build(attrs) do
    if attrs.quantity > 0 and attrs.price > 0 do
      {:ok, struct!(__MODULE__, attrs)}
    else
      {:error, :invalid_data}
    end
  end
end
