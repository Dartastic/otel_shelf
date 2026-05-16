// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_shelf/otel_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _MemorySpanExporter implements SpanExporter {
  final List<Span> spans = [];
  bool _shutdown = false;

  @override
  Future<void> export(List<Span> s) async {
    if (_shutdown) return;
    spans.addAll(s);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _shutdown = true;
  }
}

Map<String, Object> _attrs(Span span) =>
    {for (final a in span.attributes.toList()) a.key: a.value};

Future<Response> okHandler(Request _) async {
  return Response.ok('hi');
}

Future<Response> boom500Handler(Request _) async {
  return Response.internalServerError(body: 'no');
}

void main() {
  group('otelShelfMiddleware', () {
    late _MemorySpanExporter exporter;

    setUp(() async {
      await OTel.reset();
      exporter = _MemorySpanExporter();
      await OTel.initialize(
        serviceName: 'shelf-otel-test',
        detectPlatformResources: false,
        spanProcessor: SimpleSpanProcessor(exporter),
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('emits SERVER span with http.* + url.* + status', () async {
      final handler = const Pipeline()
          .addMiddleware(otelShelfMiddleware())
          .addHandler(okHandler);

      final response = await handler(
        Request('GET', Uri.parse('https://api.example.com/users')),
      );
      expect(response.statusCode, equals(200));

      final span = exporter.spans.single;
      expect(span.kind, equals(SpanKind.server));
      expect(span.name, equals('HTTP GET'));
      final attrs = _attrs(span);
      expect(attrs['http.request.method'], equals('GET'));
      expect(attrs['url.full'], contains('/users'));
      expect(attrs['server.address'], equals('api.example.com'));
      expect(attrs['http.response.status_code'], equals(200));
      expect(span.status, isNot(equals(SpanStatusCode.Error)));
    });

    test('5xx response flips span to Error (4xx does not by default)',
        () async {
      final handler = const Pipeline()
          .addMiddleware(otelShelfMiddleware())
          .addHandler(boom500Handler);

      await handler(
        Request('POST', Uri.parse('https://api.example.com/users')),
      );

      final span = exporter.spans.single;
      expect(span.status, equals(SpanStatusCode.Error));
      expect(_attrs(span)['http.response.status_code'], equals(500));
    });

    test('extracts traceparent from inbound headers — stitches to upstream',
        () async {
      const upstreamTraceId = '4bf92f3577b34da6a3ce929d0e0e4736';
      const upstreamSpanId = '00f067aa0ba902b7';
      const traceparent = '00-$upstreamTraceId-$upstreamSpanId-01';

      final handler = const Pipeline()
          .addMiddleware(otelShelfMiddleware())
          .addHandler(okHandler);

      await handler(
        Request(
          'GET',
          Uri.parse('https://api.example.com/users'),
          headers: {'traceparent': traceparent},
        ),
      );

      final span = exporter.spans.single;
      expect(span.spanContext.traceId.toString(), equals(upstreamTraceId));
      expect(
        span.spanContext.parentSpanId?.toString(),
        equals(upstreamSpanId),
      );
    });

    test('runWithoutShelfInstrumentationAsync bypasses spans', () async {
      final handler = const Pipeline()
          .addMiddleware(otelShelfMiddleware())
          .addHandler(okHandler);
      await runWithoutShelfInstrumentationAsync(() async {
        await handler(
          Request('GET', Uri.parse('https://api.example.com/users')),
        );
      });
      expect(exporter.spans, isEmpty);
    });
  });
}
