import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'constants.dart';

/// Singleton Socket.IO service — ONE connection shared across all screens.
/// Manages user registration, room joining/leaving, and auto-reconnect.
/// Includes application-level heartbeat to detect zombie connections on mobile data.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _userEmail;
  String? _accessToken;
  final Map<String, int> _joinedRidesCount = {};
  final Map<String, List<void Function(dynamic)>> _eventListeners = {};
  Timer? _healthCheckTimer;
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeout;
  bool _isReconnecting = false;

  /// Callbacks invoked whenever the socket (re)connects so screens can re-fetch data.
  /// These fire AFTER the socket is fully connected and rooms are re-joined.
  final List<VoidCallback> _onReconnectCallbacks = [];

  /// Register a callback that fires on every socket connect/reconnect.
  void addReconnectCallback(VoidCallback callback) {
    _onReconnectCallbacks.add(callback);
  }

  /// Remove a previously registered reconnect callback.
  void removeReconnectCallback(VoidCallback callback) {
    _onReconnectCallbacks.remove(callback);
  }

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
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
      'reconnectionAttempts': 9999, // Keep trying to reconnect on mobile data
    });

    s.onConnect((_) {
      debugPrint('🔌 Socket connected: ${s.id}');
      _isReconnecting = false;
      _heartbeatTimeout?.cancel(); // Connection is alive
      // Re-join all ride rooms on reconnect
      for (final rideId in _joinedRidesCount.keys) {
        s.emit('join_ride', {'rideId': rideId});
      }
      // Notify all listeners to re-fetch their data after reconnect
      _fireReconnectCallbacks();
    });

    // Heartbeat pong — cancel the timeout since the connection is alive
    s.on('app_pong', (_) {
      _heartbeatTimeout?.cancel();
    });

    s.onDisconnect((_) => debugPrint('🔌 Socket disconnected'));
    s.onReconnect((_) => debugPrint('🔌 Socket reconnected'));
    s.onError((e) => debugPrint('❌ Socket Error: $e'));
    s.onConnectError((e) {
      debugPrint('❌ Socket Connect Error: $e');
      _isReconnecting = false;
    });

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
    _startHealthCheck();
    _startHeartbeat();
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    // Check socket health every 5 seconds
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_socket == null && _userEmail != null && _accessToken != null) {
        // Socket was nulled (e.g., after token refresh) but never recreated
        debugPrint('🔌 Health check: Socket null, recreating...');
        socket.connect();
      } else if (_socket != null && !_socket!.connected && _userEmail != null && !_isReconnecting) {
        debugPrint('🔌 Health check: Socket disconnected, forcing full reconnect...');
        _isReconnecting = true;
        // Dispose the dead socket and create a fresh one
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
        socket.connect();
      }
    });
  }

  // ── Application-level heartbeat ────────────────────────────────────────────
  // Detects "zombie" connections: the socket reports connected=true but is
  // actually dead (common on mobile data with NAT timeouts). We send a custom
  // 'app_ping' event every 30s; the server echoes 'app_pong'. If no pong
  // arrives within 10s, we force a full reconnect.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimeout?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() {
    if (_socket != null && _socket!.connected) {
      _heartbeatTimeout?.cancel();
      _socket!.emit('app_ping', {'t': DateTime.now().millisecondsSinceEpoch});
      _heartbeatTimeout = Timer(const Duration(seconds: 10), () {
        // No pong received — zombie connection detected
        debugPrint('🔌 Heartbeat timeout — zombie connection detected, forcing reconnect...');
        forceReconnect();
      });
    }
  }

  /// Called by main.dart when the app resumes from background or
  /// the browser tab becomes visible again.
  void handleAppResumed() {
    if (_userEmail == null || _accessToken == null) return;
    if (_socket == null || !_socket!.connected) {
      forceReconnect();
    } else {
      // Socket thinks it's connected — verify with a heartbeat
      _sendHeartbeat();
    }
    // Always re-fetch data regardless (we might have missed events while backgrounded)
    _fireReconnectCallbacks();
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

  void _fireReconnectCallbacks() {
    for (final cb in List<VoidCallback>.from(_onReconnectCallbacks)) {
      try {
        cb();
      } catch (e) {
        debugPrint('🔌 Reconnect callback error: $e');
      }
    }
  }

  /// Full cleanup (e.g., on logout).
  void dispose() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeout?.cancel();
    _heartbeatTimeout = null;
    for (final rideId in List.from(_joinedRidesCount.keys)) {
      _socket?.emit('leave_ride', {'rideId': rideId});
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _joinedRidesCount.clear();
    _eventListeners.clear();
    _onReconnectCallbacks.clear();
    _userEmail = null;
    _accessToken = null;
    _isReconnecting = false;
  }

  void updateAccessToken(String newAccessToken) {
    if (_accessToken == newAccessToken) return;
    _accessToken = newAccessToken;
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      // Immediately recreate and connect — no delay to avoid missing events
      if (_userEmail != null) {
        socket.connect();
      }
    }
  }

  /// Force reconnect socket (e.g., when app resumes from background on mobile data)
  void forceReconnect() {
    if (_isReconnecting) return; // Already attempting
    debugPrint('🔌 Forcing socket reconnection...');
    _isReconnecting = true;
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    // Immediately re-create and connect
    if (_userEmail != null && _accessToken != null) {
      socket.connect();
    } else {
      _isReconnecting = false;
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
