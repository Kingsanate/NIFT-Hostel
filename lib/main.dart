import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config_provider.dart';

import 'chat/chat_palette.dart';
import 'splash_screen.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// All API keys (Groq, Gemini) are fetched exclusively from the Supabase
/// `app_config` table at runtime. No keys are ever hardcoded in the client.
class AppConfig {
  static String appName = 'NIFT Hostel Shillong';
  static String appSubtitle = 'NIFT Hostel Shillong';

  // Keys start empty — populated from Supabase app_config table only.
  static List<String> groqKeys = [];
  static List<String> scannerKeys = [];
  static String chatPrompt = '';
  static String scannerPrompt = '';
  static List<String> activeKeys = [];

  static Future<void> loadFromSupabase() async {
    try {
      final res = await Supabase.instance.client.from('app_config').select().limit(1);
      if (res.isNotEmpty) {
        final data = res.first;
        if (data['app_name'] != null && data['app_name'].toString().isNotEmpty) appName = data['app_name'];
        if (data['app_subtitle'] != null && data['app_subtitle'].toString().isNotEmpty) appSubtitle = data['app_subtitle'];
        if (data['groq_chat_key'] != null && data['groq_chat_key'].toString().isNotEmpty) {
          groqKeys = data['groq_chat_key'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        if (data['chat_prompt'] != null && data['chat_prompt'].toString().isNotEmpty) chatPrompt = data['chat_prompt'].toString().trim();
        if (data['scanner_prompt'] != null && data['scanner_prompt'].toString().isNotEmpty) scannerPrompt = data['scanner_prompt'].toString().trim();

        List<String> dynamicKeys = [];
        final k1 = data['gemini_chat_key']?.toString().trim() ?? '';
        
        if (data['gemini_scanner_key'] != null && data['gemini_scanner_key'].toString().isNotEmpty) {
          scannerKeys = data['gemini_scanner_key'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }

        if (k1.isNotEmpty) dynamicKeys.add(k1);
        
        activeKeys = dynamicKeys;
      }
    } catch (e) {
      debugPrint('Failed to load dynamic config: $e');
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

  // Allow runtime font fetching with fallback to default fonts if offline
  GoogleFonts.config.allowRuntimeFetching = true;

  final prefs = await SharedPreferences.getInstance();
  darkModeNotifier.value = prefs.getBool('darkMode') ?? false;

  // Uses the PUBLIC anon key only — never the service_role secret.
  await Supabase.initialize(
    url: 'https://hrydivnnodnpzdphwxyu.supabase.co',
    publishableKey: 'sb_publishable_iS7--gEg76NC-kQ5kj9s7Q_I9pw2o8B',
  );
  
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

  // Run the app wrapped in ProviderScope for Riverpod
  runApp(const ProviderScope(child: NiftHostelApp()));
}

class NiftHostelApp extends ConsumerWidget {
  const NiftHostelApp({super.key});

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
          home: const SplashScreen(),
        );
      },
    );
  }
}
