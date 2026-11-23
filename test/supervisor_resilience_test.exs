defmodule WallstreetBackend.SupervisorResilienceTest do
  use ExUnit.Case, async: false

  test "the supervisor detects a crashed service and restarts it automatically (resilience)" do
    # Verify the MarketServer is running
    pid = Process.whereis(WallstreetBackend.Market.MarketServer)
    assert pid != nil
    assert Process.alive?(pid)

    # Simulate a catastrophic crash of the MarketServer (unconditional kill)
    Process.exit(pid, :kill)

    # Wait briefly for the supervisor (in application.ex) to detect the crash and restart it
    :timer.sleep(200)

    # Verify that a new process has been spawned for the same service
    new_pid = Process.whereis(WallstreetBackend.Market.MarketServer)
    assert new_pid != nil
    assert Process.alive?(new_pid)

    # Ensure it is a different process from the original (it was restarted)
    refute new_pid == pid
  end
end
