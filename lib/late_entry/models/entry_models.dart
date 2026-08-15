/// Models + persistence (Hive) for the
/// Students Entry Approval module.
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../services/api_service.dart';

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
      hostel: json['hostel']?.toString() ?? json['hostel_id']?.toString() ?? '',
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
      hostel: json['hostel']?.toString() ?? json['hostel_id']?.toString() ?? json['hostelId']?.toString() ?? '',
      department: json['department']?.toString() ?? json['course']?.toString() ?? '',
      semester: json['semester']?.toString() ?? json['year']?.toString() ?? '',
      roomNo: json['room_no']?.toString() ?? json['roomNo']?.toString() ?? json['room']?.toString() ?? '',
      photoBase64: json['photo_base64']?.toString() ?? json['photoBase64']?.toString() ?? json['profilePhotoBase64']?.toString(),
      entryAt: DateTime.tryParse(json['entry_at']?.toString() ?? json['entryAt']?.toString() ?? json['actual_time']?.toString() ?? json['actualTime']?.toString() ?? '') ??
          DateTime.now(),
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
      hostel: json['hostel']?.toString() ?? json['hostel_id']?.toString() ?? '',
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
      hostel: json['hostel']?.toString() ?? json['hostel_id']?.toString() ?? json['hostelId']?.toString() ?? '',
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
class EntryStore {
  static const _boxName = 'entryApproval';

  static Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }

  // ── Late entries ──────────────────────────────────────────────────────
  static Future<List<LateEntryRecord>> loadLateEntries({String? hostel}) async {
    final local = await _loadHiveLate();
    _syncRemoteLateEntries(hostel);
    return local;
  }

  static Future<void> _syncRemoteLateEntries(String? hostel) async {
    try {
      final remoteList = await ApiService.fetchLateEntries(hostelId: hostel);
      if (remoteList.isNotEmpty) {
        final box = await _box();
        final local = await _loadHiveLate();
        final map = <String, LateEntryRecord>{};
        
        for (final r in local) {
          if (r.id.isNotEmpty) map[r.id] = r;
        }
        for (final item in remoteList) {
          final r = LateEntryRecord.fromBackend(item);
          if (r.id.isNotEmpty) map[r.id] = r;
        }
        
        final merged = map.values.toList()
          ..sort((a, b) => b.entryAt.compareTo(a.entryAt));
        await box.put('late_entries', merged.map((r) => r.toMap()).toList());
      }
    } catch (e) {
      debugPrint('Sync remote late entries: $e');
    }
  }

  static Future<void> saveLateEntries(List<LateEntryRecord> records) async {
    await _saveHiveLate(records);
    if (records.isNotEmpty) {
      try {
        final latest = records.first;
        await ApiService.createLateEntry({
          'id': latest.id,
          'student_id': latest.studentId,
          'studentId': latest.studentId,
          'roll_no': latest.rollNo,
          'rollNo': latest.rollNo,
          'student_name': latest.name,
          'name': latest.name,
          'hostel_id': latest.hostel,
          'hostel': latest.hostel,
          'department': latest.department,
          'semester': latest.semester,
          'room': latest.roomNo,
          'roomNo': latest.roomNo,
          'photo_base64': latest.photoBase64,
          'photoBase64': latest.photoBase64,
          'actual_time': latest.entryAt.toIso8601String(),
          'entryAt': latest.entryAt.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Post late entry to backend error: $e');
      }
    }
  }

  static Future<void> deleteLateEntry(String id) async {
    final local = await _loadHiveLate();
    final next = local.where((r) => r.id != id).toList();
    await _saveHiveLate(next);
    try {
      await ApiService.deleteLateEntry(id);
    } catch (_) {}
  }

  // ── Leave approvals ───────────────────────────────────────────────────
  static Future<List<LeaveApprovalRecord>> loadLeaveApprovals({String? hostel}) async {
    final local = await _loadHiveLeave();
    _syncRemoteLeaveApprovals(hostel);
    return local;
  }

  static Future<void> _syncRemoteLeaveApprovals(String? hostel) async {
    try {
      final remoteList = await ApiService.fetchLeaveApprovals(hostelId: hostel);
      if (remoteList.isNotEmpty) {
        final box = await _box();
        final local = await _loadHiveLeave();
        final map = <String, LeaveApprovalRecord>{};
        
        for (final r in local) {
          if (r.id.isNotEmpty) map[r.id] = r;
        }
        for (final item in remoteList) {
          final r = LeaveApprovalRecord.fromBackend(item);
          if (r.id.isNotEmpty) map[r.id] = r;
        }
        
        final merged = map.values.toList()
          ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
        await box.put('leave_approvals', merged.map((r) => r.toMap()).toList());
      }
    } catch (e) {
      debugPrint('Sync remote leave approvals: $e');
    }
  }

  static Future<void> saveLeaveApprovals(
      List<LeaveApprovalRecord> records) async {
    await _saveHiveLeave(records);
    if (records.isNotEmpty) {
      try {
        final latest = records.first;
        await ApiService.createLeaveApproval({
          'id': latest.id,
          'student_id': latest.studentId,
          'studentId': latest.studentId,
          'roll_no': latest.rollNo,
          'rollNo': latest.rollNo,
          'student_name': latest.name,
          'name': latest.name,
          'hostel_id': latest.hostel,
          'hostel': latest.hostel,
          'department': latest.department,
          'semester': latest.semester,
          'room': latest.roomNo,
          'roomNo': latest.roomNo,
          'form_image_url': latest.formImageUrl,
          'formImageUrl': latest.formImageUrl,
          'form_image_base64': latest.formImageBase64,
          'formImageBase64': latest.formImageBase64,
          'photo_base64': latest.photoBase64,
          'photoBase64': latest.photoBase64,
          'applied_at': latest.appliedAt.toIso8601String(),
          'appliedAt': latest.appliedAt.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Post leave approval to backend error: $e');
      }
    }
  }

  static Future<void> deleteLeaveApproval(String id) async {
    final local = await _loadHiveLeave();
    final next = local.where((r) => r.id != id).toList();
    await _saveHiveLeave(next);
    try {
      await ApiService.deleteLeaveApproval(id);
    } catch (_) {}
  }

  // ── Hive helpers ──────────────────────────────────────────────────────
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
