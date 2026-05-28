import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/chat_service.dart';
import '../services/ride_service.dart';
import '../core/socket_service.dart';
import '../core/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class ChatScreen extends StatefulWidget {
  final String myName;
  final String myEmail;
  final String otherName;
  final String rideId;

  const ChatScreen({
    super.key,
    required this.myName,
    required this.myEmail,
    required this.otherName,
    required this.rideId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late io.Socket socket;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> messages = [];
  final List<MapEntry<String, void Function(dynamic)>> _socketListeners = [];

  void _on(String event, void Function(dynamic) handler) {
    socket.on(event, handler);
    _socketListeners.add(MapEntry(event, handler));
  }

  @override
  void initState() {
    super.initState();
    fetchChatHistory();
    initSocket();
  }

  String participantsStr = "Loading...";

  Future<void> fetchChatHistory() async {
    try {
      final data = await RideService.getRideById(widget.rideId);
      if (!mounted) return;
      final String myEmailLower = widget.myEmail.trim().toLowerCase();
      
      List<String> allParticipants = [];
      if (data['riderName'] != null && data['riderEmail']?.toString().toLowerCase().trim() != myEmailLower) {
        allParticipants.add(data['riderName']);
      }
      for (var p in (data['passengers'] ?? [])) {
        if (p?.toString().toLowerCase().trim() != myEmailLower) {
          // Try to get display name from riderDetails
          String displayName = data['riderDetails']?[p]?['riderName'] ?? p;
          allParticipants.add(displayName);
        }
      }
        
        setState(() {
          participantsStr = allParticipants.join(', ');
          if (participantsStr.isEmpty) participantsStr = "Empty Ride";

          messages.clear();
          if (data['chatMessages'] != null) {
            final allMessages = data['chatMessages'] as List? ?? [];
            final recentMessages = allMessages.length > 50
                ? allMessages.sublist(allMessages.length - 50)
                : allMessages;
            
            for (var msg in recentMessages) {
              messages.add({
                'sender': msg['sender'],
                'senderEmail': msg['senderEmail'] ?? '',
                'text': msg['text'],
                'timestamp': msg['timestamp']
              });
            }
          }
        });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void initSocket() {
    socket = SocketService().socket;
    _on('receive_message', (data) {
      if (mounted && data['rideId'] == widget.rideId) {
        setState(() => messages.add(data));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final timeString = TimeOfDay.now().format(context);

    try {
      await ChatService.sendMessage(widget.rideId, widget.myName, widget.myEmail, text, timeString);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _sendLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      
      final text = "LOCATION:${position.latitude},${position.longitude}";
      final timeString = TimeOfDay.now().format(context);
      await ChatService.sendMessage(widget.rideId, widget.myName, widget.myEmail, text, timeString);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void dispose() {
    for (final entry in _socketListeners) {
      socket.off(entry.key, entry.value);
    }
    _socketListeners.clear();
    _scrollController.dispose();
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
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final bool isMe = (msg['senderEmail']?.toString().toLowerCase().trim() ?? '') == widget.myEmail.toLowerCase().trim();
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
                        Builder(
                          builder: (context) {
                            final text = messages[index]['text'] ?? "";
                            if (text.startsWith("LOCATION:")) {
                              return GestureDetector(
                                onTap: () async {
                                  final coords = text.substring(9).split(',');
                                  if (coords.length == 2) {
                                    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${coords[0]},${coords[1]}");
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on, color: isMe ? myTextColor : otherTextColor, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Shared Location",
                                        style: TextStyle(
                                          color: isMe ? myTextColor : otherTextColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          decorationColor: isMe ? myTextColor : otherTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Text(
                              text,
                              style: TextStyle(
                                color: isMe ? myTextColor : otherTextColor,
                                fontSize: 15,
                              ),
                            );
                          }
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
                    maxLength: kMaxMessageLength,
                    decoration: InputDecoration(
                      counterText: "",
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
                  onTap: _sendLocation,
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: inputFieldColor,
                    child: Icon(Icons.location_on, color: isDark ? Colors.white70 : Colors.black54),
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
