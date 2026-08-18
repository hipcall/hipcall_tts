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
   - [Soniox](#soniox)
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

# The result is the raw bytes of a complete audio file — write them straight out.
# Use an extension matching the `:format` you asked for (default is "mp3").
File.write!("output.mp3", audio_binary)
```

See [Working with the returned audio](#working-with-the-returned-audio) for
serving over HTTP, Base64-encoding, and the raw-PCM caveat.

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
  ],
  soniox: [
    api_key: {:system, "SONIOX_API_KEY"},
    default_model: "tts-rt-v2",
    default_voice: "Mina",
    default_format: "mp3",
    default_language: "en"
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
| `provider` | atom | Yes | `:openai`, `:elevenlabs`, `:polly`, or `:soniox` |
| `text` | string | Yes | Text to synthesize |
| `voice` | string | No | Voice identifier (provider-specific) |
| `model` | string | No | Model identifier |
| `format` | string | No | Audio format (default: `"mp3"`) |
| `sample_rate` | integer | No | Sample rate in Hz (default: `22050`) |
| `speed` | float | No | Speech speed multiplier (default: `1.0`) |
| `pitch` | float | No | Pitch adjustment in semitones (default: `0.0`) |
| `language` | string | No | Language code |
| `provider_opts` | keyword | No | Provider-specific options, merged into the provider params |
| `retry_opts` | keyword | No | Retry configuration |

Credential overrides (all optional, all fall back to application config):

| Parameter | Type | Used by | Description |
|-----------|------|---------|-------------|
| `api_key` | string | OpenAI, ElevenLabs, Soniox | Per-request API key |
| `api_organization` | string | OpenAI | `OpenAI-Organization` header |
| `access_key_id` | string | Polly | AWS access key id |
| `secret_access_key` | string | Polly | AWS secret access key |
| `session_token` | string | Polly | AWS session token for temporary credentials |
| `region` | string | Polly | AWS region, e.g. `"eu-west-1"` |

### Which parameters each provider actually uses

The schema accepts every parameter for every provider, but a provider only
sends what its API supports. **A parameter a provider does not use is silently
ignored** — it does not raise and does not warn. Check this table before
relying on one.

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

Notes on the gaps:

* **`pitch` is not implemented by any provider.** It is accepted and defaulted
  by the schema but never reaches an API. Do not rely on it.
* **`sample_rate` is only honored by Soniox.** `capabilities/0` reports a
  `sample_rates` list for every provider, but that list describes what the
  service produces, not a value you can currently select for OpenAI,
  ElevenLabs, or Polly.
* **`language` is only used by Soniox**, where it is required. The other
  providers infer the language from the text or from the chosen voice.
* **`speed` ranges differ.** Soniox rejects anything outside 0.7–1.3 during
  `validate_params/1`; Polly ignores the parameter entirely.

### Minimal request per provider

The shortest call that works for each provider, assuming credentials are in
application config:

```elixir
# OpenAI — voice and model fall back to config defaults
HipcallTts.generate(provider: :openai, text: "Hello")

# ElevenLabs — voice is a voice ID string
HipcallTts.generate(provider: :elevenlabs, text: "Hello")

# AWS Polly — note that voice and model must be compatible, see
# "Voice-Model Compatibility" below
HipcallTts.generate(provider: :polly, text: "Hello", voice: "Joanna")

# Soniox — language is required by the API; omitting it falls back to
# `default_language` from config
HipcallTts.generate(provider: :soniox, text: "Merhaba", language: "tr")
```

A fully specified call looks the same for every provider:

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

### Top-level parameters vs `provider_opts`

`provider_opts` is merged into the provider params after the top-level ones, so
it can both add provider-specific options and override top-level values:

```elixir
# Adds an option that has no top-level equivalent
HipcallTts.generate(
  provider: :elevenlabs,
  text: "Hello",
  provider_opts: [stability: 0.3, similarity_boost: 0.9]
)

# Overrides credentials for this request only
HipcallTts.generate(
  provider: :soniox,
  text: "Merhaba",
  language: "tr",
  provider_opts: [api_key: "sk-..."]
)
```

Prefer `provider_opts` for anything provider-specific; the top-level schema is
intentionally not growing a key per provider feature.

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

### Working with the returned audio

`generate/1` returns the raw bytes of the encoded audio file — the same bytes
the provider's API sent back, with no wrapper:

```elixir
{:ok, audio} = HipcallTts.generate(provider: :soniox, text: "Merhaba", language: "tr")
# => {:ok, <<73, 68, 51, 4, 0, 0, 0, 0, 0, 34, 84, 83, 83, 69, ...>>}
```

Those first three bytes are `"ID3"` — this is a complete, playable MP3 file
already, tags and all. There is nothing to decode or convert.

**The return value does not tell you which format it is.** It is bytes, not a
struct, so the caller has to remember what it asked for in `:format`. Track it
alongside the binary if it can vary at runtime.

#### Writing to a file

Give the file the extension matching the `:format` you requested — a `.mp3`
name on FLAC bytes will confuse players and browsers:

| `:format` | Extension | MIME type | Notes |
|-----------|-----------|-----------|-------|
| `"mp3"` | `.mp3` | `audio/mpeg` | Default |
| `"wav"` | `.wav` | `audio/wav` | Soniox only |
| `"opus"` | `.opus` | `audio/opus` | |
| `"aac"` | `.aac` | `audio/aac` | |
| `"flac"` | `.flac` | `audio/flac` | |
| `"ogg_vorbis"` | `.ogg` | `audio/ogg` | Polly only |
| `"pcm"` | `.pcm` | `application/octet-stream` | Headerless, see below |
| `"ulaw_8000"` | `.ulaw` | `audio/basic` | ElevenLabs only, see caveat below |

Two caveats that the format lists do not make obvious:

* **Polly + `"pcm"` needs an explicit `sample_rate`.** The schema defaults
  `:sample_rate` to `22050`, and Polly forwards it, but AWS only accepts 8000 or
  16000 for PCM output — so the default combination fails with
  `InvalidSampleRateException`. Pass `sample_rate: 16000` (or `8000`)
  explicitly. The other Polly formats accept 22050 and work as-is.

* **`"ulaw_8000"` is not accepted by `:format`.** ElevenLabs reports it in
  `capabilities/1`, and the provider knows how to send it, but the schema's
  `:format` enum does not include it, so `format: "ulaw_8000"` fails validation.
  Reach it through `provider_opts` instead, which is merged after validation:

  ```elixir
  HipcallTts.generate(
    provider: :elevenlabs,
    text: "Hello",
    provider_opts: [format: "ulaw_8000"]
  )
  ```

```elixir
def save(text, format) do
  with {:ok, audio} <- HipcallTts.generate(
         provider: :soniox,
         text: text,
         language: "tr",
         format: format
       ) do
    path = "announcement.#{extension(format)}"
    File.write!(path, audio)
    {:ok, path}
  end
end

defp extension("ogg_vorbis"), do: "ogg"
defp extension("ulaw_8000"), do: "ulaw"
defp extension(format), do: format
```

#### Raw PCM has no header

`"pcm"` and `"ulaw_8000"` return raw samples with no container — no sample rate,
no channel count, nothing a player can read. Writing them to a file produces
something most players refuse to open. You have to supply those values yourself:

```bash
# Soniox pcm defaults to 24 kHz, 16-bit, mono
ffplay -f s16le -ar 24000 -ac 1 announcement.pcm
```

Prefer `"wav"` over `"pcm"` when a file has to stand on its own — it is the same
samples with a 44-byte header that makes them self-describing.

#### Serving over HTTP

In Phoenix or Plug, send the bytes with the matching content type:

```elixir
def announcement(conn, %{"text" => text}) do
  case HipcallTts.generate(provider: :soniox, text: text, language: "tr") do
    {:ok, audio} ->
      conn
      |> put_resp_content_type("audio/mpeg")
      |> send_resp(200, audio)

    {:error, error} ->
      conn |> put_status(502) |> json(%{error: error.message})
  end
end
```

#### Embedding in JSON

JSON cannot carry raw bytes, so Base64-encode when returning audio from a JSON
API or storing it in a text column:

```elixir
{:ok, audio} = HipcallTts.generate(provider: :openai, text: "Hello")
encoded = Base.encode64(audio)

# and back
{:ok, ^audio} = Base.decode64(encoded)
```

Note this inflates the payload by about a third.

#### Checking what you got

```bash
file announcement.mp3
# => Audio file with ID3 version 2.4.0, contains:
#    - MPEG ADTS, layer III, v2, 128 kbps, 24 kHz, Monaural

ffprobe -v error -show_entries format=duration \
  -show_entries stream=codec_name,sample_rate,channels \
  -of csv=p=0 announcement.mp3
# => mp3,24000,1
#    3.720000
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

### Soniox

Soniox provides a single unified multilingual model: every voice speaks every
supported language while keeping the same speaker identity.

**Endpoint:** `https://tts-rt.soniox.com/tts`

#### Configuration

```elixir
config :hipcall_tts, :providers,
  soniox: [
    api_key: {:system, "SONIOX_API_KEY"},
    default_model: "tts-rt-v2",
    default_voice: "Mina",
    default_format: "mp3",
    # Soniox requires a language on every request; used when the caller omits it.
    default_language: "en"
  ]
```

#### Models

| Model ID | Description | Notes |
|----------|-------------|-------|
| `tts-rt-v2` | Real-time multilingual model, 63 languages | Only model offered by this package |

> `tts-rt-v1` was removed by Soniox on 2026-08-31 and is deliberately not exposed.

#### Sample Voices

70 built-in voices (40 male, 30 female). All of them accept all 63 languages.

| Voice | Gender | Character |
|-------|--------|-----------|
| `Mina` | Female | Soft, thoughtful, steady pacing |
| `Emma` | Female | Smooth, relaxed, subtle warmth |
| `Daniel` | Male | Rich, steady, polished |
| `Adrian` | Male | Deep, crisp articulation |
| `Imogen` | Female | Clear British, professional |
| `Arjun` | Male | Deep, natural Indian accent |

Use `HipcallTts.voices(:soniox)` for the full catalog.

#### The `:language` parameter

Soniox rejects requests without a language, and expects a bare ISO code. The
provider normalizes locale-style values, so all of these resolve to `"tr"`:

```elixir
language: "tr"      # passed through
language: "tr-TR"   # normalized
language: "tr_TR"   # normalized
```

An unsupported language fails validation before the request is sent:

```elixir
HipcallTts.generate(provider: :soniox, text: "Hello", language: "zz-ZZ")
# => {:error, %{code: :error, message: "Invalid language: zz-ZZ", ...}}
```

When `:language` is omitted, `default_language` from config is used.

#### Speed

Soniox accepts `speed` between `0.7` and `1.3` — narrower than the general range
documented on `HipcallTts.Schema`. Values outside it are rejected locally rather
than producing an HTTP 400:

```elixir
HipcallTts.generate(provider: :soniox, text: "Hello", language: "en", speed: 2.0)
# => {:error, %{message: "Speed must be between 0.7 and 1.3", ...}}
```

#### Audio formats

Package format names are mapped onto Soniox `audio_format` values:

| Package `:format` | Soniox `audio_format` | Sample rates (Hz) |
|-------------------|-----------------------|-------------------|
| `mp3` | `mp3` | 16000, **24000**, 32000, 44100, 48000 |
| `wav` | `wav` | 8000, 16000, **24000**, 44100, 48000 |
| `opus` | `opus` | 8000, 16000, **24000**, 48000 |
| `aac` | `aac` | 16000, **24000**, 44100, 48000 |
| `flac` | `flac` | 16000, **24000**, 44100, 48000 |
| `pcm` | `pcm_s16le` | 8000, 16000, **24000**, 44100, 48000 |

`ogg_vorbis` is not supported and fails validation.

The schema defaults `:sample_rate` to `22050`, which Soniox accepts for no format
at all. That exact value is treated as "not specified" and omitted so Soniox
applies its own per-format default. A sample rate that the chosen format does not
support is likewise omitted rather than causing a 400.

#### Text length and the 2-minute cap

Soniox caps generated audio at **2 minutes of duration**, not by character count,
and audio past the cap is truncated silently. `max_text_length` is therefore a
character budget chosen to stay under 120 seconds of speech — and how many
characters that is depends on the script.

Measured on `tts-rt-v2` (voice `Mina`, speed 1.0):

| Script | Rate | 120s budget |
|--------|------|-------------|
| Latin/Cyrillic (`tr`, `en`) | ~15.7 chars/sec | ~1,880 chars |
| Japanese (`ja`) | ~6.1 chars/sec | ~730 chars |
| Chinese (`zh`) | ~4.1 chars/sec | ~490 chars |

The default of **1,100** is sized for Latin/Cyrillic text with margin for the
slowest supported speed. `capabilities/0` cannot see the request language, so
deployments that synthesize CJK text must lower it:

```elixir
config :hipcall_tts, :soniox_max_text_length, 450
```

Longer text is split on sentence boundaries by `HipcallTts.TextSplitter` and the
segments are concatenated.

#### Capabilities

| Feature | Value |
|---------|-------|
| Max Text Length | 1,100 characters (configurable) |
| Formats | `mp3`, `wav`, `opus`, `aac`, `flac`, `pcm` |
| Sample Rates | 8000, 16000, 24000, 32000, 44100, 48000 Hz |
| Streaming | Not implemented (Soniox offers a WebSocket API) |

#### Expressive delivery with audio tags

Soniox reads bracketed English tags in the text as delivery instructions rather
than speaking them. A tag applies to the words that follow it, and several can
appear in one utterance:

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :soniox,
  text: "[warm] Merhaba. [calm] Talebiniz inceleniyor, lütfen bekleyiniz.",
  voice: "Mina",
  language: "tr"
)
```

Available categories include emotion (`[happy]`, `[sad]`, `[excited]`,
`[nervous]`, `[calm]`, …), tone and manner (`[warm]`, `[stern]`, `[serious]`,
`[sincerely]`, `[reassuringly]`, `[dramatically]`, …) and non-lexical sounds
(`[laughs]`, `[sighs]`, …). The list is not exhaustive and Soniox recommends
testing a tag before relying on it.

Two rules worth remembering:

* **Tags are always written in English**, whatever the text language. `[sakin]`
  will be spoken aloud; `[calm]` will not.
* **Tags count toward `max_text_length`**, since they are part of `:text`.

There is no separate parameter for this — nothing in the package needs to know
about tags, they simply travel inside the text.

#### Emphasis and pacing inside the text

The same layer covers written emphasis, independent of the `:speed` parameter:

| Written form | Effect |
|--------------|--------|
| `UPPERCASE` | Stronger emphasis on the word |
| `*stress*` | Marked stress |
| `sooo` | Elongated vowel |
| `...` | Hesitation / pause |
| `—` | Sharper break |
| `?!` | Combined intonation |

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :soniox,
  text: "Talebiniz *onaylandı*. Teşekkür ederiz... iyi günler.",
  language: "tr"
)
```

Soniox's own guidance is to reach for a voice whose natural pacing already fits,
then shape individual moments with tags and punctuation, and only use `:speed`
when the delivery is globally too fast or slow.

#### Speed

Accepted range is `0.7` to `1.3`, narrower than the schema's general range.
Anything outside it is rejected by `validate_params/1` before a request is sent:

```elixir
HipcallTts.generate(provider: :soniox, text: "Merhaba", language: "tr", speed: 0.9)

HipcallTts.generate(provider: :soniox, text: "Merhaba", language: "tr", speed: 2.0)
# => {:error, %{message: "Speed must be between 0.7 and 1.3", ...}}
```

#### Soniox-only options via `provider_opts`

`reduce_silence` and `bitrate` are not part of `HipcallTts.Schema`, so they
travel through `provider_opts`:

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :soniox,
  text: "Merhaba. Talebiniz inceleniyor.",
  language: "tr",
  format: "mp3",
  provider_opts: [
    reduce_silence: true,   # shorten the gaps between words and sentences
    bitrate: 64_000         # lossy codecs only — see the table below
  ]
)
```

**`reduce_silence`** trims the pauses *between* words and sentences, which is
different from `:speed` — the words themselves are spoken at the same rate.

Its effect scales with how many pauses the text actually contains. Measured on
`tts-rt-v2` with voice `Daniel`, three runs each:

| Text | Off | On |
|------|-----|-----|
| `"Merhaba. Talebiniz alındı. İnceleniyor. Lütfen bekleyin. Teşekkürler."` | ~7.5s | ~5.0s (−33%) |
| One long sentence | no measurable change | no measurable change |

So it pays off for a run of short IVR prompts and does close to nothing for a
single flowing sentence. Note also that generation is not deterministic — the
same request varied by about 20% across runs here, so compare averages rather
than single results.

**`bitrate`** applies only to the lossy codecs. Sending it with `wav`, `flac` or
`pcm` is rejected by Soniox with a 400, so the provider validates it up front:

| `:format` | Accepted bitrates (bps) | Default |
|-----------|-------------------------|---------|
| `"mp3"` | 32000, 64000, 96000, 128000, 192000, 256000, 320000 | 128000 |
| `"opus"` | 16000, 32000, 64000, 96000, 128000, 256000 | 64000 |
| `"aac"` | 32000, 64000, 96000, 128000, 192000, 256000, 320000 | 128000 |
| `"wav"`, `"flac"`, `"pcm"` | not applicable | — |

```elixir
HipcallTts.generate(
  provider: :soniox,
  text: "Merhaba",
  language: "tr",
  format: "wav",
  provider_opts: [bitrate: 128_000]
)
# => {:error, %{message: "Bitrate is not supported for the wav format", ...}}
```

Dropping the bitrate is a straightforward way to shrink cached announcements —
32 kbps mp3 is roughly a quarter the size of the 128 kbps default, and for
speech played down a phone line the difference is largely inaudible.

#### One voice across languages

Because every voice speaks every language, the same speaker identity can carry a
multilingual product without switching voices:

```elixir
for {lang, text} <- [
      {"tr", "Talebiniz inceleniyor."},
      {"en", "Your ticket is being reviewed."},
      {"de", "Ihr Ticket wird geprüft."}
    ] do
  {:ok, audio} = HipcallTts.generate(
    provider: :soniox,
    text: text,
    voice: "Mina",
    language: lang
  )

  File.write!("status_#{lang}.mp3", audio)
end
```

Soniox also handles more than one language inside a single utterance, so a
foreign brand name or term in an otherwise Turkish sentence does not need to be
split out.

#### Features this package does not expose

`GET /v1/tts-models` reports several capabilities that `tts-rt-v2` supports but
that the package has no surface for:

| Capability | Status |
|------------|--------|
| WebSocket streaming | Not implemented — `stream/1` returns an error |
| Voice cloning (20s reference clip) | Not implemented |
| Word timestamps | Not implemented |

There is also **no pronunciation control** — no SSML, no `<phoneme>`, no custom
lexicon. When Soniox mispronounces a name or brand, the only lever is respelling
it phonetically in the text. (AWS Polly, by contrast, accepts SSML `<phoneme>`.)

#### Rate limits

Soniox applies 100 requests/minute and **3 concurrent requests** per account.
Split segments are generated sequentially, so a single `generate/1` call stays
within the concurrency limit, but parallel callers may not.

#### Example

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :soniox,
  text: "Hipcall müşteri hizmetlerini aradınız.",
  voice: "Mina",
  model: "tts-rt-v2",
  language: "tr-TR",
  format: "mp3"
)
```

---

## Introspection API

HipcallTts provides functions to query provider capabilities at runtime.

### List Available Providers

```elixir
HipcallTts.providers()
# => [:openai, :elevenlabs, :polly, :soniox]
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

### Soniox with a locale-style language

The `:language` code comes straight from whatever your caller already has, so
locale strings do not need normalizing first:

```elixir
{:ok, audio} = HipcallTts.generate(
  provider: :soniox,
  text: "Hipcall müşteri hizmetlerini aradınız.",
  voice: "Mina",
  language: "tr-TR",   # normalized to "tr" before the request
  format: "mp3"
)
```

Picking a voice by gender, since every Soniox voice speaks every language:

```elixir
{:ok, voices} = HipcallTts.voices(:soniox)
female = Enum.filter(voices, &(&1.gender == :female))

{:ok, audio} = HipcallTts.generate(
  provider: :soniox,
  text: "Merhaba",
  voice: hd(female).id,
  language: "tr"
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

Counts below come from `HipcallTts.models/1`, `voices/1`, `languages/1` and
`capabilities/1`, so they stay in step with what the package actually exposes.

| Feature | OpenAI | AWS Polly | ElevenLabs | Soniox |
|---------|--------|-----------|------------|--------|
| Max Text | 4,096 chars | 3,000 chars | 40,000 chars | 1,100 chars (2 min audio cap) |
| Models | 2 | 2 (engines) | 2 | 1 |
| Voices | 13 | 22 | 7 + custom | 70 |
| Languages | 57 | 4 | 32 | 63 |
| SSML | No | Yes | No | No |
| Voice Cloning | No | No | Yes | Yes (not exposed) |
| Formats | mp3, opus, aac, flac | mp3, ogg_vorbis, pcm | mp3, pcm, ulaw_8000 | mp3, wav, opus, aac, flac, pcm |
| `language` used | No | No | No | **Yes (required)** |
| `sample_rate` used | No | No | No | Yes |
| `speed` used | Yes | Yes | No | Yes (0.7–1.3) |
| Auth | API Key | AWS SigV4 | API Key | API Key |

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
