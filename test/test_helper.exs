ExUnit.start()

support_path = Path.join(__DIR__, "support")

if File.dir?(support_path) do
  support_path
  |> Path.join("**/*.exs")
  |> Path.wildcard()
  |> Enum.each(&Code.require_file/1)
end
