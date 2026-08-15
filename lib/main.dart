import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config_provider.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'chat/chat_palette.dart';
import 'chat/chat_page.dart';
import 'auth/login_page.dart';
import 'services/notification_service.dart';
import 'services/student_repository.dart';
import 'services/student_record_cache.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// All API keys (Groq, Gemini) are fetched from the Oracle self-hosted
/// backend `/api/hostels/config` at runtime and cached in Hive.
class AppConfig {
  static String appName = 'NIFT Hostel Shillong';
  static String appSubtitle = 'NIFT Hostel Shillong';

  // 3 Groq API Keys for High-Speed Chat — loaded from the backend at runtime
  static List<String> groqKeys = [];

  // 3 Gemini API Keys for Document Scanner — loaded from the backend at runtime
  static List<String> scannerKeys = [];

  static String chatPrompt = 'You are the friendly and professional NIFT Hostel AI Assistant. Always be concise, helpful, and polite.';
  static String scannerPrompt = '';
  static List<String> activeKeys = [];

  static Future<void> loadFromOracle() async {
    try {
      final data = await ApiService.fetchConfig();
      if (data.isNotEmpty) {
        if (data['app_name'] != null && data['app_name'].toString().isNotEmpty) appName = data['app_name'];
        if (data['app_subtitle'] != null && data['app_subtitle'].toString().isNotEmpty) appSubtitle = data['app_subtitle'];
        if (data['groq_chat_key'] != null && data['groq_chat_key'].toString().isNotEmpty) {
          groqKeys = data['groq_chat_key'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        if (data['chat_prompt'] != null && data['chat_prompt'].toString().isNotEmpty) chatPrompt = data['chat_prompt'].toString().trim();
        if (data['scanner_prompt'] != null && data['scanner_prompt'].toString().isNotEmpty) scannerPrompt = data['scanner_prompt'].toString().trim();

        if (data['gemini_scanner_key'] != null && data['gemini_scanner_key'].toString().isNotEmpty) {
          scannerKeys = data['gemini_scanner_key'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      }
    } catch (e) {
      debugPrint('Failed to load dynamic config from Oracle: $e');
    }
  }
}

List<CameraDescription> cameras = [];

/// Lazily initializes cameras only the first time the scanner is opened.
/// This prevents blocking main() on every app startup.
Future<void> initCamerasIfNeeded() async {
  if (cameras.isNotEmpty) return;
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use bundled Roboto font to prevent network blocking on cold boot
  GoogleFonts.config.allowRuntimeFetching = false;

  final prefs = await SharedPreferences.getInstance();
  darkModeNotifier.value = prefs.getBool('darkMode') ?? false;

  // Initialize Native High-Speed Real-Time WebSockets
  WebSocketService.instance.connect();

  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Failed to initialize notifications: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Hive.initFlutter();
  await Hive.openBox('appConfig');

  // Initialize WhatsApp-style instant in-memory Student repository & Record Cache
  try {
    await StudentRepository.init();
    await StudentRecordCache.init();
  } catch (e) {
    debugPrint('Failed to initialize caches: $e');
  }

  // Background non-blocking config sync
  AppConfig.loadFromOracle();

  // Check auth session immediately for zero-delay startup (no splash screen)
  final token = prefs.getString('auth_token');
  final bool isLoggedIn = (token != null && token.isNotEmpty);

  // Run the app wrapped in ProviderScope for Riverpod
  runApp(ProviderScope(child: NiftHostelApp(isLoggedIn: isLoggedIn)));
}

class NiftHostelApp extends ConsumerWidget {
  final bool isLoggedIn;
  const NiftHostelApp({super.key, this.isLoggedIn = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: config.appName,
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: ChatPalette.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: ChatPalette.accent,
              brightness: Brightness.light,
              surface: ChatPalette.surface,
              primary: ChatPalette.accent,
            ),
            fontFamily: 'Roboto',
            textTheme: ThemeData.light().textTheme.apply(
              bodyColor: ChatPalette.text,
              displayColor: ChatPalette.text,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: ChatPalette.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: ChatPalette.accent,
              brightness: Brightness.dark,
              surface: ChatPalette.surface,
              primary: ChatPalette.accent,
            ),
            fontFamily: 'Roboto',
            textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: ChatPalette.text,
              displayColor: ChatPalette.text,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          home: isLoggedIn ? const ChatPage() : const LoginPage(),
        );
      },
    );
  }
}
