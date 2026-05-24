import 'package:http/http.dart' as http;
import '../core/constants.dart';

class HealthService {
  /// Pings the backend server to wake it up on cold start.
  /// Fails silently because it's only meant to keep the render.com backend awake.
  Future<void> pingServer() async {
    try {
      final uri = Uri.parse('$kBaseUrl/');
      await http.get(uri).catchError((_) {
        return http.Response('', 500);
      });
    } catch (_) {
      // Ignore
    }
  }
}
