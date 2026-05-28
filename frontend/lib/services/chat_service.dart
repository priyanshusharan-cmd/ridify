import 'dart:convert';
import 'api_client.dart';

class ChatService {
  static Future<Map<String, dynamic>> fetchChatData(String rideId) async {
    final response = await ApiClient.get('/api/rides/$rideId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load chat data');
    }
  }

  static Future<void> sendMessage(String rideId, String sender, String senderEmail, String text, String timestamp, {Map<String, dynamic>? replyTo}) async {
    final Map<String, dynamic> body = {
      'text': text,
      'timestamp': timestamp,
    };
    if (replyTo != null) {
      body['replyTo'] = replyTo;
    }
    final response = await ApiClient.post('/api/rides/$rideId/chat', body);
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to send message');
    }
  }
}
