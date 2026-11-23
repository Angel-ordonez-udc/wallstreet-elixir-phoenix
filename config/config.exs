import Config

config :wallstreet, WallstreetFrontend.Endpoint,
  url: [host: "localhost"],
  http: [port: 4000],
  secret_key_base:
    "super_secret_key_base_for_wallstreet_project_at_least_64_bytes_long_1234567890abcdef",
  render_errors: [formats: [html: WallstreetFrontend.ErrorHTML], layout: false],
  pubsub_server: WallstreetBackend.PubSub,
  live_view: [signing_salt: "wallstreet_salt_2024"],
  server: true

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
