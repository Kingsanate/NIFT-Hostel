import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// NIFT Hostel Standalone High-Performance API Service for Flutter
/// Connects directly to your Oracle Cloud backend (nifthostelshillong.duckdns.org).
/// 100% self-hosted — no external services.
class ApiService {
  static const String defaultBaseUrl = 'https://nifthostelshillong.duckdns.org/api'; // Oracle Cloud production
  static String baseUrl = defaultBaseUrl;

  static void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. User Login
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        await prefs.setString('user_data', jsonEncode(data['user']));
      }
      return data;
    } catch (e) {
      debugPrint('Login network error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 2. Gate Attendance / QR Scan Submission
  static Future<Map<String, dynamic>> submitAttendanceScan({
    required String rollNo,
    String? studentId,
    String? studentName,
    String? hostelId,
    String? room,
    String scanType = 'check_in',
    String method = 'qr_scan',
    String? photoUrl,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/scan'),
        headers: headers,
        body: jsonEncode({
          'rollNo': rollNo,
          'studentId': studentId,
          'studentName': studentName,
          'hostelId': hostelId ?? 'boys_hostel',
          'room': room ?? '',
          'scanType': scanType,
          'method': method,
          'photoUrl': photoUrl,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Submit attendance scan error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 3. Upload Face Photo directly to Cloudflare R2 / CDN
  static Future<Map<String, dynamic>> uploadFacePhoto({
    required String base64Image,
    required String rollNo,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/storage/upload-photo'),
        headers: headers,
        body: jsonEncode({
          'base64Data': base64Image,
          'rollNo': rollNo,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Upload face photo error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 4. AI Chat Assistant Proxy (Groq / Gemini)
  static Future<String> chatAi(String message, {List<Map<String, String>> history = const []}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/ai/chat'),
        headers: headers,
        body: jsonEncode({
          'message': message,
          'history': history,
        }),
      );

      final data = jsonDecode(response.body);
      return data['reply'] ?? 'No response received from AI assistant.';
    } catch (e) {
      debugPrint('AI chat network error: $e');
      return 'I am currently unable to reach the hostel AI server. Please check your connection.';
    }
  }

  /// 5. Fetch Hostel Rules & Notices
  static Future<List<dynamic>> fetchRules() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/rules'), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['rules'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('Fetch rules error: $e');
      return [];
    }
  }

  /// 5b. Save / Upsert Hostel Rules
  static Future<Map<String, dynamic>> saveRule({
    required String hostelName,
    required String extractedText,
    String? fileUrl,
  }) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/rules'),
        headers: headers,
        body: jsonEncode({
          'hostel_name': hostelName,
          'extracted_text': extractedText,
          'file_url': fileUrl,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('Save rule error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 5c. Delete Hostel Rules
  static Future<bool> deleteRule(String id) async {
    try {
      final headers = await _getHeaders();
      final res = await http.delete(Uri.parse('$baseUrl/rules/$id'), headers: headers);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Delete rule error: $e');
      return false;
    }
  }

  /// 6. Fetch App Configuration (Dynamic Prompts, Groq Keys & Settings)
  static Future<Map<String, dynamic>> fetchConfig() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/hostels/config'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['config'] ?? {};
      }
      return {};
    } catch (e) {
      debugPrint('Fetch config error: $e');
      return {};
    }
  }

  /// 7. Fetch all students from Oracle backend
  static Future<List<Map<String, dynamic>>> fetchStudents({String? hostelId}) async {
    try {
      final headers = await _getHeaders();
      final query = hostelId != null ? '?hostelId=$hostelId' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/students$query'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['students'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Fetch students error: $e');
      return [];
    }
  }

  /// 8. Upload a leave-form photo to Oracle backend
  static Future<Map<String, dynamic>> uploadFormPhoto({
    required Uint8List imageBytes,
    required String rollNo,
  }) async {
    try {
      final headers = await _getHeaders();
      final base64Data = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      final response = await http.post(
        Uri.parse('$baseUrl/storage/upload-photo'),
        headers: headers,
        body: jsonEncode({'base64Data': base64Data, 'rollNo': rollNo}),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Upload form photo error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 9b. Create a new student in Oracle backend
  static Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/students'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Create student error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 10. Delete a student from Oracle backend
  static Future<bool> deleteStudent(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/students/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Delete student error: $e');
      return false;
    }
  }

  /// 11. Update a student in Oracle backend
  static Future<bool> updateStudent(String id, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/students/$id'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update student error: $e');
      return false;
    }
  }

  /// 12. Save a reminder to Oracle backend
  static Future<Map<String, dynamic>> saveReminder({
    required String title,
    required String message,
    DateTime? dueDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/reminders'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'message': message,
          'priority': 'Medium',
          if (dueDate != null) 'due_date': dueDate.toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('Save reminder error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 13. Fetch reminders
  static Future<List<Map<String, dynamic>>> fetchReminders() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(Uri.parse('$baseUrl/reminders'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['reminders'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Fetch reminders error: $e');
      return [];
    }
  }

  /// 14. Delete a reminder
  static Future<bool> deleteReminder(String id) async {
    try {
      final headers = await _getHeaders();
      final res = await http.delete(Uri.parse('$baseUrl/reminders/$id'), headers: headers);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Delete reminder error: $e');
      return false;
    }
  }

  /// 15. Book a medical or counsellor appointment
  static Future<bool> bookAppointment(
    String studentId,
    String type, {
    String? notes,
    dynamic studentData,
    DateTime? createdAt,
  }) async {
    try {
      final headers = await _getHeaders();
      final rollNo = studentData != null ? (studentData.rollNo ?? '') : '';
      final studentName = studentData != null ? (studentData.name ?? '') : '';
      final hostelId = studentData != null ? (studentData.hostel ?? 'boys_hostel') : 'boys_hostel';
      final room = studentData != null ? (studentData.roomNo ?? '') : '';

      final raw = type.toLowerCase();
      final isCounsellor = raw.contains('counsel') || raw.contains('counsell');
      final normType = isCounsellor ? 'counsellor' : 'doctor';

      final res = await http.post(
        Uri.parse('$baseUrl/medical'),
        headers: headers,
        body: jsonEncode({
          'student_id': studentId,
          'roll_no': rollNo,
          'student_roll_no': rollNo,
          'student_name': studentName,
          'hostel_id': hostelId,
          'room': room,
          'issue_description': notes ?? 'Consultation request',
          'appointment_type': normType,
          'type': normType,
          'doctor_name': isCounsellor ? '' : 'Campus Doctor',
          'counsellor_name': isCounsellor ? 'Campus Counsellor' : '',
        }),
      );
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (e) {
      debugPrint('Book appointment error: $e');
      return false;
    }
  }

  /// 16. Cancel an appointment
  static Future<bool> cancelAppointment(String studentId, {String? rollNo}) async {
    try {
      final headers = await _getHeaders();
      final target = (rollNo != null && rollNo.isNotEmpty) ? rollNo : studentId;
      final res = await http.delete(
        Uri.parse('$baseUrl/medical/$target'),
        headers: headers,
      );
      if (res.statusCode != 200 && rollNo != null && rollNo != studentId) {
        await http.delete(
          Uri.parse('$baseUrl/medical/$studentId'),
          headers: headers,
        );
      }
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Cancel appointment error: $e');
      return false;
    }
  }

  /// 16b. Update appointment status / notes
  static Future<bool> updateAppointment(String id, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final res = await http.put(
        Uri.parse('$baseUrl/medical/$id'),
        headers: headers,
        body: jsonEncode(data),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Update appointment error: $e');
      return false;
    }
  }

  /// 17. Fetch medical appointments
  static Future<List<Map<String, dynamic>>> fetchMedicalAppointments() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(Uri.parse('$baseUrl/medical'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['appointments'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Fetch medical appointments error: $e');
      return [];
    }
  }

  /// 18. Fetch attendance history
  static Future<List<Map<String, dynamic>>> fetchAttendanceLogs({String? date, String? hostelId}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String>[];
      if (date != null) queryParams.add('date=$date');
      if (hostelId != null) queryParams.add('hostelId=$hostelId');
      final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final res = await http.get(Uri.parse('$baseUrl/attendance/logs$query'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['logs'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Fetch attendance logs error: $e');
      return [];
    }
  }

  /// 19. Save batch daily attendance
  static Future<bool> saveBatchAttendance({
    required String date,
    required String hostelId,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/attendance/batch'),
        headers: headers,
        body: jsonEncode({
          'date': date,
          'hostelId': hostelId,
          'records': records,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Save batch attendance error: $e');
      return false;
    }
  }

  /// 20. Fetch Late Entries from Oracle backend
  static Future<List<Map<String, dynamic>>> fetchLateEntries({String? hostelId, String? month, String? rollNo}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String>[];
      if (hostelId != null) queryParams.add('hostelId=$hostelId');
      if (month != null) queryParams.add('month=$month');
      if (rollNo != null) queryParams.add('rollNo=$rollNo');
      final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final res = await http.get(Uri.parse('$baseUrl/late-entries$query'), headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['lateEntries'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Fetch late entries error: $e');
      return [];
    }
  }

  /// 21. Create a Late Entry in Oracle backend
  static Future<Map<String, dynamic>> createLateEntry(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/late-entries'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('Create late entry error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 22. Delete a Late Entry
  static Future<bool> deleteLateEntry(String id) async {
    try {
      final headers = await _getHeaders();
      final res = await http.delete(Uri.parse('$baseUrl/late-entries/$id'), headers: headers).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Delete late entry error: $e');
      return false;
    }
  }

  /// 23. Fetch Leave Approvals from Oracle backend
  static Future<List<Map<String, dynamic>>> fetchLeaveApprovals({String? hostelId, String? month, String? rollNo}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String>[];
      if (hostelId != null) queryParams.add('hostelId=$hostelId');
      if (month != null) queryParams.add('month=$month');
      if (rollNo != null) queryParams.add('rollNo=$rollNo');
      final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final res = await http.get(Uri.parse('$baseUrl/leaves$query'), headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['leaves'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Fetch leave approvals error: $e');
      return [];
    }
  }

  /// 24. Create a Leave Approval in Oracle backend
  static Future<Map<String, dynamic>> createLeaveApproval(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/leaves'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('Create leave approval error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 25. Delete a Leave Approval
  static Future<bool> deleteLeaveApproval(String id) async {
    try {
      final headers = await _getHeaders();
      final res = await http.delete(Uri.parse('$baseUrl/leaves/$id'), headers: headers).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Delete leave approval error: $e');
      return false;
    }
  }

  /// 26. Fetch Medical Treatments & Prescriptions
  static Future<List<Map<String, dynamic>>> fetchMedicalTreatments({
    String? rollNo,
    String? studentId,
    String? hostelId,
    String? month,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String>[];
      if (rollNo != null && rollNo.isNotEmpty) queryParams.add('rollNo=${Uri.encodeComponent(rollNo)}');
      if (studentId != null && studentId.isNotEmpty) queryParams.add('studentId=${Uri.encodeComponent(studentId)}');
      if (hostelId != null && hostelId.isNotEmpty) queryParams.add('hostelId=${Uri.encodeComponent(hostelId)}');
      if (month != null && month.isNotEmpty) queryParams.add('month=${Uri.encodeComponent(month)}');
      final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final res = await http.get(
        Uri.parse('$baseUrl/medical/treatments$query'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['treatments'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Fetch medical treatments error: $e');
      return [];
    }
  }

  /// 27. Create Medical Treatment Record
  static Future<Map<String, dynamic>> createMedicalTreatment(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/medical/treatments'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('Create medical treatment error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 28. Update Medical Treatment Record
  static Future<Map<String, dynamic>> updateMedicalTreatment(String id, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final res = await http.put(
        Uri.parse('$baseUrl/medical/treatments/$id'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('Update medical treatment error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 29. Delete Medical Treatment Record
  static Future<bool> deleteMedicalTreatment(String id) async {
    try {
      final headers = await _getHeaders();
      final res = await http.delete(
        Uri.parse('$baseUrl/medical/treatments/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Delete medical treatment error: $e');
      return false;
    }
  }
}
