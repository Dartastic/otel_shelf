# Changelog

## [1.0.0-wip]

### Changed

- Requires `dartastic_opentelemetry ^1.1.0-beta.17` and
  `dartastic_opentelemetry_api >=1.0.0-rc.4 <1.0.0-rc.5`.
- First 1.0 release: the public API of this package is stable and
  follows semantic versioning from here on.

## [0.1.0] - 2026-08-10

### Added

- `otelShelfMiddleware({tracer, errorStatusBuilder})` — a shelf
  `Middleware` that opens a SERVER span per incoming request with
  `http.request.method`, `url.full`, `server.address`,
  `server.port`, `http.response.status_code`.
- Extracts the W3C `traceparent` header from inbound requests so
  the device/CLI client's trace stitches into this server span.
- 5xx flips span status to Error by default; 4xx does not (per
  OTel HTTP semconv — 4xx is client-side error). Override via
  `errorStatusBuilder`.
- Zone-scoped suppression
  (`runWithoutShelfInstrumentation` / async variant).
- 4 tests including end-to-end traceparent stitching.
