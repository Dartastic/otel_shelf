// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

// A minimal shelf server with OpenTelemetry instrumentation:
// one SERVER span per request, stitched to the caller's trace via
// the inbound W3C `traceparent` header.
//
// Run it, then: curl http://localhost:8080/hello

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_shelf/otel_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  // Configure exporters/endpoint via the standard OTEL_* environment
  // variables (e.g. OTEL_EXPORTER_OTLP_ENDPOINT).
  await OTel.initialize(serviceName: 'otel-shelf-example');

  final handler = const Pipeline()
      .addMiddleware(otelShelfMiddleware())
      .addHandler(
        (request) => Response.ok('hello, ${request.url.path}\n'),
      );

  final server = await io.serve(handler, 'localhost', 8080);
  print('Serving at http://${server.address.host}:${server.port}');
}
