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
  final Map<String, List<void Function(dynamic)>> _eventListeners = {};

  /// The single shared socket. Created lazily on first access.
  io.Socket get socket {
    _socket ??= _createSocket();
    return _socket!;
  }

  bool get isConnected => _socket?.connected ?? false;

  io.Socket _createSocket() {
    final accessToken = _accessToken ?? '';
    final s = io.io(kBaseUrl, <String, dynamic>{
      'transports': ['polling', 'websocket'], // Use polling first for maximum network compatibility (e.g. school wifi, hotspots)
      'autoConnect': false, // Don't auto-connect until token is set
      'forceNew': true,
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

    // Re-attach all registered listeners
    for (final entry in _eventListeners.entries) {
      for (final handler in entry.value) {
        s.on(entry.key, handler);
      }
    }

    return s;
  }

  void registerUser(String userEmail, String accessToken) {
    final needsRecreate = _userEmail != userEmail || _accessToken != accessToken;
    _userEmail = userEmail;
    _accessToken = accessToken;
    
    if (_socket != null && needsRecreate) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    
    if (!socket.connected) socket.connect();
  }

  void on(String event, void Function(dynamic) handler) {
    _eventListeners.putIfAbsent(event, () => []).add(handler);
    if (_socket != null) {
      _socket!.on(event, handler);
    }
  }

  void off(String event, void Function(dynamic) handler) {
    final list = _eventListeners[event];
    if (list != null) {
      list.remove(handler);
      if (_socket != null) {
        // Since socket.off() in Dart socket_io_client removes ALL listeners for the event,
        // we must clear it entirely and re-attach only the remaining ones.
        _socket!.off(event);
        for (final h in list) {
          _socket!.on(event, h);
        }
      }
    }
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
    _eventListeners.clear();
    _userEmail = null;
    _accessToken = null;
  }
  void updateAccessToken(String newAccessToken) {
    if (_accessToken == newAccessToken) return;
    _accessToken = newAccessToken;
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      if (_userEmail != null) {
         Future.delayed(const Duration(milliseconds: 300), () => socket.connect());
      }
    }
  }

  /// Recursively converts all nested [Map<dynamic, dynamic>] (from socket.io JSON
  /// parsing) into [Map<String, dynamic>] so Dart code can access keys safely.
  static Map<String, dynamic> deepConvertMap(dynamic data) {
    if (data is Map) {
      return data.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), _deepConvertValue(value)),
      );
    }
    return <String, dynamic>{};
  }

  static dynamic _deepConvertValue(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), _deepConvertValue(v)),
      );
    } else if (value is List) {
      return value.map((e) => _deepConvertValue(e)).toList();
    }
    return value;
  }
}
