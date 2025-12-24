# Changelog

## 0.1.0

- Initial release.
- Providers:
  - OpenAI (request/response mode)
  - AWS Polly
- Unified API:
  - `HipcallTts.generate/1`
- Features:
  - Automatic text splitting based on provider limits
  - Audio concatenation for multi-part results
  - Configurable retries with backoff
  - Telemetry events for generate/http/retry/split


