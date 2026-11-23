defmodule WallstreetBackend.Users.UserServerTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Directorio
  alias WallstreetBackend.Repo
  alias WallstreetBackend.Users.UserServer

  setup do
    user_id = "user_#{System.unique_integer([:positive])}"
    creds = %{"password" => "pw"}

    :ok = Directorio.register(user_id, creds)

    %{user_id: user_id, creds: creds}
  end

  test "login works and a wallet exists", %{user_id: user_id, creds: creds} do
    assert {:ok, _pid} = Directorio.login(user_id, creds)
    assert {:ok, _wallet} = Repo.get_wallet(user_id)
  end

  test "invalid credentials are rejected", %{user_id: user_id} do
    assert {:error, _} = Directorio.login(user_id, %{"password" => "wrong"})
  end

  test "multiple users can login independently", %{creds: creds} do
    user_a = "user_#{System.unique_integer([:positive])}"
    user_b = "user_#{System.unique_integer([:positive])}"

    :ok = Directorio.register(user_a, creds)
    :ok = Directorio.register(user_b, creds)

    assert {:ok, _} = Directorio.login(user_a, creds)
    assert {:ok, _} = Directorio.login(user_b, creds)

    assert {:ok, _} = Repo.get_wallet(user_a)
    assert {:ok, _} = Repo.get_wallet(user_b)
  end

  describe "UserServer.authenticate/2" do
    test "returns ok for correct credentials", %{user_id: user_id, creds: creds} do
      assert {:ok, _pid} = Directorio.login(user_id, creds)
      assert {:ok, %{user_id: ^user_id}} = UserServer.authenticate(user_id, creds)
    end

    test "returns invalid_credentials for wrong credentials", %{user_id: user_id, creds: creds} do
      assert {:ok, _pid} = Directorio.login(user_id, creds)

      assert {:error, :invalid_credentials} =
               UserServer.authenticate(user_id, %{"password" => "wrong"})
    end

    test "returns user_not_found when user does not exist" do
      missing = "missing_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}

      # start a process for that user id (even though it's not registered)
      {:ok, _pid} = start_supervised({UserServer, {missing, creds}})

      assert {:error, :user_not_found} = UserServer.authenticate(missing, creds)
    end
  end

  describe "UserServer.get_wallet/1 and get_balance/1" do
    test "get_wallet/1 returns wallet quantity map", %{user_id: user_id, creds: creds} do
      assert {:ok, _pid} = Directorio.login(user_id, creds)

      assert {:ok, map} = UserServer.get_wallet(user_id)
      assert is_map(map)
      # by default it can be empty positions
      assert map == %{} or map["BTC"] == nil or is_number(map["BTC"])
    end

    test "get_balance/1 returns wallet balance", %{user_id: user_id, creds: creds} do
      assert {:ok, _pid} = Directorio.login(user_id, creds)

      assert {:ok, balance} = UserServer.get_balance(user_id)
      assert is_number(balance)
      assert balance >= 0
    end

    test "get_wallet/1 returns error if repo wallet is missing (mocked)", %{
      user_id: user_id,
      creds: creds
    } do
      assert {:ok, _pid} = Directorio.login(user_id, creds)

      :ok = :meck.new(Repo, [:passthrough])
      :meck.expect(Repo, :get_wallet, fn ^user_id -> {:error, :wallet_not_found} end)

      assert {:error, :wallet_not_found} = UserServer.get_wallet(user_id)

      :meck.unload(Repo)
    end

    test "get_balance/1 returns error if repo wallet is missing (mocked)", %{
      user_id: user_id,
      creds: creds
    } do
      assert {:ok, _pid} = Directorio.login(user_id, creds)

      :ok = :meck.new(Repo, [:passthrough])
      :meck.expect(Repo, :get_wallet, fn ^user_id -> {:error, :wallet_not_found} end)

      assert {:error, :wallet_not_found} = UserServer.get_balance(user_id)

      :meck.unload(Repo)
    end
  end
end
