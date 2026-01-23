# HipcallTts Documentation

A multi-provider Text-to-Speech (TTS) client for Elixir with a unified API, automatic text splitting, retry logic, and comprehensive telemetry support.

**Version:** 0.1.0
**License:** MIT
**Repository:** [https://github.com/hipcall/hipcall_tts](https://github.com/hipcall/hipcall_tts)

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Configuration](#configuration)
5. [Making Requests](#making-requests)
6. [Provider Details](#provider-details)
   - [OpenAI](#openai)
   - [AWS Polly](#aws-polly)
   - [ElevenLabs](#elevenlabs)
7. [Introspection API](#introspection-api)
8. [Advanced Features](#advanced-features)
   - [Automatic Text Splitting](#automatic-text-splitting)
   - [Retry Logic](#retry-logic)
   - [Telemetry Events](#telemetry-events)
9. [Error Handling](#error-handling)
10. [Examples](#examples)

---

## Overview

HipcallTts provides a unified interface for generating speech audio from text using multiple TTS providers. It abstracts away provider-specific implementation details while offering:

- **Multi-provider support**: OpenAI, AWS Polly, and ElevenLabs
- **Automatic text splitting**: Handles texts exceeding provider limits
- **Retry with exponential backoff**: Configurable retry logic for resilience
- **Telemetry integration**: Comprehensive observability events
- **Parameter validation**: Schema-based validation using NimbleOptions

### Architecture

```
HipcallTts (Public API)
├── Provider (Behavior/Contract)
├── Registry (Provider Lookup)
├── Schema (Parameter Validation)
├── Config (Configuration Resolution)
├── Providers
│   ├── OpenAI
│   ├── Polly
│   └── ElevenLabs
├── TextSplitter (Auto-chunking)
├── AudioConcatenator (Binary Merging)
├── Retry (Exponential Backoff)
└── Telemetry (Event Emission)
```

---

## Installation

Add `hipcall_tts` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hipcall_tts, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

---

## Quick Start

### 1. Configure a Provider

Add provider credentials to your `config/config.exs`:

```elixir
config :hipcall_tts, :providers,
  openai: [
    api_key: {:system, "OPENAI_API_KEY"}
  ]
```

### 2. Generate Speech

```elixir
{:ok, audio_binary} = HipcallTts.generate(
  provider: :openai,
  text: "Hello, world!",
  voice: "nova"
)

# Save to file
File.write!("output.mp3", audio_binary)
```

---

## Configuration

### Configuration Structure

Provider configuration is stored under the `:hipcall_tts` application key:

```elixir
# config/config.exs or config/runtime.exs
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
    region: {:system, "AWS_REGION"},
    default_model: "standard",
    default_voice: "Joanna",
    default_format: "mp3"
  ]
```

### Environment Variable Resolution

Use the `{:system, "ENV_VAR"}` tuple syntax to read values from environment variables at runtime:

```elixir
api_key: {:system, "OPENAI_API_KEY"}
# Resolves to System.get_env("OPENAI_API_KEY") at runtime
```

### Runtime Credential Override

You can override credentials per-request using function parameters:

```elixir
HipcallTts.generate(
  provider: :openai,
  text: "Hello",
  api_key: "sk-custom-key-for-this-request"
)
```

---

## Making Requests

### Main Function: `generate/1`

The primary function for generating speech audio.

**Signature:**
```elixir
@spec generate(params) :: {:ok, binary()} | {:error, map()}
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `provider` | atom | Yes | `:openai`, `:elevenlabs`, or `:polly` |
| `text` | string | Yes | Text to synthesize |
| `voice` | string | No | Voice identifier (provider-specific) |
| `model` | string | No | Model identifier |
| `format` | string | No | Audio format (default: `"mp3"`) |
| `sample_rate` | integer | No | Sample rate in Hz (default: `22050`) |
| `speed` | float | No | Speech speed multiplier (default: `1.0`) |
| `pitch` | float | No | Pitch adjustment in semitones (default: `0.0`) |
| `language` | string | No | Language code |
| `api_key` | string | No | Override API key |
| `provider_opts` | keyword | No | Provider-specific options |
| `retry_opts` | keyword | No | Retry configuration |

**Example:**
```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :openai,
  text: "Welcome to our application!",
  voice: "alloy",
  model: "tts-1-hd",
  format: "mp3",
  speed: 1.0
)
```

### Return Values

**Success:**
```elixir
{:ok, <<binary_audio_data>>}
```

**Error:**
```elixir
{:error, %{
  code: :http_error,
  message: "Request failed with status 401",
  provider: :openai,
  status: 401,
  headers: [...]
}}
```

---

## Provider Details

### OpenAI

OpenAI's Text-to-Speech API offers high-quality voice synthesis.

**Endpoint:** `https://api.openai.com/v1/audio/speech`

#### Configuration

```elixir
config :hipcall_tts, :providers,
  openai: [
    api_key: {:system, "OPENAI_API_KEY"},
    base_url: "https://api.openai.com",
    default_model: "tts-1",
    default_voice: "nova",
    default_format: "mp3"
  ]
```

#### Models

| Model ID | Description |
|----------|-------------|
| `tts-1` | Standard quality, faster generation |
| `tts-1-hd` | High quality, slower generation |

#### Voices

| Voice ID | Gender | Description |
|----------|--------|-------------|
| `alloy` | Neutral | Balanced, versatile voice |
| `echo` | Male | Deep, resonant voice |
| `fable` | Neutral | Warm, storytelling voice |
| `onyx` | Male | Strong, authoritative voice |
| `nova` | Female | Clear, professional voice |
| `shimmer` | Female | Soft, gentle voice |

#### Supported Languages

English, Turkish, German, Spanish, French, Italian, Portuguese, Russian, Japanese, Korean, Chinese

#### Capabilities

| Feature | Value |
|---------|-------|
| Max Text Length | 4,096 characters |
| Formats | `mp3`, `opus`, `aac`, `flac` |
| Sample Rates | 22050, 44100 Hz |
| Streaming | Not implemented |

#### Example

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :openai,
  text: "Hello from OpenAI!",
  voice: "nova",
  model: "tts-1-hd",
  format: "mp3"
)
```

---

### AWS Polly

Amazon Polly offers natural-sounding text-to-speech with SSML support.

**Endpoint:** `https://polly.<region>.amazonaws.com/v1/speech`

#### Configuration

```elixir
config :hipcall_tts, :providers,
  polly: [
    access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
    secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"},
    region: {:system, "AWS_REGION"},           # Optional, defaults to "us-east-1"
    session_token: {:system, "AWS_SESSION_TOKEN"},  # Optional, for temporary credentials
    default_model: "standard",
    default_voice: "Joanna",
    default_format: "mp3"
  ]
```

#### Models (Engines)

| Model ID | Description |
|----------|-------------|
| `standard` | Standard Polly engine |
| `neural` | Neural engine (higher quality, region/voice dependent) |

#### Voices

**English (US):**
| Voice ID | Gender |
|----------|--------|
| `Joanna` | Female |
| `Matthew` | Male |

**English (UK):**
| Voice ID | Gender |
|----------|--------|
| `Amy` | Female |
| `Brian` | Male |

**German:**
| Voice ID | Gender |
|----------|--------|
| `Marlene` | Female |
| `Daniel` | Male |
| `Vicki` | Female |

**Turkish:**
| Voice ID | Gender |
|----------|--------|
| `Filiz` | Female |
| `Burcu` | Female |

#### Capabilities

| Feature | Value |
|---------|-------|
| Max Text Length | 3,000 characters |
| Formats | `mp3`, `ogg_vorbis`, `pcm` |
| Sample Rates | 8000, 16000, 22050 Hz |
| SSML Support | Yes (auto-detected) |
| Streaming | Not implemented |

#### SSML Support

Polly automatically detects SSML when your text starts with `<speak>`:

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :polly,
  text: "<speak>Hello <break time='500ms'/> World!</speak>",
  voice: "Joanna"
)
```

#### Example

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :polly,
  text: "Hello from Amazon Polly!",
  voice: "Joanna",
  model: "neural",
  format: "mp3",
  region: "us-east-1"
)
```

---

### ElevenLabs

ElevenLabs offers highly realistic, emotionally expressive voice synthesis.

**Endpoint:** `https://api.elevenlabs.io/v1/text-to-speech`

#### Configuration

```elixir
config :hipcall_tts, :providers,
  elevenlabs: [
    api_key: {:system, "ELEVENLABS_API_KEY"},
    default_model: "eleven_flash_v2_5",
    default_voice: "Xb7hH8MSUJpSbSDYk0k2",
    default_format: "mp3"
  ]
```

#### Models

| Model ID | Description | Max Text |
|----------|-------------|----------|
| `eleven_multilingual_v2` | Most life-like, emotionally rich, 29 languages | 10,000 chars |
| `eleven_flash_v2_5` | Ultra-low latency, 32 languages | 40,000 chars |

#### Sample Voices

| Voice ID | Name | Gender | Language |
|----------|------|--------|----------|
| `Xb7hH8MSUJpSbSDYk0k2` | Alice | Female | English |
| `TX3LPaxmHKxFdv7VOQHJ` | Liam | Male | English |
| Custom voice IDs | - | - | Various |

> Note: ElevenLabs supports custom and cloned voices. Use the ElevenLabs dashboard to find voice IDs.

#### Supported Languages (30+)

Arabic, Bulgarian, Chinese, Croatian, Czech, Danish, Dutch, English, Filipino, Finnish, French, German, Greek, Hindi, Hungarian, Indonesian, Italian, Japanese, Korean, Malay, Norwegian, Polish, Portuguese, Romanian, Russian, Slovak, Spanish, Swedish, Tamil, Turkish, Ukrainian, Vietnamese

#### Voice Settings (Provider Options)

ElevenLabs supports advanced voice settings via `provider_opts`:

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :elevenlabs,
  text: "Hello with custom settings!",
  voice: "Xb7hH8MSUJpSbSDYk0k2",
  provider_opts: [
    stability: 0.5,           # Voice stability (0.0 - 1.0)
    similarity_boost: 0.8,    # Similarity to original voice (0.0 - 1.0)
    style: 0.5,               # Voice style intensity
    use_speaker_boost: true,  # Enable speaker boost
    speed: 1.0                # Speech speed
  ]
)
```

#### Capabilities

| Feature | Value |
|---------|-------|
| Max Text Length | 10,000 - 40,000 characters (model-dependent) |
| Formats | `mp3`, `pcm`, `ulaw_8000` |
| Sample Rates | 22050, 24000, 44100, 48000 Hz |
| Streaming | Not implemented |

#### Example

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :elevenlabs,
  text: "Welcome to ElevenLabs text-to-speech!",
  voice: "Xb7hH8MSUJpSbSDYk0k2",
  model: "eleven_multilingual_v2",
  format: "mp3",
  sample_rate: 44100
)
```

---

## Introspection API

HipcallTts provides functions to query provider capabilities at runtime.

### List Available Providers

```elixir
HipcallTts.providers()
# => [:openai, :elevenlabs, :polly]
```

### Get Provider Models

```elixir
{:ok, models} = HipcallTts.models(:openai)
# => [
#   %{id: "tts-1", name: "TTS-1", description: "Standard quality...", languages: [...]},
#   %{id: "tts-1-hd", name: "TTS-1 HD", description: "High quality..."}
# ]
```

### Get Provider Voices

```elixir
{:ok, voices} = HipcallTts.voices(:openai)
# => [
#   %{id: "alloy", name: "Alloy", gender: :neutral, language: "en", locale: nil},
#   %{id: "nova", name: "Nova", gender: :female, language: "en", locale: nil},
#   ...
# ]
```

### Get Supported Languages

```elixir
{:ok, languages} = HipcallTts.languages(:polly)
# => [
#   %{code: "en-US", name: "English", locale: "US"},
#   %{code: "de-DE", name: "German", locale: "DE"},
#   ...
# ]
```

### Get Provider Capabilities

```elixir
{:ok, caps} = HipcallTts.capabilities(:elevenlabs)
# => %{
#   streaming: false,
#   formats: ["mp3", "pcm", "ulaw_8000"],
#   sample_rates: [22050, 24000, 44100, 48000],
#   max_text_length: 40000
# }
```

---

## Advanced Features

### Automatic Text Splitting

When text exceeds a provider's maximum length, HipcallTts automatically:

1. **Splits text** at sentence boundaries (`.`, `!`, `?`, `…`, etc.)
2. **Groups sentences** to maximize chunks within the limit
3. **Generates audio** for each chunk
4. **Concatenates** the audio segments

This is transparent to the caller - you receive a single audio binary.

**Example with long text:**
```elixir
long_text = """
This is a very long text that exceeds the provider's limit.
It will be automatically split into sentences.
Each sentence will be processed separately.
The audio will be concatenated seamlessly.
"""

{:ok, audio} = HipcallTts.generate(
  provider: :openai,  # 4096 char limit
  text: long_text,
  voice: "nova"
)
# Returns combined audio from all chunks
```

### Retry Logic

HipcallTts includes built-in retry with exponential backoff for resilient API calls.

#### Configuration

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :openai,
  text: "Hello",
  retry_opts: [
    max_attempts: 5,           # Maximum retry attempts (default: 3)
    initial_delay: 500,        # Initial delay in ms (default: 1000)
    max_delay: 10_000,         # Maximum delay in ms (default: 10000)
    backoff_factor: 2.0,       # Exponential factor (default: 2.0)
    retryable_errors: []       # Error codes to retry (default: all)
  ]
)
```

#### Backoff Formula

```
delay = min(initial_delay * (backoff_factor ^ attempt), max_delay)
```

Example with defaults:
- Attempt 1: 1000ms
- Attempt 2: 2000ms
- Attempt 3: 4000ms
- (capped at max_delay)

#### Retry-After Header

When providers return `Retry-After` headers (common with 429 Too Many Requests), HipcallTts respects the specified delay.

### Telemetry Events

HipcallTts emits telemetry events for monitoring and observability.

#### Available Events

| Event | When | Metadata |
|-------|------|----------|
| `[:hipcall_tts, :generate, :start]` | Before generation | provider, text_length |
| `[:hipcall_tts, :generate, :stop]` | After success | provider, text_length, audio_size, format |
| `[:hipcall_tts, :generate, :error]` | On error | provider, text_length, error |
| `[:hipcall_tts, :generate, :exception]` | On exception | provider, kind, error, stacktrace |
| `[:hipcall_tts, :http, :request]` | HTTP request complete | provider, method, url, status_code |
| `[:hipcall_tts, :retry, :attempt]` | Retry attempt | provider, attempt, delay, error |
| `[:hipcall_tts, :text, :split]` | Text was split | provider, original_length, chunks |

#### Attaching Handlers

```elixir
:telemetry.attach(
  "hipcall-tts-logger",
  [:hipcall_tts, :generate, :stop],
  fn event, measurements, metadata, _config ->
    Logger.info("TTS generated #{metadata.audio_size} bytes in #{measurements.duration}ms")
  end,
  nil
)
```

---

## Error Handling

All errors return a normalized map structure:

```elixir
{:error, %{
  code: atom,           # Error type
  message: string,      # Human-readable message
  provider: atom,       # Which provider failed
  status: integer | nil, # HTTP status code (if applicable)
  headers: list | nil   # Response headers (if applicable)
}}
```

### Common Error Codes

| Code | Description |
|------|-------------|
| `:validation_error` | Invalid parameters |
| `:http_error` | HTTP request failed |
| `:network_error` | Network connectivity issue |
| `:timeout` | Request timed out |
| `:authentication_error` | Invalid API credentials |
| `:rate_limited` | Too many requests |
| `:provider_error` | Provider-specific error |

### Handling Errors

```elixir
case HipcallTts.generate(provider: :openai, text: "Hello") do
  {:ok, audio} ->
    File.write!("output.mp3", audio)

  {:error, %{code: :rate_limited}} ->
    # Wait and retry
    Process.sleep(5000)
    retry_generation()

  {:error, %{code: :validation_error, message: msg}} ->
    Logger.error("Invalid parameters: #{msg}")

  {:error, error} ->
    Logger.error("TTS failed: #{inspect(error)}")
end
```

---

## Examples

### Basic Usage

```elixir
# Simple generation with defaults
{:ok, audio} = HipcallTts.generate(
  provider: :openai,
  text: "Hello, world!"
)
File.write!("hello.mp3", audio)
```

### Multiple Voices Comparison

```elixir
voices = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]

for voice <- voices do
  {:ok, audio} = HipcallTts.generate(
    provider: :openai,
    text: "This is the #{voice} voice.",
    voice: voice
  )
  File.write!("voice_#{voice}.mp3", audio)
end
```

### Concurrent Generation

```elixir
texts = [
  "Welcome to our service.",
  "Please hold while we connect you.",
  "Thank you for your patience."
]

results =
  texts
  |> Task.async_stream(fn text ->
    HipcallTts.generate(
      provider: :openai,
      text: text,
      voice: "nova"
    )
  end, max_concurrency: 3)
  |> Enum.map(fn {:ok, result} -> result end)
```

### Dynamic Provider Selection

```elixir
def generate_speech(text, opts \\ []) do
  provider = Keyword.get(opts, :provider, :openai)

  # Get available voices for the provider
  {:ok, voices} = HipcallTts.voices(provider)
  default_voice = List.first(voices).id

  HipcallTts.generate(
    provider: provider,
    text: text,
    voice: Keyword.get(opts, :voice, default_voice)
  )
end
```

### Building a Voice Selection UI

```elixir
defmodule VoiceSelector do
  def get_options do
    for provider <- HipcallTts.providers() do
      {:ok, voices} = HipcallTts.voices(provider)
      {:ok, caps} = HipcallTts.capabilities(provider)

      %{
        provider: provider,
        voices: Enum.map(voices, &%{id: &1.id, name: &1.name, gender: &1.gender}),
        formats: caps.formats,
        max_length: caps.max_text_length
      }
    end
  end
end
```

### AWS Polly with SSML

```elixir
ssml_text = """
<speak>
  Welcome to <emphasis level="strong">HipcallTts</emphasis>.
  <break time="500ms"/>
  This message uses <prosody rate="slow">SSML markup</prosody> for enhanced control.
</speak>
"""

{:ok, audio} = HipcallTts.generate(
  provider: :polly,
  text: ssml_text,
  voice: "Joanna",
  model: "neural"
)
```

### ElevenLabs with Voice Settings

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :elevenlabs,
  text: "This voice has custom emotional settings.",
  voice: "Xb7hH8MSUJpSbSDYk0k2",
  model: "eleven_multilingual_v2",
  provider_opts: [
    stability: 0.3,           # More variable/emotional
    similarity_boost: 0.9,    # Stay close to original voice
    style: 0.7,               # Higher style intensity
    use_speaker_boost: true
  ]
)
```

### With Custom Retry Configuration

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :openai,
  text: "Important message that must succeed.",
  voice: "nova",
  retry_opts: [
    max_attempts: 5,
    initial_delay: 2000,
    max_delay: 30_000,
    backoff_factor: 1.5
  ]
)
```

---

## Provider Comparison Table

| Feature | OpenAI | AWS Polly | ElevenLabs |
|---------|--------|-----------|------------|
| Max Text | 4,096 chars | 3,000 chars | 10,000-40,000 chars |
| Voices | 6 | 9+ | Custom + Library |
| Languages | 11 | 4 | 30+ |
| SSML | No | Yes | No |
| Neural Voices | Yes (HD) | Yes | Yes |
| Voice Cloning | No | No | Yes |
| Formats | mp3, opus, aac, flac | mp3, ogg, pcm | mp3, pcm, ulaw |
| Auth | API Key | AWS SigV4 | API Key |

---

## Troubleshooting

### Common Issues

**"Invalid API key"**
- Ensure your API key is correctly set in config or environment
- Check that `{:system, "ENV_VAR"}` syntax is used for env vars

**"Rate limited"**
- Reduce concurrent requests
- Increase retry delays
- Consider upgrading your API plan

**"Text too long"**
- Text splitting is automatic, but verify your text isn't exceeding memory limits
- Consider pre-splitting very large texts

**"Voice not found"**
- Use `HipcallTts.voices(provider)` to list available voices
- Ensure voice ID matches exactly (case-sensitive for some providers)

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `finch` | ~> 0.18 | HTTP client |
| `nimble_options` | ~> 1.1 | Parameter validation |
| `jason` | ~> 1.4 | JSON encoding/decoding |
| `telemetry` | ~> 1.2 | Observability events |

---

## License

MIT License - see [LICENSE](LICENSE) for details.
