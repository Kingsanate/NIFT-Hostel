import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../main.dart';
import '../home/reminders_page.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidChannel =
      AndroidNotificationDetails(
    'reminders_channel_id',
    'Reminders',
    channelDescription: 'Channel for AI reminders',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _notifDetails = NotificationDetails(
    android: _androidChannel,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('Local notifications bypassed on Web platform.');
      return;
    }

    // Initialize timezone
    tz.initializeTimeZones();
    try {
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Local timezone set to: $timeZoneName');
    } catch (e) {
      debugPrint('Could not initialize local timezone: $e');
    }

    // Initialize plugin
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const RemindersPage()),
        );
      },
    );

    // Request POST_NOTIFICATIONS permission on Android 13+
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    try {
      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint('Notification permission granted: $granted');
      final exactGranted = await androidPlugin?.requestExactAlarmsPermission();
      debugPrint('Exact Alarm permission granted: $exactGranted');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Shows a notification immediately (instant pop-up).
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    try {
      await _flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _notifDetails,
      );
      debugPrint('✅ Instant notification fired: $title');
    } catch (e) {
      debugPrint('❌ showNow() failed: $e');
    }
  }

  /// Schedules a notification to fire at [scheduledDate].
  /// Tries exact alarm first; if SecurityException is thrown (permission denied),
  /// automatically falls back to inexact alarm so it still fires.
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (kIsWeb) return;

    final tz.TZDateTime scheduledTZ =
        tz.TZDateTime.from(scheduledDate, tz.local);
    final tz.TZDateTime nowTZ = tz.TZDateTime.now(tz.local);

    debugPrint('⏱ Scheduling: $scheduledTZ | now: $nowTZ');

    if (scheduledTZ.isBefore(nowTZ)) {
      debugPrint('⚠️ Scheduled time is in the past — skipping.');
      return;
    }

    // Try exact first, fall back to inexact if exact alarms aren't permitted
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTZ,
        notificationDetails: _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('✅ Exact alarm scheduled for: $scheduledTZ');
    } catch (e) {
      debugPrint('⚠️ Exact alarm failed ($e). Falling back to inexact...');
      try {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTZ,
          notificationDetails: _notifDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        debugPrint('✅ Inexact alarm scheduled for: $scheduledTZ');
      } catch (e2) {
        debugPrint('❌ Both alarm modes failed: $e2');
      }
    }
  }
}
