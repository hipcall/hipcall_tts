# Changelog

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


