import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers requests from a routing table of "METHOD /path" → (status, body)
/// and records what was sent.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes, {this.handlers = const {}});

  final Map<String, (int, Object?)> routes;

  /// Routes whose answer depends on the request (e.g. echoing an id).
  final Map<String, (int, Object?) Function(RequestOptions)> handlers;
  final List<RequestOptions> requests = [];

  /// Raw bodies of requests sent as byte streams (e.g. storage uploads).
  final List<Uint8List> streamedBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final body = BytesBuilder(copy: false);
      await requestStream.forEach(body.add);
      streamedBodies.add(body.takeBytes());
    }
    final key = '${options.method} ${options.path}';
    final route = handlers[key]?.call(options) ?? routes[key];
    if (route == null) throw StateError('No route for ${options.path}');
    final (status, body) = route;
    final contentType = status >= 400
        ? 'application/problem+json'
        : 'application/json';
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio dioWith(FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
      ..httpClientAdapter = adapter;

Map<String, Object?> problem(String type, int status) => {
  'type': 'urn:orbit:problem:$type',
  'status': status,
  'title': type,
};
