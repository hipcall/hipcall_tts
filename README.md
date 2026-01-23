# HipcallTts

[![Hex.pm](https://img.shields.io/hexpm/v/hipcall_tts.svg)](https://hex.pm/packages/hipcall_tts)
[![Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/hipcall_tts)

Multi-provider Text-to-Speech (TTS) client for Elixir with a unified API, automatic text splitting, retry logic, and telemetry.

## Supported Providers

| Provider | ID | Authentication |
|----------|-----|----------------|
| OpenAI | `:openai` | API Key |
| Amazon Polly | `:polly` | AWS SigV4 |
| ElevenLabs | `:elevenlabs` | API Key |

## Installation

Add `hipcall_tts` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hipcall_tts, "~> 0.1.0"}
  ]
end
```

## Quick Start

### OpenAI

```bash
export OPENAI_API_KEY="..."
```

```elixir
{:ok, audio} =
  HipcallTts.generate(
    provider: :openai,
    text: "Hello from HipcallTts",
    voice: "nova",
    model: "tts-1",
    format: "mp3"
  )

File.write!("openai.mp3", audio)
```

### Amazon Polly

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"
```

```elixir
{:ok, audio} =
  HipcallTts.generate(
    provider: :polly,
    text: "Hello from Polly",
    voice: "Joanna",
    model: "standard",
    format: "mp3"
  )

File.write!("polly.mp3", audio)
```

### ElevenLabs

```bash
export ELEVENLABS_API_KEY="..."
```

```elixir
{:ok, audio} =
  HipcallTts.generate(
    provider: :elevenlabs,
    text: "Hello from ElevenLabs",
    voice: "Xb7hH8MSUJpSbSDYk0k2",
    model: "eleven_multilingual_v2",
    format: "mp3",
    sample_rate: 44100
  )

File.write!("elevenlabs.mp3", audio)
```

## Configuration

Configure providers in `config/config.exs`:

```elixir
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
```

The `{:system, "ENV_VAR"}` tuple reads from environment variables at runtime.

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `provider` | atom | Yes | `:openai`, `:elevenlabs`, or `:polly` |
| `text` | string | Yes | Text to synthesize |
| `voice` | string | No | Voice identifier (provider-specific) |
| `model` | string | No | Model identifier |
| `format` | string | No | Audio format (default: `"mp3"`) |
| `sample_rate` | integer | No | Sample rate in Hz |
| `speed` | float | No | Speech speed multiplier (default: `1.0`) |
| `language` | string | No | Language code |
| `provider_opts` | keyword | No | Provider-specific options |
| `retry_opts` | keyword | No | Retry configuration |

## Provider Details

### OpenAI

**Models:** `tts-1` (standard), `tts-1-hd` (high quality)

**Voices:** `alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer`

**Formats:** `mp3`, `opus`, `aac`, `flac`

**Max text:** 4,096 characters

### Amazon Polly

**Models:** `standard`, `neural`

**Sample Voices:** `Joanna` (en-US), `Matthew` (en-US), `Amy` (en-GB), `Filiz` (tr-TR)

**Formats:** `mp3`, `ogg_vorbis`, `pcm`

**Max text:** 3,000 characters

**SSML Support:** Auto-detected when text starts with `<speak>`

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :polly,
  text: "<speak>Hello <break time='500ms'/> World!</speak>",
  voice: "Joanna"
)
```

### ElevenLabs

**Models:** `eleven_multilingual_v2`, `eleven_flash_v2_5`

**Formats:** `mp3`, `pcm`, `ulaw_8000`

**Max text:** 10,000-40,000 characters (model-dependent)

**Voice Settings:**

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :elevenlabs,
  text: "Hello with custom settings!",
  voice: "Xb7hH8MSUJpSbSDYk0k2",
  provider_opts: [
    stability: 0.5,
    similarity_boost: 0.8,
    style: 0.5,
    use_speaker_boost: true
  ]
)
```

## Introspection API

Query provider capabilities at runtime:

```elixir
# List all providers
HipcallTts.providers()
# => [:openai, :elevenlabs, :polly]

# Get provider models
{:ok, models} = HipcallTts.models(:openai)

# Get provider voices
{:ok, voices} = HipcallTts.voices(:openai)

# Get supported languages
{:ok, languages} = HipcallTts.languages(:polly)

# Get provider capabilities
{:ok, caps} = HipcallTts.capabilities(:elevenlabs)
# => %{streaming: false, formats: ["mp3", "pcm", "ulaw_8000"], ...}
```

## Advanced Features

### Automatic Text Splitting

When text exceeds provider limits, HipcallTts automatically:
1. Splits text at sentence boundaries
2. Generates audio for each chunk
3. Concatenates the audio segments

This is transparent - you receive a single audio binary.

### Retry Logic

```elixir
HipcallTts.generate(
  provider: :openai,
  text: "Hello",
  retry_opts: [
    max_attempts: 5,
    initial_delay: 500,
    max_delay: 10_000,
    backoff_factor: 2.0
  ]
)
```

### Telemetry Events

| Event | When |
|-------|------|
| `[:hipcall_tts, :generate, :start]` | Before generation |
| `[:hipcall_tts, :generate, :stop]` | After success |
| `[:hipcall_tts, :generate, :error]` | On error |
| `[:hipcall_tts, :http, :request]` | HTTP request complete |
| `[:hipcall_tts, :retry, :attempt]` | Retry attempt |
| `[:hipcall_tts, :text, :split]` | Text was split |

```elixir
:telemetry.attach(
  "hipcall-tts-logger",
  [:hipcall_tts, :generate, :stop],
  fn _event, measurements, metadata, _config ->
    Logger.info("TTS generated #{metadata.audio_size} bytes in #{measurements.duration}ms")
  end,
  nil
)
```

## Error Handling

```elixir
case HipcallTts.generate(provider: :openai, text: "Hello") do
  {:ok, audio} ->
    File.write!("output.mp3", audio)

  {:error, %{code: :rate_limited}} ->
    Process.sleep(5000)
    retry_generation()

  {:error, %{code: :validation_error, message: msg}} ->
    Logger.error("Invalid parameters: #{msg}")

  {:error, error} ->
    Logger.error("TTS failed: #{inspect(error)}")
end
```

**Error codes:** `:validation_error`, `:http_error`, `:network_error`, `:timeout`, `:authentication_error`, `:rate_limited`, `:provider_error`

## Provider Comparison

| Feature | OpenAI | AWS Polly | ElevenLabs |
|---------|--------|-----------|------------|
| Max Text | 4,096 chars | 3,000 chars | 10,000-40,000 chars |
| Voices | 6 | 9+ | Custom + Library |
| Languages | 11 | 4 | 30+ |
| SSML | No | Yes | No |
| Voice Cloning | No | No | Yes |

## Testing

Tests use [Bypass](https://hex.pm/packages/bypass), so they do not call real APIs:

```bash
mix test
```

## Hipcall

All [Hipcall](https://www.hipcall.com/en/) libraries:

- [HipcallDisposableEmail](https://hex.pm/packages/hipcall_disposable_email) - Check if email domain is disposable
- [HipcallDeepgram](https://hex.pm/packages/hipcall_deepgram) - Deepgram API Wrapper
- [HipcallOpenai](https://hex.pm/packages/hipcall_openai) - OpenAI API Wrapper
- [HipcallWhichtech](https://hex.pm/packages/hipcall_whichtech) - Website tech detection
- [HipcallSms](https://hex.pm/packages/hipcall_sms) - SMS SDK for multiple providers
- [HipcallSdk](https://hex.pm/packages/hipcall_sdk) - Official Hipcall API Wrapper

## License

MIT License - see [LICENSE](LICENSE) for details.
