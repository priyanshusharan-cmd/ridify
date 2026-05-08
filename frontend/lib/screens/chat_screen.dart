import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';

class ChatScreen extends StatefulWidget {
  final String myName;
  final String otherName;
  final String rideId;

  const ChatScreen({
    super.key,
    required this.myName,
    required this.otherName,
    required this.rideId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late io.Socket socket;
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    fetchChatHistory();
    initSocket();
  }

  String participantsStr = "Loading...";

  Future<void> fetchChatHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/api/rides/${widget.rideId}'),
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        
        List<String> allParticipants = [];
        if (data['riderName'] != null && data['riderName'] != widget.myName) {
          allParticipants.add(data['riderName']);
        }
        if (data['passengers'] != null) {
          for (var p in data['passengers']) {
            if (p != widget.myName) allParticipants.add(p);
          }
        }
        
        setState(() {
          participantsStr = allParticipants.join(', ');
          if (participantsStr.isEmpty) participantsStr = "Empty Ride";

          messages.clear();
          if (data['chatMessages'] != null) {
            for (var msg in data['chatMessages']) {
              messages.add({
                'sender': msg['sender'], 
                'text': msg['text'],
                'timestamp': msg['timestamp']
              });
            }
          }
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void initSocket() {
    socket = io.io(kBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    socket.on('receive_message', (data) {
      if (mounted && data['rideId'] == widget.rideId) {
        setState(() => messages.add(data));
      }
    });
  }

  Future<void> sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();

    final timeString = TimeOfDay.now().format(context);

    try {
      await http.post(
        Uri.parse('$kBaseUrl/api/rides/${widget.rideId}/chat'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"sender": widget.myName, "text": text, "timestamp": timeString}),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Chat bubble colors
    final myBubbleColor = isDark ? const Color(0xFF2C2C2C) : Colors.black;
    final otherBubbleColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[200]!;
    final myTextColor = Colors.white;
    final otherTextColor = isDark ? Colors.white : Colors.black;
    final otherNameColor = isDark ? Colors.blue.shade300 : Colors.blue[800]!;
    final timestampMyColor = Colors.white70;
    final timestampOtherColor = isDark ? Colors.white38 : Colors.black54;

    // Input area
    final inputBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputFieldColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!;
    final inputTextColor = isDark ? Colors.white : Colors.black;
    final sendButtonColor = isDark ? const Color(0xFF2C2C2C) : Colors.black;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              child: Icon(Icons.group, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participantsStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                const Text(
                  "Ridify Member",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                bool isMe = messages[index]['sender'] == widget.myName;
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? myBubbleColor : otherBubbleColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              messages[index]['sender'] ?? "Unknown",
                              style: TextStyle(
                                color: otherNameColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          messages[index]['text'] ?? "",
                          style: TextStyle(
                            color: isMe ? myTextColor : otherTextColor,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          messages[index]['timestamp'] ?? "",
                          style: TextStyle(
                            color: isMe ? timestampMyColor : timestampOtherColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            color: inputBgColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: inputTextColor),
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: TextStyle(color: inputTextColor.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: inputFieldColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: sendMessage,
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: sendButtonColor,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
