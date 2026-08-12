import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline Action Queue Manager for Mobile Application
class SyncQueueService {
  static const String _queueKey = 'nift_mobile_sync_queue';

  /// Enqueue an action taken while offline (e.g. attendance scan, note update)
  static Future<void> enqueueAction(String actionType, Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> currentQueue = await getQueue();
      
      final newAction = {
        'id': 'mob_act_${DateTime.now().millisecondsSinceEpoch}',
        'actionType': actionType,
        'payload': payload,
        'createdAt': DateTime.now().toIso8601String(),
      };

      currentQueue.add(newAction);
      await prefs.setString(_queueKey, jsonEncode(currentQueue));
    } catch (e) {
      debugPrint('Error queueing mobile offline action: $e');
    }
  }

  /// Get all queued offline actions
  static Future<List<Map<String, dynamic>>> getQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_queueKey);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Clear queue after successful synchronization
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  /// Process queue sequentially with callback
  static Future<int> processQueue(Future<bool> Function(Map<String, dynamic> action) processor) async {
    final queue = await getQueue();
    if (queue.isEmpty) return 0;

    int successCount = 0;
    List<Map<String, dynamic>> remaining = [];

    for (final item in queue) {
      final ok = await processor(item);
      if (ok) {
        successCount++;
      } else {
        remaining.add(item);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    if (remaining.isEmpty) {
      await prefs.remove(_queueKey);
    } else {
      await prefs.setString(_queueKey, jsonEncode(remaining));
    }

    return successCount;
  }
}
