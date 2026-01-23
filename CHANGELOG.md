# Changelog

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


