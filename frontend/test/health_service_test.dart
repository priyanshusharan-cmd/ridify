import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ridify/core/constants.dart';
import 'package:ridify/services/health_service.dart';

Future<BackendStatus> _check(MockClientHandler handler, {List<Uri>? seen}) {
  return http.runWithClient(
    () => HealthService().checkBackend(retryDelay: Duration.zero),
    () => MockClient((req) {
      seen?.add(req.url);
      return handler(req);
    }),
  );
}

void main() {
  test('reports up when /health returns 200', () async {
    final seen = <Uri>[];
    final status = await _check((_) async => http.Response('{"status":"ok"}', 200), seen: seen);
    expect(status, BackendStatus.up);
    expect(seen.single.toString(), '$kBaseUrl/health');
  });

  test('retries while the server wakes up, then reports up', () async {
    var calls = 0;
    final status = await _check((_) async => ++calls < 3 ? http.Response('', 502) : http.Response('ok', 200));
    expect(status, BackendStatus.up);
    expect(calls, 3);
  });

  test('reports degraded when /health keeps returning 503', () async {
    final status = await _check((_) async => http.Response('{"status":"unavailable"}', 503));
    expect(status, BackendStatus.degraded);
  });

  test('reports unreachable when the request fails', () async {
    final status = await _check((_) async => throw http.ClientException('no route to host'));
    expect(status, BackendStatus.unreachable);
  });
}
