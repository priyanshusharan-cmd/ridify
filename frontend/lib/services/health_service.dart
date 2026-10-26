import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// Result of checking the backend's /health endpoint.
enum BackendStatus {
  /// Server and database are both up.
  up,

  /// Server answered but reported a problem (e.g. database unavailable).
  degraded,

  /// Server could not be reached at all.
  unreachable,
}

class HealthService {
  /// Pings the backend server to wake it up on cold start.
  /// Fails silently because it's only meant to keep the render.com backend awake.
  Future<void> pingServer() async {
    try {
      final uri = Uri.parse('$kBaseUrl/');
      await http.get(uri).timeout(kHttpTimeout).catchError((_) {
        return http.Response('', 500);
      });
    } catch (_) {
      // Ignore
    }
  }

  /// Checks [kBaseUrl]/health, retrying so a sleeping free-tier Render
  /// instance (which can take ~30-60s to wake) isn't reported as down.
  Future<BackendStatus> checkBackend({
    int attempts = 3,
    Duration perAttemptTimeout = const Duration(seconds: 25),
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    final uri = Uri.parse('$kBaseUrl/health');
    BackendStatus result = BackendStatus.unreachable;
    for (int i = 0; i < attempts; i++) {
      try {
        final res = await http.get(uri).timeout(perAttemptTimeout);
        if (res.statusCode == 200) return BackendStatus.up;
        // 503 from /health means the API is running but MongoDB isn't ready.
        // Render also returns 502/503 briefly while an instance wakes, so retry.
        result = BackendStatus.degraded;
      } catch (_) {
        result = BackendStatus.unreachable;
      }
      if (i < attempts - 1) await Future.delayed(retryDelay);
    }
    return result;
  }
}
