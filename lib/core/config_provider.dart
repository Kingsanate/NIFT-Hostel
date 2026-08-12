import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfigState {
  final String appName;
  final String appSubtitle;
  final String groqChatKey;
  final String chatPrompt;
  final String scannerPrompt;
  final List<String> activeKeys;

  /// Keys are intentionally empty — they are loaded from the Supabase
  /// `app_config` table at runtime. Never hardcode secrets here.
  AppConfigState({
    this.appName = 'NIFT Hostel Shillong',
    this.appSubtitle = 'NIFT Hostel Shillong',
    this.groqChatKey = '',
    this.chatPrompt = '',
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
    // Start background fetch async
    Future.microtask(() => _fetchFromSupabase());
    
    // Return the cached state immediately for instant boot
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

  Future<void> _fetchFromSupabase() async {
    try {
      final res = await Supabase.instance.client.from('app_config').select().limit(1);
      if (res.isNotEmpty) {
        final data = res.first;
        
        List<String> dynamicKeys = [];
        if (data['gemini_chat_key'] != null && data['gemini_chat_key'].toString().isNotEmpty && data['gemini_chat_key'] != 'YOUR_CHAT_API_KEY_HERE') {
          dynamicKeys.add(data['gemini_chat_key']);
        }
        if (data['gemini_scanner_key'] != null && data['gemini_scanner_key'].toString().isNotEmpty && data['gemini_scanner_key'] != 'YOUR_SCANNER_API_KEY_HERE') {
          if (!dynamicKeys.contains(data['gemini_scanner_key'])) {
            dynamicKeys.add(data['gemini_scanner_key']);
          }
        }
        
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

        // Cache the updated state in Hive for offline use
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
      debugPrint('Failed to load dynamic config from Supabase: $e');
    }
  }
}

final configProvider = NotifierProvider<ConfigNotifier, AppConfigState>(() {
  return ConfigNotifier();
});
