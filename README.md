# HipcallTts

Multi-provider Text-to-Speech (TTS) client for Elixir with a unified API, automatic text splitting, retry logic, and telemetry.

Currently supported providers:

- OpenAI (`:openai`)
- Amazon Polly (`:polly`)
- ElevenLabs (`:elevenlabs`)

## Installation

Add `hipcall_tts` to your dependencies:

```elixir
def deps do
  [
    {:hipcall_tts, "~> 0.1.0"}
  ]
end
```

## Quick start

### OpenAI

Set your API key:

```bash
export OPENAI_API_KEY="..."
```

Generate speech:

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

Set AWS credentials:

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"
```

Generate speech:

```elixir
{:ok, audio} =
  HipcallTts.generate(
    provider: :polly,
    text: "Hello from Polly",
    voice: "Joanna",
    model: "standard",
    format: "mp3",
    region: "us-east-1"
  )

File.write!("polly.mp3", audio)
```

### ElevenLabs

Set your API key:

```bash
export ELEVENLABS_API_KEY="..."
```

Generate speech:

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
    api_key: {:system, "OPENAI_API_KEY"}
  ],
  elevenlabs: [
    api_key: {:system, "ELEVENLABS_API_KEY"}
  ],
  polly: [
    access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
    secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"},
    # optional:
    # region: {:system, "AWS_REGION"},
    # session_token: {:system, "AWS_SESSION_TOKEN"}
  ]
```

## Provider options (`provider_opts`)

Pass provider-specific overrides via `provider_opts`:

```elixir
HipcallTts.generate(
  provider: :openai,
  text: "Hello",
  voice: "nova",
  provider_opts: [api_key: "override-key"]
)
```

```elixir
HipcallTts.generate(
  provider: :polly,
  text: "Hello",
  voice: "Joanna",
  provider_opts: [region: "us-east-1"]
)
```

```elixir
HipcallTts.generate(
  provider: :elevenlabs,
  text: "Hello",
  voice: "Xb7hH8MSUJpSbSDYk0k2",
  provider_opts: [api_key: "override-key"]
)
```

## Automatic text splitting + concatenation

If the text exceeds the provider limit, `HipcallTts.generate/1` will:

1. Split the text into chunks (`HipcallTts.TextSplitter`)
2. Call the provider for each chunk (optionally with retries)
3. Concatenate returned audio binaries (`HipcallTts.AudioConcatenator`)

## Retry options

Use `retry_opts` to control retries:

```elixir
HipcallTts.generate(
  provider: :openai,
  text: "Hello",
  retry_opts: [
    max_attempts: 3,
    initial_delay: 200,
    max_delay: 2000,
    backoff_factor: 2.0,
    retryable_errors: [:network_error, :http_error]
  ]
)
```

`max_attempts: 0` disables retries (only the initial attempt is made).

## Introspection API

Useful for dynamic UIs:

```elixir
HipcallTts.providers()
HipcallTts.models(:openai)
HipcallTts.voices(:polly)
HipcallTts.languages(:polly)
HipcallTts.capabilities(:openai)
```

## Telemetry

Events emitted:

- `[:hipcall_tts, :generate, :start]`
- `[:hipcall_tts, :generate, :stop]` (includes `success: true/false`)
- `[:hipcall_tts, :generate, :error]` (when `generate/1` returns `{:error, ...}`)
- `[:hipcall_tts, :generate, :exception]`
- `[:hipcall_tts, :http, :request]`
- `[:hipcall_tts, :retry, :attempt]`
- `[:hipcall_tts, :text, :split]`

## Testing

The provider tests use [Bypass](https://hex.pm/packages/bypass), so they do not call real APIs.

Run tests:

```bash
mix test
```

## Hipcall

All [Hipcall](https://www.hipcall.com/en/) libraries:

- [HipcallDisposableEmail](https://hex.pm/packages/hipcall_disposable_email) - Simple library checking the email's domain is disposable or not.
- [HipcallDeepgram](https://hex.pm/packages/hipcall_deepgram) - Unofficial Deepgram API Wrapper written in Elixir.
- [HipcallOpenai](https://hex.pm/packages/hipcall_openai) - Unofficial OpenAI API Wrapper written in Elixir.
- [HipcallWhichtech](https://hex.pm/packages/hipcall_whichtech) - Find out what the website is built with.
- [HipcallSms](https://hex.pm/packages/hipcall_sms) - SMS SDK for different providers.
- [HipcallSdk](https://hex.pm/packages/hipcall_sdk) - Official Hipcall API Wrapper written in Elixir.
