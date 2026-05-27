import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'constants.dart';

/// Singleton Socket.IO service — ONE connection shared across all screens.
/// Manages user registration, room joining/leaving, and auto-reconnect.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _userEmail;
  String? _accessToken;
  final Map<String, int> _joinedRidesCount = {};

  /// The single shared socket. Created lazily on first access.
  io.Socket get socket {
    _socket ??= _createSocket();
    return _socket!;
  }

  bool get isConnected => _socket?.connected ?? false;

  io.Socket _createSocket() {
    final accessToken = _accessToken ?? '';
    final s = io.io(kBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false, // Don't auto-connect until token is set
      'forceNew': false,
      'auth': {'token': accessToken},
    });

    s.onConnect((_) {
      debugPrint('🔌 Socket connected: ${s.id}');
      // Re-register user on reconnect
      if (_userEmail != null) {
        s.emit('register_user', {'userEmail': _userEmail});
      }
      // Re-join all ride rooms on reconnect
      for (final rideId in _joinedRidesCount.keys) {
        s.emit('join_ride', {'rideId': rideId});
      }
    });

    s.onDisconnect((_) => debugPrint('🔌 Socket disconnected'));
    s.onReconnect((_) => debugPrint('🔌 Socket reconnected'));
    s.onError((e) => debugPrint('❌ Socket Error: $e'));

    return s;
  }

  /// Register this user identity. Call once after login.
  void registerUser(String userEmail, String accessToken) {
    final isNewUser = _userEmail != userEmail;
    _userEmail = userEmail;
    _accessToken = accessToken;
    
    if (_socket != null && isNewUser) {
      // Different user — must disconnect and reconnect with new identity
      _socket!.disconnect();
      _socket = null;
    }
    
    // Update auth on socket options
    _socket?.io.options?['auth'] = {'token': accessToken};
    
    if (!socket.connected) socket.connect();
  }

  /// Join a ride room for targeted events.
  void joinRide(String rideId) {
    if (rideId.isEmpty) return;
    int count = _joinedRidesCount[rideId] ?? 0;
    _joinedRidesCount[rideId] = count + 1;
    if (count == 0) {
      socket.emit('join_ride', {'rideId': rideId});
    }
  }

  /// Leave a ride room.
  void leaveRide(String rideId) {
    if (rideId.isEmpty) return;
    int count = _joinedRidesCount[rideId] ?? 0;
    if (count > 0) {
      count--;
      if (count == 0) {
        _joinedRidesCount.remove(rideId);
        socket.emit('leave_ride', {'rideId': rideId});
      } else {
        _joinedRidesCount[rideId] = count;
      }
    }
  }

  /// Full cleanup (e.g., on logout).
  void dispose() {
    for (final rideId in List.from(_joinedRidesCount.keys)) {
      _socket?.emit('leave_ride', {'rideId': rideId});
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _joinedRidesCount.clear();
    _userEmail = null;
    _accessToken = null;
  }
}
