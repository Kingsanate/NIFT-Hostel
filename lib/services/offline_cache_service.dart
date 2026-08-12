import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WhatsApp-Style Local Persistent Storage for Flutter Mobile App
/// Provides 0ms instant app boot data rendering from local disk cache.
class OfflineCacheService {
  static const String _cachePrefix = 'nift_mobile_cache_';

  /// Save payload instantly to local persistent cache
  static Future<bool> setCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      };
      return await prefs.setString('$_cachePrefix$key', jsonEncode(payload));
    } catch (e) {
      debugPrint('Failed to write to local mobile cache: $e');
      return false;
    }
  }

  /// Get cached payload instantly from local disk
  static Future<Map<String, dynamic>?> getCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('$_cachePrefix$key');
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Check if local cache exists
  static Future<bool> hasCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_cachePrefix$key');
  }

  /// Clear all mobile caches
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final k in keys) {
      if (k.startsWith(_cachePrefix)) {
        await prefs.remove(k);
      }
    }
  }
}
