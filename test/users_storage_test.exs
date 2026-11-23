defmodule WallstreetBackend.Users.StorageTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Users.Storage

  setup do
    assert :ok = Storage.setup()

    :mnesia.clear_table(:users)

    :ok
  end

  test "save_user/2 and get_user/1" do
    user_id = "us_#{System.unique_integer([:positive])}"
    creds = %{"password" => "pw"}

    assert :ok = Storage.save_user(user_id, creds)
    assert {:ok, %{credentials: ^creds}} = Storage.get_user(user_id)
  end

  test "get_user/1 returns :user_not_found for missing users" do
    assert {:error, :user_not_found} = Storage.get_user("missing_user")
  end

  test "get_all_users/0 returns map of users" do
    user_id = "us_#{System.unique_integer([:positive])}"
    creds = %{"password" => "pw"}

    assert :ok = Storage.save_user(user_id, creds)
    assert {:ok, users} = Storage.get_all_users()
    assert users[user_id].credentials == creds
  end

  test "setup/0 tolerates already existing schema/table" do
    :ok = :meck.new(:mnesia, [:passthrough])

    :meck.expect(:mnesia, :create_schema, fn _ ->
      {:error, {node(), {:already_exists, node()}}}
    end)

    :meck.expect(:mnesia, :create_table, fn :users, _opts ->
      {:aborted, {:already_exists, :users}}
    end)

    :meck.expect(:mnesia, :wait_for_tables, fn _tables, _timeout -> :ok end)

    assert :ok = Storage.setup()

    :meck.unload(:mnesia)
  end

  test "save_user/2 returns error when transaction aborts" do
    :ok = :meck.new(:mnesia, [:passthrough])
    :meck.expect(:mnesia, :transaction, fn _fun -> {:aborted, :tx_failed} end)

    assert {:error, :tx_failed} = Storage.save_user("u1", %{"password" => "pw"})

    :meck.unload(:mnesia)
  end

  test "get_all_users/0 returns error when transaction aborts" do
    :ok = :meck.new(:mnesia, [:passthrough])
    :meck.expect(:mnesia, :transaction, fn _fun -> {:aborted, :tx_failed} end)

    assert {:error, :tx_failed} = Storage.get_all_users()

    :meck.unload(:mnesia)
  end

  test "get_user/1 returns error when transaction aborts" do
    :ok = :meck.new(:mnesia, [:passthrough])
    :meck.expect(:mnesia, :transaction, fn _fun -> {:aborted, :tx_failed} end)

    try do
      assert {:error, :tx_failed} = Storage.get_user("any")
    after
      :meck.unload(:mnesia)
    end
  end

  test "setup/0 returns error when :mnesia.start/0 fails" do
    :ok = :meck.new(:mnesia, [:passthrough])
    :meck.expect(:mnesia, :start, fn -> {:error, :boom} end)

    try do
      assert {:error, :boom} = Storage.setup()
    after
      :meck.unload(:mnesia)
    end
  end

  test "setup/0 returns error when wait_for_tables times out" do
    :ok = :meck.new(:mnesia, [:passthrough])

    :meck.expect(:mnesia, :create_schema, fn _ -> :ok end)
    :meck.expect(:mnesia, :start, fn -> :ok end)
    :meck.expect(:mnesia, :create_table, fn :users, _opts -> {:atomic, :ok} end)
    :meck.expect(:mnesia, :wait_for_tables, fn tables, _timeout -> {:timeout, tables} end)

    try do
      assert {:error, {:timeout, _}} = Storage.setup()
    after
      :meck.unload(:mnesia)
    end
  end
end
