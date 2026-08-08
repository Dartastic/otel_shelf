// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

const Symbol _suppressKey = #otel_shelf_suppress;

/// Whether shelf instrumentation is suppressed in the current [Zone].
///
/// True inside a [runWithoutShelfInstrumentation] or
/// [runWithoutShelfInstrumentationAsync] body; the middleware checks
/// this and passes requests through without opening a span.
bool shelfInstrumentationSuppressed() {
  return Zone.current[_suppressKey] == true;
}

/// Runs [body] with shelf instrumentation suppressed.
///
/// Any request handled inside [body] (in the same [Zone]) bypasses
/// the middleware — no SERVER span is opened. Use the async variant,
/// [runWithoutShelfInstrumentationAsync], when [body] awaits.
T runWithoutShelfInstrumentation<T>(T Function() body) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}

/// Async variant of [runWithoutShelfInstrumentation]: runs [body]
/// with shelf instrumentation suppressed until its future completes.
Future<T> runWithoutShelfInstrumentationAsync<T>(
  Future<T> Function() body,
) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}
