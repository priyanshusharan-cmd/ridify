import 'package:flutter/material.dart';
import '../utils/snackbar_util.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/chat_service.dart';
import '../services/ride_service.dart';
import '../core/socket_service.dart';
import '../core/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/swipe_to_reply.dart';
import 'package:flutter/services.dart';

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
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, dynamic>> messages = [];
  final List<MapEntry<String, void Function(dynamic)>> _socketListeners = [];
  Map<String, dynamic>? replyToMessage;

  /// Unique local ID counter for optimistic messages so we can reconcile them
  /// with the server-confirmed echo later.
  int _localMsgId = 0;

  void _on(String event, void Function(dynamic) handler) {
    SocketService().on(event, handler);
    _socketListeners.add(MapEntry(event, handler));
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(0.0);
        }
      }
    });
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

          // Preserve any unsent optimistic messages across refreshes
          final pendingMsgs = messages.where((m) => m['_localId'] != null).toList();
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
                'timestamp': msg['timestamp'],
                'replyTo': msg['replyTo'],
              });
            }
          }
          // Re-add pending optimistic messages that weren't in the server response
          for (final pending in pendingMsgs) {
            final alreadyExists = messages.any((m) =>
              m['senderEmail'] == pending['senderEmail'] &&
              m['text'] == pending['text'] &&
              m['timestamp'] == pending['timestamp']);
            if (!alreadyExists) {
              messages.add(pending);
            }
          }
        });
        
        _scrollToBottom(animate: false);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void initSocket() {
    socket = SocketService().socket;
    
    // Ensure we join the ride room (reference counted)
    SocketService().joinRide(widget.rideId);
    
    // If the socket disconnects and reconnects (especially on mobile), refetch chat history
    SocketService().addReconnectCallback(fetchChatHistory);

    _on('receive_message', (rawData) {
      final data = SocketService.deepConvertMap(rawData);
      if (mounted && data['rideId'] == widget.rideId) {
        // Check if this message already exists (optimistic entry or duplicate echo).
        // On mobile data, both room emit AND personal emit may arrive — dedup by
        // matching timestamp + senderEmail + text.
        int existingIdx = messages.indexWhere((m) =>
          m['timestamp'] == data['timestamp'] &&
          m['senderEmail'] == data['senderEmail'] &&
          m['text'] == data['text']);
          
        if (existingIdx == -1) {
          // Fallback: look for an optimistic message that hasn't been confirmed yet
          existingIdx = messages.indexWhere((m) =>
            m['_localId'] != null &&
            m['senderEmail'] == data['senderEmail'] &&
            m['text'] == data['text']
          );
        }
        
        if (existingIdx != -1) {
          // Already have this message (optimistic or earlier echo) — update in place
          setState(() {
            // Preserve _localId if it was an optimistic message, but clear sending state
            final localId = messages[existingIdx]['_localId'];
            messages[existingIdx] = data;
            if (localId != null) messages[existingIdx]['_localId'] = localId;
          });
        } else {
          setState(() => messages.add(data));
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final replyTo = replyToMessage;
    setState(() => replyToMessage = null);

    // ── Optimistic update: show the message IMMEDIATELY ──
    final localId = ++_localMsgId;
    final optimisticTimestamp = DateTime.now().toUtc().toIso8601String();
    final optimisticMsg = <String, dynamic>{
      'sender': widget.myName,
      'senderEmail': widget.myEmail.toLowerCase().trim(),
      'text': text,
      'timestamp': optimisticTimestamp,
      'replyTo': replyTo,
      '_localId': localId,
      '_sending': true,
    };
    setState(() => messages.add(optimisticMsg));
    _scrollToBottom();

    try {
      final confirmed = await ChatService.sendMessage(
        widget.rideId, widget.myName, widget.myEmail, text, '', replyTo: replyTo);
      if (!mounted) return;

      // Reconcile: replace the optimistic message with server-confirmed data
      if (confirmed.isNotEmpty) {
        setState(() {
          final idx = messages.indexWhere((m) => m['_localId'] == localId);
          if (idx != -1) {
            messages[idx] = confirmed;
            messages[idx]['_localId'] = localId;
          }
        });
      }
    } catch (e) {
      debugPrint('Send message error: $e');
      if (!mounted) return;
      // Mark the optimistic message as failed
      setState(() {
        final idx = messages.indexWhere((m) => m['_localId'] == localId);
        if (idx != -1) {
          messages[idx]['_sending'] = false;
          messages[idx]['_failed'] = true;
        }
      });
      SnackbarUtil.show(context, 'Failed to send message. Tap to retry.');
    }
  }

  Future<void> _sendLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) SnackbarUtil.show(context, 'Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) SnackbarUtil.show(context, 'Location permissions are denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) SnackbarUtil.show(context, 'Location permissions are permanently denied.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      
      final text = "LOCATION:${position.latitude},${position.longitude}";
      final replyTo = replyToMessage;
      setState(() => replyToMessage = null);

      // ── Optimistic update for location too ──
      final localId = ++_localMsgId;
      final optimisticTimestamp = DateTime.now().toUtc().toIso8601String();
      final optimisticMsg = <String, dynamic>{
        'sender': widget.myName,
        'senderEmail': widget.myEmail.toLowerCase().trim(),
        'text': text,
        'timestamp': optimisticTimestamp,
        'replyTo': replyTo,
        '_localId': localId,
        '_sending': true,
      };
      setState(() => messages.add(optimisticMsg));
      _scrollToBottom();

      try {
        final confirmed = await ChatService.sendMessage(
          widget.rideId, widget.myName, widget.myEmail, text, '', replyTo: replyTo);
        if (!mounted) return;
        if (confirmed.isNotEmpty) {
          setState(() {
            final idx = messages.indexWhere((m) => m['_localId'] == localId);
            if (idx != -1) {
              messages[idx] = confirmed;
              messages[idx]['_localId'] = localId;
            }
          });
        }
      } catch (e) {
        debugPrint('Send location error: $e');
        if (!mounted) return;
        setState(() {
          final idx = messages.indexWhere((m) => m['_localId'] == localId);
          if (idx != -1) {
            messages[idx]['_sending'] = false;
            messages[idx]['_failed'] = true;
          }
        });
        SnackbarUtil.show(context, 'Failed to send location. Try again.');
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) SnackbarUtil.show(context, 'Failed to get location. Try again.');
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "";
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour;
      final minute = dt.minute;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final hr12 = hour % 12 == 0 ? 12 : hour % 12;
      final minStr = minute.toString().padLeft(2, '0');
      return '$hr12:$minStr $ampm';
    } catch (e) {
      return isoString;
    }
  }

  @override
  void dispose() {
    SocketService().removeReconnectCallback(fetchChatHistory);
    SocketService().leaveRide(widget.rideId);
    for (final entry in _socketListeners) {
      SocketService().off(entry.key, entry.value);
    }
    _socketListeners.clear();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Chat bubble colors
    final myBubbleColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[300]!;
    final otherBubbleColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final myTextColor = isDark ? Colors.white : Colors.black87;
    final otherTextColor = isDark ? Colors.white : Colors.black87;
    final otherNameColor = isDark ? Colors.blue.shade300 : Colors.blue[800]!;
    final timestampMyColor = isDark ? Colors.white70 : Colors.black54;
    final timestampOtherColor = isDark ? Colors.white70 : Colors.black54;

    // Input area
    final inputBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[200]!;
    final inputFieldColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final inputTextColor = isDark ? Colors.white : Colors.black87;
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
              reverse: true,
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[messages.length - 1 - index];
                final bool isMe = (msg['senderEmail']?.toString().toLowerCase().trim() ?? '') == widget.myEmail.toLowerCase().trim();
                return SwipeToReply(
                  key: ValueKey('msg_${messages.length - 1 - index}'),
                  onReply: () {
                    _focusNode.unfocus();
                    setState(() {
                      replyToMessage = {
                        'sender': msg['sender'],
                        'text': msg['text'],
                      };
                    });
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (mounted) {
                        _focusNode.requestFocus();
                      }
                    });
                  },
                  child: Align(
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
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              msg['sender'] ?? "Unknown",
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: otherNameColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (msg['replyTo'] != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withValues(alpha: 0.2) : (isMe ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    width: 4,
                                    color: isDark ? (isMe ? Colors.white70 : Colors.blueAccent) : Colors.blue[800]!,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    msg['replyTo']['sender'] ?? 'Unknown',
                                    style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    msg['replyTo']['text']?.toString().startsWith('LOCATION:') == true ? '📍 Location' : (msg['replyTo']['text'] ?? ''),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Builder(
                          builder: (context) {
                            final text = msg['text'] ?? "";
                            if (text.startsWith("LOCATION:")) {
                              final coords = text.substring(9).split(',');
                              if (coords.length == 2) {
                                final lat = double.tryParse(coords[0]);
                                final lng = double.tryParse(coords[1]);
                                if (lat != null && lng != null) {
                                  return Align(
                                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      child: Container(
                                        height: 150,
                                        width: 250,
                                        margin: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                                        clipBehavior: Clip.hardEdge,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Stack(
                                          children: [
                                            IgnorePointer(
                                              child: FlutterMap(
                                                options: MapOptions(
                                                  initialCenter: LatLng(lat, lng),
                                                  initialZoom: 15.0,
                                                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                                ),
                                                children: [
                                                  TileLayer(
                                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                    userAgentPackageName: 'com.example.ridify',
                                                  ),
                                                  MarkerLayer(
                                                    markers: [
                                                      Marker(
                                                        point: LatLng(lat, lng),
                                                        width: 40,
                                                        height: 40,
                                                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.bottomCenter,
                                                    end: Alignment.topCenter,
                                                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                                                  ),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.location_on, color: Colors.white, size: 16),
                                                    SizedBox(width: 4),
                                                    Text("Shared Location", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                            return Text(
                              text,
                              textAlign: isMe ? TextAlign.end : TextAlign.start,
                              style: TextStyle(
                                color: isMe ? myTextColor : otherTextColor,
                                fontSize: 15,
                              ),
                            );
                          }
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            Text(
                              _formatTimestamp(msg['timestamp']),
                              style: TextStyle(
                                color: isMe ? timestampMyColor : timestampOtherColor,
                                fontSize: 10,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              if (msg['_failed'] == true)
                                const Icon(Icons.error_outline, size: 12, color: Colors.red)
                              else if (msg['_sending'] == true)
                                Icon(Icons.access_time, size: 12, color: timestampMyColor)
                              else
                                Icon(Icons.check, size: 14, color: timestampMyColor),
                            ],
                          ],
                        ),
                      ],
                    ),
                    ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (replyToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Replying to ${replyToMessage!['sender']}", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          replyToMessage!['text']?.toString().startsWith('LOCATION:') == true ? '📍 Location' : (replyToMessage!['text'] ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54, size: 20),
                    onPressed: () => setState(() => replyToMessage = null),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(15),
            color: inputBgColor,
            child: Row(
              children: [
                Expanded(
                  child: Focus(
                    onKeyEvent: (FocusNode node, KeyEvent event) {
                      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                        if (!HardwareKeyboard.instance.isShiftPressed) {
                          sendMessage();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      showCursor: true,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(color: inputTextColor),
                      maxLength: kMaxMessageLength,
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: "Type a message...",
                      hintStyle: TextStyle(color: inputTextColor.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: inputFieldColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: sendButtonColor,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: _sendLocation,
                    splashColor: Colors.white.withValues(alpha: 0.3),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: const SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(Icons.location_on, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: sendButtonColor,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: sendMessage,
                    splashColor: Colors.white.withValues(alpha: 0.3),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: const SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(Icons.send, color: Colors.white),
                    ),
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
