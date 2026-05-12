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
  String? _userName;
  final Set<String> _joinedRides = {};

  /// The single shared socket. Created lazily on first access.
  io.Socket get socket {
    _socket ??= _createSocket();
    return _socket!;
  }

  bool get isConnected => _socket?.connected ?? false;

  io.Socket _createSocket() {
    final s = io.io(kBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'forceNew': false,
    });

    s.onConnect((_) {
      debugPrint('🔌 Socket connected: ${s.id}');
      // Re-register user on reconnect
      if (_userName != null) {
        s.emit('register_user', {'userName': _userName});
      }
      // Re-join all ride rooms on reconnect
      for (final rideId in _joinedRides) {
        s.emit('join_ride', {'rideId': rideId});
      }
    });

    s.onDisconnect((_) => debugPrint('🔌 Socket disconnected'));
    s.onReconnect((_) => debugPrint('🔌 Socket reconnected'));

    return s;
  }

  /// Register this user identity. Call once after login.
  void registerUser(String userName) {
    _userName = userName;
    socket.emit('register_user', {'userName': userName});
  }

  /// Join a ride room for targeted events.
  void joinRide(String rideId) {
    if (rideId.isEmpty) return;
    _joinedRides.add(rideId);
    socket.emit('join_ride', {'rideId': rideId});
  }

  /// Leave a ride room.
  void leaveRide(String rideId) {
    if (rideId.isEmpty) return;
    _joinedRides.remove(rideId);
    socket.emit('leave_ride', {'rideId': rideId});
  }

  /// Full cleanup (e.g., on logout).
  void dispose() {
    _socket?.dispose();
    _socket = null;
    _joinedRides.clear();
    _userName = null;
  }
}
