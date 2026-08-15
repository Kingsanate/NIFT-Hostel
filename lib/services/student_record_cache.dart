import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../students/models/medical_treatment_model.dart';
import 'api_service.dart';

/// Ultra high-speed in-memory & persistent cache for Student Record Tabs
/// (Leaves, Late Entries, and Medical Treatments).
/// Follows WhatsApp-style 0ms instant loading architecture.
class StudentRecordCache {
  static final Map<String, List<Map<String, dynamic>>> _leavesCache = {};
  static final Map<String, List<Map<String, dynamic>>> _lateEntriesCache = {};
  static final Map<String, List<MedicalTreatmentRecord>> _treatmentsCache = {};

  static bool _initialized = false;

  static String _cleanKey(String rollNo) {
    return rollNo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Initialize cache from local storage on app start
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final leavesRaw = prefs.getString('cache_leaves_v1');
      if (leavesRaw != null && leavesRaw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(leavesRaw);
        decoded.forEach((k, v) {
          if (v is List) {
            _leavesCache[k] = v.cast<Map<String, dynamic>>();
          }
        });
      }

      final lateRaw = prefs.getString('cache_late_v1');
      if (lateRaw != null && lateRaw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(lateRaw);
        decoded.forEach((k, v) {
          if (v is List) {
            _lateEntriesCache[k] = v.cast<Map<String, dynamic>>();
          }
        });
      }

      final medRaw = prefs.getString('cache_med_v1');
      if (medRaw != null && medRaw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(medRaw);
        decoded.forEach((k, v) {
          if (v is List) {
            _treatmentsCache[k] = v
                .map((m) => MedicalTreatmentRecord.fromJson(m as Map<String, dynamic>))
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint('[StudentRecordCache] Cache load error: $e');
    }

    // Trigger immediate background preload of all records from backend
    preloadAll();
  }

  /// Preload all student records (leaves, late entries, treatments) in the background on app start
  static Future<void> preloadAll() async {
    try {
      final results = await Future.wait([
        ApiService.fetchLeaveApprovals(),
        ApiService.fetchLateEntries(),
        ApiService.fetchMedicalTreatments(),
      ]);

      final leavesList = results[0];
      final lateList = results[1];
      final treatmentsList = results[2];

      // Group leaves by rollNo
      final Map<String, List<Map<String, dynamic>>> newLeaves = {};
      for (var l in leavesList) {
        final r = (l['roll_no'] ?? l['rollNo'] ?? '').toString();
        if (r.isNotEmpty) {
          final key = _cleanKey(r);
          newLeaves.putIfAbsent(key, () => []).add(l);
        }
      }
      newLeaves.forEach((k, v) => _leavesCache[k] = v);

      // Group late entries by rollNo
      final Map<String, List<Map<String, dynamic>>> newLate = {};
      for (var l in lateList) {
        final r = (l['roll_no'] ?? l['rollNo'] ?? '').toString();
        if (r.isNotEmpty) {
          final key = _cleanKey(r);
          newLate.putIfAbsent(key, () => []).add(l);
        }
      }
      newLate.forEach((k, v) => _lateEntriesCache[k] = v);

      // Group treatments by rollNo
      final Map<String, List<MedicalTreatmentRecord>> newTreatments = {};
      for (var t in treatmentsList) {
        final r = (t['roll_no'] ?? t['rollNo'] ?? '').toString();
        if (r.isNotEmpty) {
          final key = _cleanKey(r);
          final rec = MedicalTreatmentRecord.fromJson(t);
          newTreatments.putIfAbsent(key, () => []).add(rec);
        }
      }
      newTreatments.forEach((k, v) => _treatmentsCache[k] = v);

      // Persist to disk in background
      _persistLeaves();
      _persistLateEntries();
      _persistTreatments();
      debugPrint('⚡ [StudentRecordCache] Preloaded all student records into RAM (0ms instant display)');
    } catch (e) {
      debugPrint('[StudentRecordCache] Preload background notice: $e');
    }
  }

  // ── Leaves Cache ─────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>>? getLeaves(String rollNo) {
    return _leavesCache[_cleanKey(rollNo)];
  }

  static void setLeaves(String rollNo, List<Map<String, dynamic>> leaves) {
    _leavesCache[_cleanKey(rollNo)] = leaves;
    _persistLeaves();
  }

  // ── Late Entries Cache ───────────────────────────────────────────────────────
  static List<Map<String, dynamic>>? getLateEntries(String rollNo) {
    return _lateEntriesCache[_cleanKey(rollNo)];
  }

  static void setLateEntries(String rollNo, List<Map<String, dynamic>> lateEntries) {
    _lateEntriesCache[_cleanKey(rollNo)] = lateEntries;
    _persistLateEntries();
  }

  // ── Medical Treatments Cache ────────────────────────────────────────────────
  static List<MedicalTreatmentRecord>? getTreatments(String rollNo) {
    return _treatmentsCache[_cleanKey(rollNo)];
  }

  static void setTreatments(String rollNo, List<MedicalTreatmentRecord> treatments) {
    _treatmentsCache[_cleanKey(rollNo)] = treatments;
    _persistTreatments();
  }

  static void addTreatment(String rollNo, MedicalTreatmentRecord treatment) {
    final key = _cleanKey(rollNo);
    final current = List<MedicalTreatmentRecord>.from(_treatmentsCache[key] ?? []);
    current.removeWhere((r) => r.id == treatment.id);
    current.insert(0, treatment);
    _treatmentsCache[key] = current;
    _persistTreatments();
  }

  static void removeTreatment(String rollNo, String id) {
    final key = _cleanKey(rollNo);
    final current = List<MedicalTreatmentRecord>.from(_treatmentsCache[key] ?? []);
    current.removeWhere((r) => r.id == id);
    _treatmentsCache[key] = current;
    _persistTreatments();
  }

  // ── Background Persistence ───────────────────────────────────────────────────
  static void _persistLeaves() {
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_leaves_v1', jsonEncode(_leavesCache));
      } catch (_) {}
    });
  }

  static void _persistLateEntries() {
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_late_v1', jsonEncode(_lateEntriesCache));
      } catch (_) {}
    });
  }

  static void _persistTreatments() {
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final mapped = _treatmentsCache.map((k, v) => MapEntry(k, v.map((r) => r.toJson()).toList()));
        await prefs.setString('cache_med_v1', jsonEncode(mapped));
      } catch (_) {}
    });
  }
}
