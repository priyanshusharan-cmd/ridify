import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ChatService {
  static Future<Map<String, dynamic>> fetchChatData(String rideId) async {
    final response = await http.get(Uri.parse('$kBaseUrl/api/rides/$rideId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load chat data');
    }
  }

  static Future<void> sendMessage(String rideId, String sender, String senderEmail, String text, String timestamp) async {
    final response = await http.post(
      Uri.parse('$kBaseUrl/api/rides/$rideId/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender': sender,
        'senderEmail': senderEmail,
        'text': text,
        'timestamp': timestamp,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to send message');
    }
  }
}
