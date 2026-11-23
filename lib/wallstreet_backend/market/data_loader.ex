defmodule WallstreetBackend.Market.DataLoader do
  @moduledoc """
  Loads price data from a CSV/JSON file on application startup.
  Inserts them into an ETS table accessible by name :prices.
  """

  @ets_table :precios
  @csv_file_path "priv/data/precios.csv"
  @json_file_path "priv/data/precios.json"

  # Creates the ETS table if it does not exist yet
  defp ensure_ets_table! do
    unless :ets.whereis(@ets_table) != :undefined do
      :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])
    end

    :ok
  end

  # load!/0 – reads the file and fills the ETS table :prices
  def load! do
    ensure_ets_table!()

    cond do
      File.exists?(@csv_file_path) ->
        @csv_file_path
        |> File.stream!()
        # skip header
        |> Stream.drop(1)
        |> Stream.map(&parse_row/1)
        |> Enum.each(fn {timestamp, price} ->
          :ets.insert(@ets_table, {timestamp, price})
        end)

      File.exists?(@json_file_path) ->
        @json_file_path
        |> File.read!()
        |> Jason.decode!()
        |> Enum.each(fn row ->
          {timestamp, price} = parse_row(row)
          :ets.insert(@ets_table, {timestamp, price})
        end)

      true ->
        raise "Price data file not found"
    end
  end

  # parse_row/1 – converts each row to {timestamp, price}
  # For CSV: row is a string "timestamp,price"
  # For JSON: row is a map %{"timestamp" => ..., "precio" => ...}
  def parse_row(row) when is_binary(row) do
    [timestamp, price] = String.trim(row) |> String.split(",")
    {parse_timestamp(timestamp), String.to_float(price)}
  end

  def parse_row(%{"timestamp" => timestamp, "precio" => price}) do
    {parse_timestamp(timestamp), price * 1.0}
  end

  defp parse_timestamp(ts) when is_binary(ts) do
    # Try to parse as integer, otherwise as ISO8601 string
    case Integer.parse(ts) do
      {int, ""} ->
        int

      _ ->
        case DateTime.from_iso8601(ts) do
          {:ok, dt, _} -> DateTime.to_unix(dt)
          _ -> raise "Unsupported timestamp format: #{ts}"
        end
    end
  end
end
