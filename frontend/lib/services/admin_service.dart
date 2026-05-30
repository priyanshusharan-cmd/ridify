import 'dart:convert';
import 'api_client.dart';

class AdminService {
  // ── User Management ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAllUsers({
    String? search,
    int page = 1,
    int limit = 20,
    String sortBy = 'createdAt',
    String order = 'desc',
  }) async {
    String url = '/api/admin/users?page=$page&limit=$limit&sortBy=$sortBy&order=$order';
    if (search != null && search.trim().isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search.trim())}';
    }
    final response = await ApiClient.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to fetch users.');
  }

  static Future<Map<String, dynamic>> getUserById(String id) async {
    final response = await ApiClient.get('/api/admin/users/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to fetch user.');
  }

  static Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    String? age,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    };
    if (age != null && age.isNotEmpty) body['age'] = age;

    final response = await ApiClient.post('/api/admin/users/create', body);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to create user.');
  }

  static Future<Map<String, dynamic>> updateUser(String id, {String? name, String? age}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (age != null) body['age'] = age;

    final response = await ApiClient.patch('/api/admin/users/$id', body);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to update user.');
  }

  static Future<void> deleteUser(String id) async {
    final response = await ApiClient.delete('/api/admin/users/$id');
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to delete user.');
    }
  }

  static Future<Map<String, dynamic>> bulkDeleteUsers(List<String> ids) async {
    final response = await ApiClient.post('/api/admin/users/bulk-delete', {'ids': ids});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to bulk delete users.');
  }

  // ── Ride Management ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAllRides({
    String? status,
    String? driverEmail,
    int page = 1,
    int limit = 20,
  }) async {
    String url = '/api/admin/rides?page=$page&limit=$limit';
    if (status != null && status.isNotEmpty) {
      url += '&status=${Uri.encodeComponent(status)}';
    }
    if (driverEmail != null && driverEmail.isNotEmpty) {
      url += '&driverEmail=${Uri.encodeComponent(driverEmail)}';
    }
    final response = await ApiClient.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to fetch rides.');
  }

  static Future<Map<String, dynamic>> getRideById(String id) async {
    final response = await ApiClient.get('/api/admin/rides/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to fetch ride.');
  }

  static Future<void> deleteRide(String id) async {
    final response = await ApiClient.delete('/api/admin/rides/$id');
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to delete ride.');
    }
  }

  static Future<void> wipeAllRides() async {
    final response = await ApiClient.delete('/api/admin/rides');
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to wipe all rides.');
    }
  }

  static Future<void> forceCancelRide(String id) async {
    final response = await ApiClient.patch('/api/admin/rides/$id/cancel', {});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to cancel ride.');
    }
  }

  // ── Stats ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStats() async {
    final response = await ApiClient.get('/api/admin/stats');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to fetch stats.');
  }

  // ── New Expansion Features ──────────────────────────────────────────────

  static Future<void> banUser(String id) async {
    final response = await ApiClient.post('/api/admin/users/$id/ban', {});
    if (response.statusCode != 200) throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to ban user.');
  }

  static Future<void> unbanUser(String id) async {
    final response = await ApiClient.post('/api/admin/users/$id/unban', {});
    if (response.statusCode != 200) throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to unban user.');
  }

  static Future<void> verifyUserDocuments(String id) async {
    final response = await ApiClient.patch('/api/admin/users/$id/verify', {});
    if (response.statusCode != 200) throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to verify user.');
  }

}
