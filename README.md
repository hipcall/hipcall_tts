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
| Soniox | `:soniox` | API Key |

## Installation

Add `hipcall_tts` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hipcall_tts, "~> 0.4.0"}
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

### Soniox

```bash
export SONIOX_API_KEY="..."
```

```elixir
{:ok, audio} =
  HipcallTts.generate(
    provider: :soniox,
    text: "Merhaba dünya",
    voice: "Mina",
    model: "tts-rt-v2",
    language: "tr",
    format: "mp3"
  )

File.write!("soniox.mp3", audio)
```

Soniox requires a language on every request. Locale-style values are normalized
automatically, so `"tr-TR"` and `"tr_TR"` both resolve to `"tr"`.

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
  ],
  soniox: [
    api_key: {:system, "SONIOX_API_KEY"},
    default_model: "tts-rt-v2",
    default_voice: "Mina",
    default_format: "mp3",
    # Soniox requires a language on every request; used when the caller omits it.
    default_language: "en"
  ]
```

The `{:system, "ENV_VAR"}` tuple reads from environment variables at runtime.

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `provider` | atom | Yes | `:openai`, `:elevenlabs`, `:polly`, or `:soniox` |
| `text` | string | Yes | Text to synthesize |
| `voice` | string | No | Voice identifier (provider-specific) |
| `model` | string | No | Model identifier |
| `format` | string | No | Audio format (default: `"mp3"`) |
| `sample_rate` | integer | No | Sample rate in Hz |
| `speed` | float | No | Speech speed multiplier (default: `1.0`) |
| `language` | string | No | Language code |
| `provider_opts` | keyword | No | Provider-specific options |
| `retry_opts` | keyword | No | Retry configuration |

### Parameter support by provider

The schema accepts every parameter for every provider, but a provider only
sends what its API supports. **A parameter a provider does not use is silently
ignored.**

| Parameter | OpenAI | ElevenLabs | Polly | Soniox |
|-----------|:------:|:----------:|:-----:|:------:|
| `text` | ✅ | ✅ | ✅ | ✅ |
| `voice` | ✅ | ✅ | ✅ | ✅ |
| `model` | ✅ | ✅ | ✅ (engine) | ✅ |
| `format` | ✅ | ✅ | ✅ | ✅ |
| `speed` | ✅ | ✅ | ❌ | ✅ (0.7–1.3) |
| `language` | ❌ | ❌ | ❌ | ✅ (required) |
| `sample_rate` | ❌ | ❌ | ❌ | ✅ |
| `pitch` | ❌ | ❌ | ❌ | ❌ |

`pitch` is accepted and defaulted by the schema but is not implemented by any
provider. `sample_rate` and `language` currently only reach Soniox. See
[DOCUMENTATION.md](DOCUMENTATION.md#which-parameters-each-provider-actually-uses)
for the details and the minimal request per provider.

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

### Soniox

**Models:** `tts-rt-v2`

**Voices:** 70 built-in voices (40 male, 30 female) — `Mina`, `Daniel`, `Emma`,
`Adrian`, `Nina`, … Every voice speaks every supported language.

**Languages:** 63, selected per request via `:language`.

**Formats:** `mp3`, `wav`, `opus`, `aac`, `flac`, `pcm` (mapped to `pcm_s16le`)

**Speed:** `0.7`–`1.3` (narrower than the schema's general range; values outside
it are rejected before the request is sent)

**Max text:** 1,100 characters by default.

Soniox caps generated audio at **2 minutes of duration**, not by character count,
and truncates past the cap without an error. The default character budget is
sized for Latin/Cyrillic scripts. CJK text packs far more speech into the same
character count, so lower the threshold when synthesizing it:

```elixir
# ~15.7 chars/sec for tr/en, ~6.1 for ja, ~4.1 for zh (measured on tts-rt-v2)
config :hipcall_tts, :soniox_max_text_length, 450
```

Longer text is split on sentence boundaries and the segments are concatenated.

## Introspection API

Query provider capabilities at runtime:

```elixir
# List all providers
HipcallTts.providers()
# => [:openai, :elevenlabs, :polly, :soniox]

# Get provider models
{:ok, models} = HipcallTts.models(:openai)

# Get provider voices
{:ok, voices} = HipcallTts.voices(:openai)

# Get supported languages
{:ok, languages} = HipcallTts.languages(:polly)

# Get provider capabilities
{:ok, caps} = HipcallTts.capabilities(:elevenlabs)
# => %{streaming: false, formats: ["mp3", "pcm", "ulaw_8000"], ...}

# Get models compatible with a specific voice (see Voice-Model Compatibility section)
{:ok, models} = HipcallTts.compatible_models(:polly, "Filiz")
```

## Voice-Model Compatibility

Each voice declares which models it supports via the `supported_models` field. Use `HipcallTts.compatible_models/2` to query compatible models for a voice, and invalid combinations are rejected at validation time.

```elixir
# Check which engines a Polly voice supports
{:ok, models} = HipcallTts.compatible_models(:polly, "Filiz")
# => [%{id: "standard", ...}]  (standard only)

{:ok, models} = HipcallTts.compatible_models(:polly, "Burcu")
# => [%{id: "neural", ...}]  (neural only)

{:ok, models} = HipcallTts.compatible_models(:polly, "Joanna")
# => [%{id: "standard", ...}, %{id: "neural", ...}]  (both)

# OpenAI and ElevenLabs voices support all models
{:ok, models} = HipcallTts.compatible_models(:openai, "nova")
# => [%{id: "tts-1", ...}, %{id: "tts-1-hd", ...}]
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

| Feature | OpenAI | AWS Polly | ElevenLabs | Soniox |
|---------|--------|-----------|------------|--------|
| Max Text | 4,096 chars | 3,000 chars | 10,000-40,000 chars | 1,100 chars (2 min audio cap) |
| Voices | 13 | 9+ | Custom + Library | 70 |
| Languages | 57 | 4 | 30+ | 63 |
| SSML | No | Yes | No | No |
| Voice Cloning | No | No | Yes | Yes (not exposed by this package) |

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
