defmodule WallstreetBackend.Schemas.Wallet do
  @moduledoc """
  User wallet with available balance and positions.
  """

  alias WallstreetBackend.Schemas.Position

  @type t :: %__MODULE__{
          balance: number(),
          positions: %{optional(String.t()) => Position.t()}
        }

  defstruct balance: 0.0, positions: %{}

  @spec new(number()) :: t()
  def new(initial_balance \\ 0.0) when is_number(initial_balance) and initial_balance >= 0 do
    %__MODULE__{balance: initial_balance, positions: %{}}
  end

  @spec buy(t(), String.t(), number(), number()) ::
          {:ok, t()} | {:error, :insufficient_funds | :invalid_operation}
  def buy(%__MODULE__{} = wallet, asset, quantity, unit_price)
      when is_binary(asset) and is_number(quantity) and is_number(unit_price) and quantity > 0 and
             unit_price > 0 do
    total_cost = quantity * unit_price

    if wallet.balance < total_cost do
      {:error, :insufficient_funds}
    else
      updated_positions =
        case Map.get(wallet.positions, asset) do
          nil ->
            {:ok, position} = Position.new(asset, quantity, unit_price)
            Map.put(wallet.positions, asset, position)

          %Position{} = position ->
            {:ok, updated_position} = Position.buy(position, quantity, unit_price)
            Map.put(wallet.positions, asset, updated_position)
        end

      {:ok, %{wallet | balance: wallet.balance - total_cost, positions: updated_positions}}
    end
  end

  def buy(_, _, _, _), do: {:error, :invalid_operation}

  @spec sell(t(), String.t(), number(), number()) ::
          {:ok, t()} | {:error, :asset_not_found | :insufficient_assets | :invalid_operation}
  def sell(%__MODULE__{} = wallet, asset, quantity, unit_price)
      when is_binary(asset) and is_number(quantity) and is_number(unit_price) and quantity > 0 and
             unit_price > 0 do
    case Map.get(wallet.positions, asset) do
      nil ->
        {:error, :asset_not_found}

      %Position{} = position ->
        case Position.sell(position, quantity) do
          {:ok, nil} ->
            updated_positions = Map.delete(wallet.positions, asset)

            {:ok,
             %{
               wallet
               | balance: wallet.balance + quantity * unit_price,
                 positions: updated_positions
             }}

          {:ok, updated_position} ->
            updated_positions = Map.put(wallet.positions, asset, updated_position)

            {:ok,
             %{
               wallet
               | balance: wallet.balance + quantity * unit_price,
                 positions: updated_positions
             }}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def sell(_, _, _, _), do: {:error, :invalid_operation}

  @spec to_quantity_map(t()) :: %{optional(String.t()) => number()}
  def to_quantity_map(%__MODULE__{} = wallet) do
    Map.new(wallet.positions, fn {asset, position} -> {asset, position.quantity} end)
  end
end
