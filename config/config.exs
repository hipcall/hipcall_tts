import Config

config :hipcall_tts, :providers,
  openai: [
    api_key: {:system, "OPENAI_API_KEY"},
    base_url: "https://api.openai.com",
    default_model: "tts-1",
    default_voice: "nova",
    default_format: "mp3"
  ],
  elevenlabs: [
    api_key: {:system, "ELEVENLABS_API_KEY"},
    default_model: "eleven_flash_v2_5",
    default_voice: "Xb7hH8MSUJpSbSDYk0k2",
    default_format: "mp3"
  ],
  polly: [
    access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
    secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"},
    default_model: "standard",
    default_voice: "Joanna",
    default_format: "mp3"
    # Optional:
    # region: {:system, "AWS_REGION"},
    # session_token: {:system, "AWS_SESSION_TOKEN"}
  ]
