# Changelog

## 0.5.0

- Add Soniox as a fourth provider (`:soniox`), using the `tts-rt-v2` model
- Soniox: 70 built-in voices and 63 languages, every voice speaks every language
- Soniox: `:language` is required by the API; locale-style values (`"tr-TR"`, `"tr_TR"`) are normalized to the bare ISO code, with a configurable `default_language` fallback
- Soniox: `speed` is validated against the model's 0.7-1.3 range before the request is sent
- Soniox: package formats are mapped onto Soniox `audio_format` values; `ogg_vorbis` is rejected at validation
- Soniox: the schema's default `sample_rate` of 22050 (which Soniox accepts for no format) is omitted rather than forwarded
- Soniox: forward `reduce_silence` and `bitrate` via `provider_opts`, with validation — `bitrate` is rejected for lossless formats (Soniox returns a 400) and checked against the per-codec list
- Soniox: document the expressive layer (audio tags, written emphasis, punctuation), which needs no code since it travels inside `:text`
- Soniox: `max_text_length` defaults to 1100 characters to stay under the API's 2-minute audio cap, and is configurable via `config :hipcall_tts, :soniox_max_text_length` for denser scripts
- `HipcallTts.Schema`: `:provider` now accepts `:soniox`; documented that the accepted `speed` range is provider-specific
- Docs: add a "parameter support by provider" matrix — the schema accepts every parameter for every provider, but `language` and `sample_rate` only reach Soniox, `speed` is ignored by Polly, and `pitch` is not implemented by any provider
- Docs: add the credential-override parameters (`api_organization`, `access_key_id`, `secret_access_key`, `session_token`, `region`) that were missing from the parameter table
- Docs: add a minimal working request per provider, and guidance on top-level parameters vs `provider_opts`
- Docs: refresh the provider comparison table against the values the package actually reports
- Docs: add a "working with the returned audio" section — writing to a file with the right extension, format/MIME table, serving over HTTP, Base64, and the headerless raw-PCM caveat
- Docs: record two pre-existing gotchas found while verifying the above — Polly with `format: "pcm"` fails unless `sample_rate` is set to 8000/16000 (the schema default of 22050 is invalid for PCM on AWS), and ElevenLabs' `"ulaw_8000"` is reported by `capabilities/1` but rejected by the schema's `:format` enum, so it is only reachable via `provider_opts`

## 0.4.0

- Add voice-model compatibility: each voice now declares its `supported_models` field
- Add `supported_models` field to the `voice` type in `HipcallTts.Provider`
- Add `compatible_models/1` callback to `HipcallTts.Provider` behaviour
- Add `HipcallTts.compatible_models/2` to query compatible models for a given voice
- All providers: `validate_params/1` now rejects invalid voice-model combinations with a clear error message

## 0.3.0

- Update voice `language` field to support arrays for multilingual voices (`String.t() | [String.t()]`)
- ElevenLabs: Add per-voice multilingual language support (Alice, Brian, Callum, Belma, Doga)
- OpenAI: Add 7 new voices (Ash, Ballad, Coral, Sage, Verse, Marin, Cedar) for a total of 13
- OpenAI: Expand supported languages from 11 to 57 (full Whisper language set)
- Polly: Add all English (US), English (UK), and German voices from AWS docs

## 0.2.1

- Remove Meloxia voice from ElevenLabs provider (discontinued by ElevenLabs)

## 0.1.0

- Initial release.
- Providers:
  - OpenAI (request/response mode)
  - AWS Polly
  - ElevenLabs
- Unified API:
  - `HipcallTts.generate/1`
- Introspection API:
  - `HipcallTts.providers/0`
  - `HipcallTts.models/1`
  - `HipcallTts.voices/1`
  - `HipcallTts.languages/1`
  - `HipcallTts.capabilities/1`
- Features:
  - Automatic text splitting based on provider limits
  - Audio concatenation for multi-part results
  - Configurable retries with exponential backoff
  - Telemetry events for generate/http/retry/split


