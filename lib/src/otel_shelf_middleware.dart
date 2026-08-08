// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
// `shelf` also exports a `Server` type; hide it so the unprefixed `Server`
// here is unambiguously the OTel semconv attribute group.
import 'package:shelf/shelf.dart' hide Server;

import 'shelf_suppression.dart';

const _tracerName = 'otel_shelf';

class _HeaderGetter implements TextMapGetter<String> {
  _HeaderGetter(this._headers);
  final Map<String, String> _headers;

  @override
  String? get(String key) {
    final lower = key.toLowerCase();
    for (final entry in _headers.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  @override
  Iterable<String> keys() => _headers.keys;
}

/// Returns a shelf [Middleware] that opens a `SERVER` span per
/// incoming request.
///
/// Extracts the W3C `traceparent` (and optional `tracestate`) from
/// the request headers so client-side spans on the caller stitch
/// into this server-side span.
///
/// ```dart
/// final handler = Pipeline()
///     .addMiddleware(otelShelfMiddleware())
///     .addHandler(myRouter);
/// ```
///
/// Span shape:
/// - name: `HTTP <METHOD>` (low cardinality; URL is on `url.full`)
/// - kind: `SERVER`
/// - attributes: `http.request.method`, `url.full`,
///   `server.address`, `http.response.status_code`
/// - status: `Error` on 5xx (4xx is "client error" — kept unset by
///   default per OTel HTTP semconv; override with [errorStatusBuilder]
///   if you want 4xx to flip status).
Middleware otelShelfMiddleware({
  Tracer? tracer,
  bool Function(int statusCode)? errorStatusBuilder,
}) {
  final t = tracer ?? OTel.tracerProvider().getTracer(_tracerName);
  final propagator = W3CTraceContextPropagator();
  final isError = errorStatusBuilder ?? (code) => code >= 500;

  return (Handler inner) {
    return (Request request) async {
      if (shelfInstrumentationSuppressed()) return inner(request);

      final headers = Map<String, String>.from(request.headers);
      final extractedContext = propagator.extract(
        Context.current,
        headers,
        _HeaderGetter(headers),
      );

      final method = request.method.toUpperCase();
      final url = request.requestedUri;
      final attrs = <String, Object>{
        Http.httpRequestMethod.key: method,
        Url.urlFull.key: url.toString(),
      };
      if (url.host.isNotEmpty) {
        attrs[Server.serverAddress.key] = url.host;
      }
      if (url.hasPort) attrs[Server.serverPort.key] = url.port;

      final span = t.startSpan(
        'HTTP $method',
        kind: SpanKind.server,
        context: extractedContext,
        attributes: OTel.attributesFromMap(attrs),
      );

      try {
        final response = await inner(request);
        span.addAttributes(OTel.attributes([
          OTel.attributeInt(
            Http.httpResponseStatusCode.key,
            response.statusCode,
          ),
        ]));
        if (isError(response.statusCode)) {
          span.setStatus(
            SpanStatusCode.Error,
            'HTTP ${response.statusCode}',
          );
        }
        return response;
      } catch (e, st) {
        span.addAttributes(OTel.attributes([
          OTel.attributeString(
            ErrorAttributes.errorType.key,
            e.runtimeType.toString(),
          ),
        ]));
        span.recordException(e, stackTrace: st);
        span.setStatus(SpanStatusCode.Error, e.toString());
        rethrow;
      } finally {
        span.end();
      }
    };
  };
}
