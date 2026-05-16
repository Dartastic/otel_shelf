# otel_shelf

OpenTelemetry instrumentation for
[`package:shelf`](https://pub.dev/packages/shelf) — server-side
complement to the various client-side wrappers (http, dio, grpc,
chopper). One SERVER span per incoming request, with W3C
traceparent extracted from inbound headers so distributed traces
stitch end-to-end.

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:otel_shelf/otel_shelf.dart';

final handler = const Pipeline()
    .addMiddleware(otelShelfMiddleware())
    .addHandler(myRouter);

await io.serve(handler, 'localhost', 8080);
```

Each request:
- name: `HTTP <METHOD>` (URL is on `url.full`, kept off the name
  for cardinality)
- kind: SERVER
- `http.request.method`, `http.method` (legacy), `url.full`,
  `server.address`, `server.port`, `http.response.status_code`
- 5xx → span status `Error`. 4xx unset by default (per OTel HTTP
  semconv — override with `errorStatusBuilder`).

## Trace propagation

Extracts the W3C `traceparent` (and optional `tracestate`) from
inbound headers. A client using `otel_http`,
`otel_dio`, or `otel_chopper` injects those
headers automatically, and this middleware stitches the server
span into the same trace.

Suppression: `runWithoutShelfInstrumentationAsync`.

## License

Apache 2.0
