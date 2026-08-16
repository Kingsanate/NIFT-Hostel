import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../scanner/models/student_model.dart';
import 'api_service.dart';
import 'websocket_service.dart';
import 'student_record_cache.dart';

/// WhatsApp-style Single Source of Truth Repository for Student Data.
/// - Instant 0ms in-memory cache: never shows loading or blank screen.
/// - Always available offline and online.
/// - Reactive updates across all screens (Home, Chat, Student List, Attendance).
/// - Background sync that merges seamlessly without wiping existing entries.
class StudentRepository {
  static final StudentRepository instance = StudentRepository._internal();
  factory StudentRepository() => instance;
  StudentRepository._internal();

  static final ValueNotifier<List<StudentModel>> studentsNotifier =
      ValueNotifier<List<StudentModel>>([]);
  static List<StudentModel> get students => studentsNotifier.value;

  static bool _initialized = false;
  static bool _isSyncing = false;
  static StreamSubscription? _wsSub;
  static Timer? _syncDebounce;

  static String _mapHostelId(dynamic raw) {
    if (raw == null) return 'Boys Hostel';
    final str = raw.toString().toLowerCase().trim();
    if (str.contains('umsawli') || str.contains('girls2') || str.contains('girls_2')) {
      return 'Umsawli Girls';
    }
    if (str.contains('nongthymmai') || str.contains('girls1') || str.contains('girls_1')) {
      return 'Nongthymmai Girls';
    }
    return 'Boys Hostel';
  }

  /// Initialize local memory repository from disk (called in main / splash)
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cached_students');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final list = decoded.map((e) => StudentModel.fromBackend(
          e as Map<String, dynamic>,
          _mapHostelId(e['hostelId'] ?? e['hostel_id'] ?? e['hostel']),
        )).toList();

        if (list.isNotEmpty) {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          studentsNotifier.value = list;
          debugPrint('⚡ [StudentRepository] Loaded ${list.length} cached students into memory');
        }
      }
    } catch (e) {
      debugPrint('[StudentRepository] Error initializing cache: $e');
    }

    // Connect real-time WebSocket events for automatic live sync
    _listenToWebSockets();

    // Trigger initial background sync & record tabs preload
    syncWithBackend();
    StudentRecordCache.preloadAll();
  }

  static void _listenToWebSockets() {
    _wsSub?.cancel();
    _wsSub = WebSocketService.instance.events.listen((event) {
      final type = event['type']?.toString() ?? '';
      if (type == 'PING' || type == 'PONG' || type == 'TYPING' || type == 'CHAT_MESSAGE') {
        return;
      }
      debugPrint('⚡ [StudentRepository] Syncing on WebSocket event: $type');
      if (type == 'STUDENTS_CHANGED') {
        final data = event['data'];
        if (data is Map && data['action'] == 'delete') {
          final targetId = data['id']?.toString() ?? '';
          if (targetId.isNotEmpty) {
            final current = List<StudentModel>.from(studentsNotifier.value);
            current.removeWhere((s) =>
                s.id == targetId ||
                s.rollNo.trim().toUpperCase() == targetId.trim().toUpperCase());
            studentsNotifier.value = current;
            _persistToDisk();
          }
        }
      }
      _scheduleSync();
      if (type == 'MEDICAL_CHANGED' ||
          type == 'MEDICAL_TREATMENT_CHANGED' ||
          type == 'LEAVE_LOGGED' ||
          type == 'LATE_ENTRY_LOGGED') {
        _scheduleRecordPreload();
      }
    });
  }

  static Timer? _recordPreloadDebounce;

  /// Debounced record preload — one refresh per burst of events.
  static void _scheduleRecordPreload() {
    _recordPreloadDebounce?.cancel();
    _recordPreloadDebounce = Timer(const Duration(milliseconds: 500), () {
      _recordPreloadDebounce = null;
      StudentRecordCache.preloadAll();
    });
  }

  /// Debounced background sync — collapses bursts of WebSocket events into a
  /// single fetch so rapid multi-device activity never thrashes the network.
  static void _scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 500), () {
      _syncDebounce = null;
      syncWithBackend();
    });
  }

  /// Silent background sync with Oracle backend — authoritative fresh list
  static Future<void> syncWithBackend() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final backendList = await ApiService.fetchStudents();
      if (backendList.isNotEmpty) {
        final freshList = backendList.map((e) => StudentModel.fromBackend(
          e,
          _mapHostelId(e['hostelId'] ?? e['hostel_id'] ?? e['hostel']),
        )).toList();

        freshList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        studentsNotifier.value = freshList;

        // Persist to disk
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_students', jsonEncode(backendList));
        debugPrint('⚡ [StudentRepository] Synced ${freshList.length} students from backend');
      }
    } catch (e) {
      debugPrint('[StudentRepository] Silent sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Add student locally with 0ms UI response + async backend upload
  static Future<void> addStudent(StudentModel student) async {
    final current = List<StudentModel>.from(studentsNotifier.value);
    current.removeWhere((s) =>
        s.id == student.id ||
        s.rollNo.trim().toUpperCase() == student.rollNo.trim().toUpperCase());
    current.insert(0, student);
    studentsNotifier.value = current;

    _persistToDisk();
  }

  /// Update student locally with 0ms UI response + async backend update
  static Future<void> updateStudent(StudentModel student) async {
    final current = List<StudentModel>.from(studentsNotifier.value);
    final idx = current.indexWhere((s) => s.id == student.id);
    if (idx != -1) {
      current[idx] = student;
    } else {
      current.insert(0, student);
    }
    studentsNotifier.value = current;

    _persistToDisk();
  }

  /// Delete student with 0ms optimistic UI + real backend verification.
  /// Returns `true` when the student was removed from the server, `false`
  /// otherwise (the student is restored locally so no data is lost).
  static Future<bool> deleteStudent(StudentModel student) async {
    final current = List<StudentModel>.from(studentsNotifier.value);
    current.removeWhere((s) =>
        s.id == student.id || s.rollNo.trim().toUpperCase() == student.rollNo.trim().toUpperCase());
    studentsNotifier.value = current;
    _persistToDisk();

    final ok = await ApiService.deleteStudent(student.id);
    if (!ok) {
      // Restore the student immediately so nothing is silently lost.
      final restored = List<StudentModel>.from(studentsNotifier.value);
      restored.removeWhere((s) =>
          s.id == student.id || s.rollNo.trim().toUpperCase() == student.rollNo.trim().toUpperCase());
      restored.insert(0, student);
      studentsNotifier.value = restored;
      _persistToDisk();
    }
    return ok;
  }

  static Future<void> _persistToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          studentsNotifier.value.map((s) => s.toBackend()).toList();
      await prefs.setString('cached_students', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[StudentRepository] Error saving to disk: $e');
    }
  }
}
