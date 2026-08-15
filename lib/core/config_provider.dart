import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';

class AppConfigState {
  final String appName;
  final String appSubtitle;
  final String groqChatKey;
  final String chatPrompt;
  final String scannerPrompt;
  final List<String> activeKeys;

  /// Keys are intentionally empty — they are loaded from the backend
  /// `app_config` table at runtime. Never hardcode secrets here.
  AppConfigState({
    this.appName = 'NIFT Hostel Shillong',
    this.appSubtitle = 'NIFT Hostel Shillong',
    this.groqChatKey = '',
    this.chatPrompt = 'You are the friendly and professional NIFT Hostel AI Assistant. Always be concise, helpful, and polite.',
    this.scannerPrompt = '',
    this.activeKeys = const [],
  });


  AppConfigState copyWith({
    String? appName,
    String? appSubtitle,
    String? groqChatKey,
    String? chatPrompt,
    String? scannerPrompt,
    List<String>? activeKeys,
  }) {
    return AppConfigState(
      appName: appName ?? this.appName,
      appSubtitle: appSubtitle ?? this.appSubtitle,
      groqChatKey: groqChatKey ?? this.groqChatKey,
      chatPrompt: chatPrompt ?? this.chatPrompt,
      scannerPrompt: scannerPrompt ?? this.scannerPrompt,
      activeKeys: activeKeys ?? this.activeKeys,
    );
  }
}

class ConfigNotifier extends Notifier<AppConfigState> {
  @override
  AppConfigState build() {
    // Start background fetch from Oracle backend (async, non-blocking)
    Future.microtask(() => _fetchFromOracle());
    // Return cached state immediately for instant boot
    return _loadFromCache();
  }

  AppConfigState _loadFromCache() {
    var initialState = AppConfigState();
    try {
      final box = Hive.box('appConfig');
      if (box.isNotEmpty) {
        initialState = initialState.copyWith(
          appName: box.get('app_name') as String?,
          appSubtitle: box.get('app_subtitle') as String?,
          groqChatKey: box.get('groq_chat_key') as String?,
          chatPrompt: box.get('chat_prompt') as String?,
          scannerPrompt: box.get('scanner_prompt') as String?,
          activeKeys: (box.get('active_keys') as List?)?.cast<String>(),
        );
      }
    } catch (e) {
      debugPrint('Error loading config from Hive cache: $e');
    }
    return initialState;
  }

  Future<void> _fetchFromOracle() async {
    try {
      // Fetch config directly from our Oracle self-hosted backend
      // Config endpoint is now auth-protected; send the stored JWT if present
      final token = await ApiService.getAuthToken();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/hostels/config'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['config'] as Map<String, dynamic>? ?? {};

        List<String> dynamicKeys = [];
        final geminiKey = data['gemini_chat_key']?.toString().trim() ?? '';
        final geminiScannerKey = data['gemini_scanner_key']?.toString().trim() ?? '';
        if (geminiKey.isNotEmpty && geminiKey != 'YOUR_CHAT_API_KEY_HERE') {
          dynamicKeys.add(geminiKey);
        }
        if (geminiScannerKey.isNotEmpty &&
            geminiScannerKey != 'YOUR_SCANNER_API_KEY_HERE' &&
            !dynamicKeys.contains(geminiScannerKey)) {
          dynamicKeys.add(geminiScannerKey);
        }
        // Preserve any existing keys not returned from Oracle
        for (var k in state.activeKeys) {
          if (!dynamicKeys.contains(k)) dynamicKeys.add(k);
        }

        final newState = state.copyWith(
          appName: data['app_name']?.toString() ?? state.appName,
          appSubtitle: data['app_subtitle']?.toString() ?? state.appSubtitle,
          groqChatKey: data['groq_chat_key']?.toString().trim() ?? state.groqChatKey,
          chatPrompt: data['chat_prompt']?.toString().trim() ?? state.chatPrompt,
          scannerPrompt: data['scanner_prompt']?.toString().trim() ?? state.scannerPrompt,
          activeKeys: dynamicKeys,
        );

        state = newState;

        // Cache in Hive for offline use
        final box = Hive.box('appConfig');
        await box.putAll({
          'app_name': newState.appName,
          'app_subtitle': newState.appSubtitle,
          'groq_chat_key': newState.groqChatKey,
          'chat_prompt': newState.chatPrompt,
          'scanner_prompt': newState.scannerPrompt,
          'active_keys': newState.activeKeys,
        });
      }
    } catch (e) {
      // Non-fatal: use Hive cache if Oracle is unreachable
      debugPrint('Failed to load config from Oracle backend: $e');
    }
  }
}

final configProvider = NotifierProvider<ConfigNotifier, AppConfigState>(() {
  return ConfigNotifier();
});
