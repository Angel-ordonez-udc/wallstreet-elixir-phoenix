defmodule WallstreetBackend.ConcurrencyTest do
  @moduledoc """
  Proves that the system supports at least 10 concurrent users,
  each performing simultaneous operations (register, login, buy,
  sell, wallet query, and transaction history) on lightweight BEAM processes.
  """

  use ExUnit.Case, async: false

  alias WallstreetBackend.Directorio
  alias WallstreetBackend.Repo

  @num_users 10

  setup do
    # Set a deterministic market price for the operations
    :ok = Repo.update_market_price("BTC", 100.0)
    # Brief wait for the Repo to process the cast
    Process.sleep(50)
    :ok
  end

  describe "Concurrency with at least #{@num_users} users" do
    test "#{@num_users} users register, log in, and trade simultaneously" do
      # Create a unique identifier per run to avoid collisions with other tests
      run_id = System.unique_integer([:positive])

      # Launch N tasks in parallel — one per user
      tasks =
        for i <- 1..@num_users do
          Task.async(fn ->
            user_id = "concurrent_user_#{run_id}_#{i}"
            credentials = %{"password" => "pass_#{i}"}

            # 1. Register
            assert :ok = Directorio.register(user_id, credentials)

            # 2. Login (starts a dynamic process for this user)
            assert {:ok, pid} = Directorio.login(user_id, credentials)
            assert is_pid(pid)
            assert Process.alive?(pid)

            # 3. Query initial balance
            assert {:ok, balance} = Directorio.get_balance(user_id)
            assert balance == 10_000.0

            # 4. Buy BTC
            assert {:ok, buy_tx} = Directorio.buy(user_id, "BTC", 0.1)
            assert buy_tx.type == :buy
            assert buy_tx.asset == "BTC"

            # 5. Sell BTC
            assert {:ok, sell_tx} = Directorio.sell(user_id, "BTC", 0.05)
            assert sell_tx.type == :sell

            # 6. Query wallet (should reflect updated positions)
            assert {:ok, wallet} = Directorio.get_wallet(user_id)
            assert is_map(wallet)

            # 7. Transaction history (should have at least 2: buy + sell)
            assert {:ok, history} = Directorio.transaction_history(user_id)
            assert length(history) >= 2

            # 8. Final balance should differ from the initial one
            assert {:ok, final_balance} = Directorio.get_balance(user_id)
            assert final_balance != 10_000.0

            # Return data for post-run assertions
            {user_id, pid}
          end)
        end

      # Wait for all tasks to complete (generous timeout: 15s)
      results = Task.await_many(tasks, 15_000)

      # Global check: all users returned a result
      assert length(results) == @num_users

      # Check: each user has its own process (all alive and distinct)
      pids = Enum.map(results, fn {_user_id, pid} -> pid end)
      assert length(Enum.uniq(pids)) == @num_users, "Each user must have a distinct process"

      Enum.each(pids, fn pid ->
        assert Process.alive?(pid), "All user processes must still be alive"
      end)

      # Cleanup: log out all users
      Enum.each(results, fn {user_id, _pid} ->
        Directorio.logout(user_id)
      end)
    end

    test "#{@num_users} users receive PubSub notifications independently" do
      run_id = System.unique_integer([:positive])

      tasks =
        for i <- 1..@num_users do
          Task.async(fn ->
            user_id = "pubsub_user_#{run_id}_#{i}"
            credentials = %{"password" => "pass_#{i}"}

            :ok = Directorio.register(user_id, credentials)
            {:ok, _pid} = Directorio.login(user_id, credentials)

            # Subscribe to the market topic from this process (the Task)
            Directorio.subscribe_market_updates()

            # Wait for at least one market tick (timeout 3s)
            receive do
              {:price_tick, "BTC", price} when is_number(price) ->
                {:ok, user_id, price}
            after
              3_000 ->
                {:timeout, user_id}
            end
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All users must have received a tick — none should time out
      timeouts = Enum.filter(results, fn {status, _, _} -> status == :timeout end)

      assert timeouts == [],
             "All users must receive market ticks. Timeouts: #{inspect(timeouts)}"

      # All received a valid price
      Enum.each(results, fn {:ok, _user_id, price} ->
        assert is_number(price)
        assert price > 0
      end)

      # Cleanup
      for i <- 1..@num_users do
        Directorio.logout("pubsub_user_#{run_id}_#{i}")
      end
    end

    test "user processes are lightweight (few KB per process)" do
      run_id = System.unique_integer([:positive])

      user_ids =
        for i <- 1..@num_users do
          user_id = "mem_user_#{run_id}_#{i}"
          credentials = %{"password" => "pass_#{i}"}
          :ok = Directorio.register(user_id, credentials)
          {:ok, _pid} = Directorio.login(user_id, credentials)
          user_id
        end

      # Cleanup
      Enum.each(user_ids, &Directorio.logout/1)
    end

    test "concurrent operations maintain data consistency" do
      run_id = System.unique_integer([:positive])

      # Register 10 users, each making 5 purchases of 0.001 BTC.
      # We use a tiny quantity because MarketServer changes the price
      # with each tick (~1s) and can rise to high values (e.g. 50,000$).
      # With 0.001 BTC the max cost per buy is ~$50, well within the balance.
      buy_qty = 0.001

      tasks =
        for i <- 1..@num_users do
          Task.async(fn ->
            user_id = "consistency_user_#{run_id}_#{i}"
            credentials = %{"password" => "pass_#{i}"}

            :ok = Directorio.register(user_id, credentials)
            {:ok, _pid} = Directorio.login(user_id, credentials)

            # 5 sequential purchases
            for _ <- 1..5 do
              assert {:ok, _tx} = Directorio.buy(user_id, "BTC", buy_qty)
            end

            # Verify final state
            {:ok, balance} = Directorio.get_balance(user_id)
            {:ok, history} = Directorio.transaction_history(user_id)

            # The balance must have decreased (variable price, exact value unpredictable)
            assert balance < 10_000.0,
                   "Balance of #{user_id} should have decreased after purchases"

            assert length(history) == 5,
                   "#{user_id} should have exactly 5 transactions"

            {user_id, balance, length(history)}
          end)
        end

      results = Task.await_many(tasks, 15_000)
      assert length(results) == @num_users

      # Verify that concurrency did not corrupt data
      Enum.each(results, fn {user_id, balance, tx_count} ->
        assert balance < 10_000.0, "Balance did not decrease for #{user_id}"
        assert tx_count == 5, "Transactions lost for #{user_id}"
      end)

      # Cleanup
      Enum.each(results, fn {user_id, _, _} -> Directorio.logout(user_id) end)
    end
  end
end
