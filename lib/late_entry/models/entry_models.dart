/// Models + persistence (Hive) for the
/// Students Entry Approval module.
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../services/api_service.dart';

/// Normalizes any hostel ID / name variant (e.g. 'boys_hostel', 'Boys Hostel',
/// 'umsawli_girls', 'Umsawli Girls') to the canonical display name used by the UI.
/// Prevents records from being filtered out due to raw backend IDs.
String mapHostel(String raw) {
  final h = raw.toLowerCase().trim();
  if (h.contains('umsawli') ||
      h.contains('girls2') ||
      h.contains('girls_2') ||
      h.contains('girls 2')) {
    return 'Umsawli Girls';
  }
  if (h.contains('nongthymmai') ||
      h.contains('girls1') ||
      h.contains('girls_1') ||
      h.contains('girls 1')) {
    return 'Nongthymmai Girls';
  }
  return 'Boys Hostel';
}

class LateEntryRecord {
  final String id;
  final String studentId;
  final String name;
  final String rollNo;
  final String hostel;
  final String department;
  final String semester;
  final String roomNo;
  final String? photoBase64;
  final DateTime entryAt;

  const LateEntryRecord({
    required this.id,
    required this.studentId,
    required this.name,
    required this.rollNo,
    required this.hostel,
    this.department = '',
    this.semester = '',
    this.roomNo = '',
    this.photoBase64,
    required this.entryAt,
  });

  bool inMonth(int year, int month) =>
      entryAt.year == year && entryAt.month == month;

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'name': name,
        'rollNo': rollNo,
        'hostel': hostel,
        'department': department,
        'semester': semester,
        'roomNo': roomNo,
        'photoBase64': photoBase64,
        'entryAt': entryAt.toIso8601String(),
      };

  factory LateEntryRecord.fromMap(Map<String, dynamic> json) {
    return LateEntryRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? json['student_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['student_name']?.toString() ?? '',
      rollNo: json['rollNo']?.toString() ?? json['roll_no']?.toString() ?? '',
      hostel: mapHostel(json['hostel']?.toString() ?? json['hostel_id']?.toString() ?? ''),
      department: json['department']?.toString() ?? json['course']?.toString() ?? '',
      semester: json['semester']?.toString() ?? json['year']?.toString() ?? '',
      roomNo: json['roomNo']?.toString() ?? json['room_no']?.toString() ?? json['room']?.toString() ?? '',
      photoBase64: json['photoBase64']?.toString() ?? json['photo_base64']?.toString(),
      entryAt: DateTime.tryParse(json['entryAt']?.toString() ?? json['entry_at']?.toString() ?? json['actual_time']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory LateEntryRecord.fromBackend(Map<String, dynamic> json) {
    return LateEntryRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      name: json['name']?.toString() ?? json['student_name']?.toString() ?? json['studentName']?.toString() ?? '',
      rollNo: json['roll_no']?.toString() ?? json['rollNo']?.toString() ?? '',
      hostel: mapHostel(json['hostel']?.toString() ?? json['hostel_id']?.toString() ?? json['hostelId']?.toString() ?? ''),
      department: json['department']?.toString() ?? json['course']?.toString() ?? '',
      semester: json['semester']?.toString() ?? json['year']?.toString() ?? '',
      roomNo: json['room_no']?.toString() ?? json['roomNo']?.toString() ?? json['room']?.toString() ?? '',
      photoBase64: json['photo_base64']?.toString() ?? json['photoBase64']?.toString() ?? json['profilePhotoBase64']?.toString(),
      entryAt: DateTime.tryParse(json['entry_at']?.toString() ?? json['entryAt']?.toString() ?? json['actual_time']?.toString() ?? json['actualTime']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  LateEntryRecord copyWith({
    String? id,
    String? studentId,
    String? name,
    String? rollNo,
    String? hostel,
    String? department,
    String? semester,
    String? roomNo,
    String? photoBase64,
    DateTime? entryAt,
  }) {
    return LateEntryRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      hostel: hostel ?? this.hostel,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      roomNo: roomNo ?? this.roomNo,
      photoBase64: photoBase64 ?? this.photoBase64,
      entryAt: entryAt ?? this.entryAt,
    );
  }
}

class LeaveApprovalRecord {
  final String id;
  final String studentId;
  final String name;
  final String rollNo;
  final String hostel;
  final String department;
  final String semester;
  final String roomNo;
  final String? photoBase64;
  final DateTime appliedAt;
  final String? formImageBase64;
  final String? formImageUrl;

  const LeaveApprovalRecord({
    required this.id,
    required this.studentId,
    required this.name,
    required this.rollNo,
    required this.hostel,
    required this.department,
    required this.semester,
    required this.roomNo,
    this.photoBase64,
    required this.appliedAt,
    this.formImageBase64,
    this.formImageUrl,
  });

  bool inMonth(int year, int month) =>
      appliedAt.year == year && appliedAt.month == month;

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'name': name,
        'rollNo': rollNo,
        'hostel': hostel,
        'department': department,
        'semester': semester,
        'roomNo': roomNo,
        'photoBase64': photoBase64,
        'appliedAt': appliedAt.toIso8601String(),
        'formImageBase64': formImageBase64,
        'formImageUrl': formImageUrl,
      };

  factory LeaveApprovalRecord.fromMap(Map<String, dynamic> json) {
    return LeaveApprovalRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? json['student_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['student_name']?.toString() ?? '',
      rollNo: json['rollNo']?.toString() ?? json['roll_no']?.toString() ?? '',
      hostel: mapHostel(json['hostel']?.toString() ?? json['hostel_id']?.toString() ?? ''),
      department: json['department']?.toString() ?? json['course']?.toString() ?? '',
      semester: json['semester']?.toString() ?? json['year']?.toString() ?? '',
      roomNo: json['roomNo']?.toString() ?? json['room_no']?.toString() ?? json['room']?.toString() ?? '',
      photoBase64: json['photoBase64']?.toString() ?? json['photo_base64']?.toString(),
      appliedAt: DateTime.tryParse(json['appliedAt']?.toString() ?? json['applied_at']?.toString() ?? '') ??
          DateTime.now(),
      formImageBase64: json['formImageBase64']?.toString() ?? json['form_image_base64']?.toString(),
      formImageUrl: json['formImageUrl']?.toString() ?? json['form_image_url']?.toString(),
    );
  }

  factory LeaveApprovalRecord.fromBackend(Map<String, dynamic> json) {
    return LeaveApprovalRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      name: json['name']?.toString() ?? json['student_name']?.toString() ?? json['studentName']?.toString() ?? '',
      rollNo: json['roll_no']?.toString() ?? json['rollNo']?.toString() ?? '',
      hostel: mapHostel(json['hostel']?.toString() ?? json['hostel_id']?.toString() ?? json['hostelId']?.toString() ?? ''),
      department: json['department']?.toString() ?? json['course']?.toString() ?? '',
      semester: json['semester']?.toString() ?? json['year']?.toString() ?? '',
      roomNo: json['room_no']?.toString() ?? json['roomNo']?.toString() ?? json['room']?.toString() ?? '',
      photoBase64: json['photo_base64']?.toString() ?? json['photoBase64']?.toString() ?? json['profilePhotoBase64']?.toString(),
      appliedAt: DateTime.tryParse(json['applied_at']?.toString() ?? json['appliedAt']?.toString() ?? json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      formImageBase64: json['form_image_base64']?.toString() ?? json['formImageBase64']?.toString(),
      formImageUrl: json['form_image_url']?.toString() ?? json['formImageUrl']?.toString(),
    );
  }

  LeaveApprovalRecord copyWith({
    String? id,
    String? studentId,
    String? name,
    String? rollNo,
    String? hostel,
    String? department,
    String? semester,
    String? roomNo,
    String? photoBase64,
    DateTime? appliedAt,
    String? formImageBase64,
    String? formImageUrl,
  }) {
    return LeaveApprovalRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      hostel: hostel ?? this.hostel,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      roomNo: roomNo ?? this.roomNo,
      photoBase64: photoBase64 ?? this.photoBase64,
      appliedAt: appliedAt ?? this.appliedAt,
      formImageBase64: formImageBase64 ?? this.formImageBase64,
      formImageUrl: formImageUrl ?? this.formImageUrl,
    );
  }
}

/// Sync layer:
/// - Always persists locally (Hive) for instant 0ms access and full offline capability.
/// - Automatically syncs with PostgreSQL Backend in the background.
///
/// Sync model:
/// - The backend performs an idempotent upsert (see leaveRoutes.js / lateEntryRoutes.js)
///   and always returns the real database UUID for the record.
/// - Records created offline carry temp ids (e.g. "LA" + timestamp). Those are the only
///   records pushed to the server; once pushed, the server UUID is adopted back into Hive
///   so future deletes / merges always target the correct row.
/// - The server is the source of truth for merges: rows deleted on the server disappear
///   from local Hive on the next sync, and local duplicates of a remote row
///   (same roll no + timestamp, different id) are collapsed.
class EntryStore {
  static const _boxName = 'entryApproval';

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool _isUuid(String id) =>
      id.isNotEmpty && _uuidPattern.hasMatch(id);

  static Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }

  // ── Late entries ──────────────────────────────────────────────────────
  static Future<List<LateEntryRecord>> loadLateEntries({String? hostel}) async {
    return _syncRemoteLateEntries(hostel);
  }

  static Future<List<LateEntryRecord>> _syncRemoteLateEntries(String? hostel) async {
    try {
      final remoteList = await ApiService.fetchLateEntries(hostelId: hostel);
      final remoteIds = <String>{};
      final local = await _loadHiveLate();
      final map = <String, LateEntryRecord>{};

      // Seed with local records
      for (final r in local) {
        if (r.id.isNotEmpty) map[r.id] = r;
      }

      // Merge remote (server is source of truth)
      for (final item in remoteList) {
        final r = LateEntryRecord.fromBackend(item);
        if (r.id.isEmpty) continue;
        remoteIds.add(r.id);
        // Collapse local duplicates of the same logical record
        map.removeWhere((_, e) => e.id != r.id && _sameLateEntry(e, r));
        final existing = map[r.id];
        if (existing != null &&
            (existing.photoBase64?.isNotEmpty ?? false) &&
            !(r.photoBase64?.isNotEmpty ?? false)) {
          map[r.id] = existing;
        } else {
          map[r.id] = r;
        }
      }

      // Drop locally synced rows that no longer exist on the server
      map.removeWhere((id, _) => _isUuid(id) && !remoteIds.contains(id));

      var merged = _dedupeLateRecords(map.values.toList())
        ..sort((a, b) => b.entryAt.compareTo(a.entryAt));

      // Push offline-created records and adopt server ids
      final pending = merged.where((r) => !_isUuid(r.id)).toList();
      if (pending.isNotEmpty) {
        final pushed = await _pushLateEntriesToServer(pending);
        final pushedById = {for (final r in pushed) r.id: r};
        merged = _dedupeLateRecords(merged.map((r) => pushedById[r.id] ?? r).toList())
          ..sort((a, b) => b.entryAt.compareTo(a.entryAt));
      }

      await _saveHiveLate(merged);
      return merged;
    } catch (e) {
      debugPrint('Sync remote late entries: $e');
      return _loadHiveLate();
    }
  }

  static Future<List<LateEntryRecord>> _pushLateEntriesToServer(
      List<LateEntryRecord> records) async {
    final out = <LateEntryRecord>[];
    for (final r in records) {
      try {
        final res = await ApiService.createLateEntry({
          'id': r.id,
          'student_id': r.studentId,
          'studentId': r.studentId,
          'roll_no': r.rollNo,
          'rollNo': r.rollNo,
          'student_name': r.name,
          'name': r.name,
          'hostel_id': r.hostel,
          'hostel': r.hostel,
          'department': r.department,
          'semester': r.semester,
          'room': r.roomNo,
          'roomNo': r.roomNo,
          'photo_base64': r.photoBase64,
          'photoBase64': r.photoBase64,
          'actual_time': r.entryAt.toIso8601String(),
          'entryAt': r.entryAt.toIso8601String(),
        });
        final serverId = res['lateEntry']?['id']?.toString() ??
            res['id']?.toString() ??
            '';
        out.add(serverId.isNotEmpty && serverId != r.id
            ? r.copyWith(id: serverId)
            : r);
      } catch (e) {
        debugPrint('Post late entry to backend error: $e');
        out.add(r);
      }
    }
    return out;
  }

  /// Atomic single record save that prevents duplicate entries
  static Future<List<LateEntryRecord>> saveLateEntry(
      LateEntryRecord record) async {
    final current = await _loadHiveLate();
    final updated = [
      record,
      ...current.where((r) => r.id != record.id && !_sameLateEntry(r, record))
    ];
    final deduped = _dedupeLateRecords(updated);
    await _saveHiveLate(deduped);

    if (!_isUuid(record.id)) {
      _pushLateEntriesToServer([record]).then((pushed) async {
        if (pushed.isNotEmpty) {
          final serverRecord = pushed.first;
          if (serverRecord.id.isNotEmpty && serverRecord.id != record.id) {
            final latest = await _loadHiveLate();
            final mapped = latest.map((r) {
              if (r.id == record.id || _sameLateEntry(r, record)) {
                return serverRecord;
              }
              return r;
            }).toList();
            await _saveHiveLate(_dedupeLateRecords(mapped));
          }
        }
      }).catchError((e) {
        debugPrint('Async push late entry error: $e');
      });
    }

    return deduped;
  }

  static Future<void> saveLateEntries(List<LateEntryRecord> records) async {
    final unique = _dedupeLateRecords(records);
    await _saveHiveLate(unique);

    final pending = unique.where((r) => !_isUuid(r.id)).toList();
    if (pending.isEmpty) return;

    final pushed = await _pushLateEntriesToServer(pending);
    final pushedById = {for (final r in pushed) r.id: r};
    final finalList = unique.map((r) => pushedById[r.id] ?? r).toList();
    await _saveHiveLate(_dedupeLateRecords(finalList));
  }

  static Future<void> deleteLateEntry(String id) async {
    final local = await _loadHiveLate();
    final rec = local.where((r) => r.id == id).firstOrNull;
    final next = local.where((r) => r.id != id).toList();
    await _saveHiveLate(next);
    try {
      final ok = await ApiService.deleteLateEntry(id);
      // Legacy temp id fallback: delete the actual server row by logical key
      if (!ok && rec != null) {
        final remote = await ApiService.fetchLateEntries(rollNo: rec.rollNo);
        for (final item in remote) {
          final r = LateEntryRecord.fromBackend(item);
          if (r.id.isNotEmpty && _sameLateEntry(r, rec)) {
            await ApiService.deleteLateEntry(r.id);
            break;
          }
        }
      }
    } catch (_) {}
  }

  // ── Leave approvals ───────────────────────────────────────────────────
  static Future<List<LeaveApprovalRecord>> loadLeaveApprovals({String? hostel}) async {
    return _syncRemoteLeaveApprovals(hostel);
  }

  static Future<List<LeaveApprovalRecord>> _syncRemoteLeaveApprovals(String? hostel) async {
    try {
      final remoteList = await ApiService.fetchLeaveApprovals(hostelId: hostel);
      final remoteIds = <String>{};
      final box = await _box();
      final local = await _loadHiveLeave();
      final map = <String, LeaveApprovalRecord>{};

      // Seed with local records
      for (final r in local) {
        if (r.id.isNotEmpty) map[r.id] = r;
      }

      // Merge remote (server is source of truth)
      for (final item in remoteList) {
        final r = LeaveApprovalRecord.fromBackend(item);
        if (r.id.isEmpty) continue;
        remoteIds.add(r.id);
        // Collapse local duplicates of the same logical record
        map.removeWhere((_, e) => e.id != r.id && _sameLeaveApproval(e, r));
        final existing = map[r.id];
        if (existing == null) {
          map[r.id] = r;
        } else {
          // Prefer the version that carries a form image, so syncing
          // never erases a locally attached document.
          final hasLocalImage =
              existing.formImageBase64?.isNotEmpty ?? false;
          final hasRemoteImage = r.formImageBase64?.isNotEmpty ?? false;
          final hasLocalUrl = existing.formImageUrl?.isNotEmpty ?? false;
          final hasRemoteUrl = r.formImageUrl?.isNotEmpty ?? false;
          if ((!hasLocalImage && hasRemoteImage) ||
              (!hasLocalUrl && hasRemoteUrl) ||
              (hasLocalImage && hasRemoteUrl && existing.formImageUrl == null)) {
            map[r.id] = r;
          }
        }
      }

      // Drop locally synced rows that no longer exist on the server
      map.removeWhere((id, _) => _isUuid(id) && !remoteIds.contains(id));

      var merged = _dedupeLeaveRecords(map.values.toList())
        ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

      // Push offline-created records and adopt server ids
      final pending = merged.where((r) => !_isUuid(r.id)).toList();
      if (pending.isNotEmpty) {
        final pushed = await _pushLeaveApprovalsToServer(pending);
        final pushedById = {for (final r in pushed) r.id: r};
        merged = _dedupeLeaveRecords(merged.map((r) => pushedById[r.id] ?? r).toList())
          ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
      }

      await box.put('leave_approvals', merged.map((r) => r.toMap()).toList());
      return merged;
    } catch (e) {
      debugPrint('Sync remote leave approvals: $e');
      return _loadHiveLeave();
    }
  }

  static Future<List<LeaveApprovalRecord>> _pushLeaveApprovalsToServer(
      List<LeaveApprovalRecord> records) async {
    final out = <LeaveApprovalRecord>[];
    for (final r in records) {
      try {
        final res = await ApiService.createLeaveApproval({
          'id': r.id,
          'student_id': r.studentId,
          'studentId': r.studentId,
          'roll_no': r.rollNo,
          'rollNo': r.rollNo,
          'student_name': r.name,
          'name': r.name,
          'hostel_id': r.hostel,
          'hostel': r.hostel,
          'department': r.department,
          'semester': r.semester,
          'room': r.roomNo,
          'roomNo': r.roomNo,
          'form_image_url': r.formImageUrl,
          'formImageUrl': r.formImageUrl,
          'form_image_base64': r.formImageBase64,
          'formImageBase64': r.formImageBase64,
          'photo_base64': r.photoBase64,
          'photoBase64': r.photoBase64,
          'applied_at': r.appliedAt.toIso8601String(),
          'appliedAt': r.appliedAt.toIso8601String(),
        });
        final serverId = res['leave']?['id']?.toString() ??
            res['id']?.toString() ??
            '';
        out.add(serverId.isNotEmpty && serverId != r.id
            ? r.copyWith(id: serverId)
            : r);
      } catch (e) {
        debugPrint('Post leave approval to backend error: $e');
        out.add(r);
      }
    }
    return out;
  }

  /// Atomic single record save that prevents duplicate entries
  static Future<List<LeaveApprovalRecord>> saveLeaveApproval(
      LeaveApprovalRecord record) async {
    final current = await _loadHiveLeave();
    final updated = [
      record,
      ...current.where((r) => r.id != record.id && !_sameLeaveApproval(r, record))
    ];
    final deduped = _dedupeLeaveRecords(updated);
    await _saveHiveLeave(deduped);

    if (!_isUuid(record.id)) {
      _pushLeaveApprovalsToServer([record]).then((pushed) async {
        if (pushed.isNotEmpty) {
          final serverRecord = pushed.first;
          if (serverRecord.id.isNotEmpty && serverRecord.id != record.id) {
            final latest = await _loadHiveLeave();
            final mapped = latest.map((r) {
              if (r.id == record.id || _sameLeaveApproval(r, record)) {
                return serverRecord;
              }
              return r;
            }).toList();
            await _saveHiveLeave(_dedupeLeaveRecords(mapped));
          }
        }
      }).catchError((e) {
        debugPrint('Async push leave error: $e');
      });
    }

    return deduped;
  }

  static Future<void> saveLeaveApprovals(
      List<LeaveApprovalRecord> records) async {
    final unique = _dedupeLeaveRecords(records);
    await _saveHiveLeave(unique);

    final pending = unique.where((r) => !_isUuid(r.id)).toList();
    if (pending.isEmpty) return;

    final pushed = await _pushLeaveApprovalsToServer(pending);
    final pushedById = {for (final r in pushed) r.id: r};
    final finalList = unique.map((r) => pushedById[r.id] ?? r).toList();
    await _saveHiveLeave(_dedupeLeaveRecords(finalList));
  }

  static Future<void> deleteLeaveApproval(String id) async {
    final local = await _loadHiveLeave();
    final rec = local.where((r) => r.id == id).firstOrNull;
    final next = local.where((r) => r.id != id).toList();
    await _saveHiveLeave(next);
    try {
      final ok = await ApiService.deleteLeaveApproval(id);
      // Legacy temp id fallback: delete the actual server row by logical key
      if (!ok && rec != null) {
        final remote = await ApiService.fetchLeaveApprovals(rollNo: rec.rollNo);
        for (final item in remote) {
          final r = LeaveApprovalRecord.fromBackend(item);
          if (r.id.isNotEmpty && _sameLeaveApproval(r, rec)) {
            await ApiService.deleteLeaveApproval(r.id);
            break;
          }
        }
      }
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  /// Deduplicates late entries by ID and logical record identity
  static List<LateEntryRecord> _dedupeLateRecords(List<LateEntryRecord> records) {
    final seenIds = <String>{};
    final out = <LateEntryRecord>[];
    for (final r in records) {
      if (r.id.isNotEmpty && seenIds.contains(r.id)) continue;
      final duplicate = out.any((existing) => _sameLateEntry(existing, r));
      if (!duplicate) {
        if (r.id.isNotEmpty) seenIds.add(r.id);
        out.add(r);
      }
    }
    return out;
  }

  /// Deduplicates leave approvals by ID and logical record identity
  static List<LeaveApprovalRecord> _dedupeLeaveRecords(List<LeaveApprovalRecord> records) {
    final seenIds = <String>{};
    final out = <LeaveApprovalRecord>[];
    for (final r in records) {
      if (r.id.isNotEmpty && seenIds.contains(r.id)) continue;
      final duplicate = out.any((existing) => _sameLeaveApproval(existing, r));
      if (!duplicate) {
        if (r.id.isNotEmpty) seenIds.add(r.id);
        out.add(r);
      }
    }
    return out;
  }

  static bool _sameLateEntry(LateEntryRecord a, LateEntryRecord b) {
    if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;
    final sameRoll = a.rollNo.trim().toUpperCase() == b.rollNo.trim().toUpperCase();
    if (!sameRoll) return false;
    final diff = a.entryAt.toUtc().difference(b.entryAt.toUtc()).abs();
    return diff.inSeconds <= 120 ||
        (a.entryAt.year == b.entryAt.year &&
            a.entryAt.month == b.entryAt.month &&
            a.entryAt.day == b.entryAt.day &&
            a.entryAt.hour == b.entryAt.hour &&
            a.entryAt.minute == b.entryAt.minute);
  }

  static bool _sameLeaveApproval(LeaveApprovalRecord a, LeaveApprovalRecord b) {
    if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;
    final sameRoll = a.rollNo.trim().toUpperCase() == b.rollNo.trim().toUpperCase();
    if (!sameRoll) return false;
    final diff = a.appliedAt.toUtc().difference(b.appliedAt.toUtc()).abs();
    return diff.inSeconds <= 120 ||
        (a.appliedAt.year == b.appliedAt.year &&
            a.appliedAt.month == b.appliedAt.month &&
            a.appliedAt.day == b.appliedAt.day &&
            a.appliedAt.hour == b.appliedAt.hour &&
            a.appliedAt.minute == b.appliedAt.minute);
  }

  static Future<List<LateEntryRecord>> _loadHiveLate() async {
    final box = await _box();
    final raw = box.get('late_entries', defaultValue: <dynamic>[]) as List;
    return raw
        .map((e) => LateEntryRecord.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> _saveHiveLate(List<LateEntryRecord> records) async {
    final box = await _box();
    await box.put('late_entries', records.map((r) => r.toMap()).toList());
  }

  static Future<List<LeaveApprovalRecord>> _loadHiveLeave() async {
    final box = await _box();
    final raw = box.get('leave_approvals', defaultValue: <dynamic>[]) as List;
    return raw
        .map((e) => LeaveApprovalRecord.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> _saveHiveLeave(List<LeaveApprovalRecord> records) async {
    final box = await _box();
    await box.put('leave_approvals', records.map((r) => r.toMap()).toList());
  }
}
