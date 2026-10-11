# Changelog

## [2.0.0] - 2026-10-11

### Changed

- **Breaking:** depends on `dartastic_opentelemetry_api` only, no
  longer on the SDK. The application chooses and initializes the
  OpenTelemetry SDK. Parameters typed with SDK classes now use the
  API types (`APITracer`, `APISpan`); SDK instances are still
  accepted wherever an API type is expected.
- Inbound context is extracted with the app's configured propagators
  (`OTelAPI.textMapPropagator`: W3C trace context and baggage by
  default, `OTEL_PROPAGATORS` to change them). Previously only W3C
  trace context was extracted, so inbound baggage was dropped.

## [1.0.0] - 2026-10-11

### Changed

- Requires `dartastic_opentelemetry_api >=1.0.0-rc.4 <1.0.0-rc.5`.
- **Breaking:** depends on `dartastic_opentelemetry_api` only, no
  longer on the SDK. The application chooses and initializes the
  OpenTelemetry SDK. Parameters and fields typed with SDK classes
  now use the API types (`APITracer`, `APISpan`, `APILogger`, ...);
  SDK instances are still accepted wherever an API type is expected.

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
