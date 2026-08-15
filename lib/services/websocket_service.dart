import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// High-Speed Native WebSocket Service for NIFT Hostel Flutter
/// Connects directly to wss://nifthostelshillong.duckdns.org/ws for sub-10ms real-time event synchronization.
class WebSocketService {
  static final WebSocketService instance = WebSocketService._internal();
  factory WebSocketService() => instance;
  WebSocketService._internal();

  static const String wsUrl = 'wss://nifthostelshillong.duckdns.org/ws';
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  // Stream Controllers for instant UI reactions
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  bool get isConnected => _isConnected;

  /// Start connection to Oracle WebSocket
  void connect() {
    if (_isConnected) return;
    _reconnectTimer?.cancel();

    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          _isConnected = true;
          try {
            final data = jsonDecode(message.toString());
            debugPrint('⚡ Live WebSocket Event: ${data['type']}');
            _eventController.add(data);
          } catch (e) {
            debugPrint('WebSocket message decode error: $e');
          }
        },
        onError: (err) {
          debugPrint('WebSocket stream error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocket connection closed.');
          _handleDisconnect();
        },
      );

      _isConnected = true;
      _startHeartbeat();
      debugPrint('⚡ WebSocket connected to $wsUrl');
    } catch (e) {
      debugPrint('WebSocket initial connection failed: $e');
      _handleDisconnect();
    }
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'PING'}));
        } catch (_) {}
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('⚡ Reconnecting to WebSocket...');
      connect();
    });
  }

  /// Disconnect cleanly
  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _isConnected = false;
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }
}
