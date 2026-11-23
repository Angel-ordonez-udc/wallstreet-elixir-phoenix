defmodule WallstreetBackend.Market.DataLoaderTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Market.DataLoader

  @ets :precios

  setup do
    if :ets.whereis(@ets) == :undefined do
      :ets.new(@ets, [:named_table, :set, :public])
    else
      :ets.delete_all_objects(@ets)
    end

    # If these files exist in the project, rename them temporarily to avoid
    # depending on repo fixtures and to make tests deterministic.
    csv_path = Path.expand("priv/data/precios.csv")
    json_path = Path.expand("priv/data/precios.json")

    csv_backup = csv_path <> ".bak_test"
    json_backup = json_path <> ".bak_test"

    backups =
      []
      |> maybe_backup(csv_path, csv_backup)
      |> maybe_backup(json_path, json_backup)

    on_exit(fn ->
      restore_backups(backups)

      if :ets.whereis(@ets) != :undefined do
        :ets.delete_all_objects(@ets)
      end
    end)

    :ok
  end

  defp maybe_backup(backups, path, backup_path) do
    if File.exists?(path) do
      File.rename!(path, backup_path)
      [{path, backup_path} | backups]
    else
      backups
    end
  end

  defp restore_backups(backups) do
    Enum.each(backups, fn {path, backup_path} ->
      if File.exists?(backup_path) do
        # If the test created a new file at path, remove it first.
        if File.exists?(path), do: File.rm!(path)
        File.rename!(backup_path, path)
      end
    end)
  end

  test "loads from CSV when CSV exists" do
    File.mkdir_p!("priv/data")

    File.write!(
      "priv/data/precios.csv",
      "timestamp,precio\n1,10.5\n2,20.5\n"
    )

    assert :ok = DataLoader.load!()

    assert :ets.lookup(@ets, 1) == [{1, 10.5}]
    assert :ets.lookup(@ets, 2) == [{2, 20.5}]
  end

  test "loads from JSON when CSV missing and JSON exists" do
    File.mkdir_p!("priv/data")

    # Ensure CSV is absent so JSON branch is used.
    if File.exists?("priv/data/precios.csv"), do: File.rm!("priv/data/precios.csv")

    File.write!(
      "priv/data/precios.json",
      Jason.encode!([
        %{"timestamp" => "1", "precio" => 99.0},
        %{"timestamp" => "2025-01-01T00:00:00Z", "precio" => 1.25}
      ])
    )

    assert :ok = DataLoader.load!()

    assert :ets.lookup(@ets, 1) == [{1, 99.0}]

    # the ISO timestamp gets converted to unix
    {:ok, dt, _} = DateTime.from_iso8601("2025-01-01T00:00:00Z")
    unix = DateTime.to_unix(dt)
    assert :ets.lookup(@ets, unix) == [{unix, 1.25}]
  end

  test "raises when no data file exists" do
    if File.exists?("priv/data/precios.csv"), do: File.rm!("priv/data/precios.csv")
    if File.exists?("priv/data/precios.json"), do: File.rm!("priv/data/precios.json")

    assert_raise RuntimeError, ~r/Price data file not found/, fn ->
      DataLoader.load!()
    end
  end
end
