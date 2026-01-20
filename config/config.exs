import Config

config :hipcall_tts, :providers,
  openai: [
    api_key: {:system, "OPENAI_API_KEY"},
    base_url: "https://api.openai.com"
  ],
  elevenlabs: [
    api_key: {:system, "ELEVENLABS_API_KEY"}
  ],
  polly: [
    access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
    secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"}
    # Optional:
    # region: {:system, "AWS_REGION"},
    # session_token: {:system, "AWS_SESSION_TOKEN"}
  ]
