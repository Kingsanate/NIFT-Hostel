import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_models.dart';
import '../../scanner/models/student_model.dart';
import '../../main.dart';
import '../../services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final ValueNotifier<bool> hasNewReminder = ValueNotifier<bool>(false);

  // Personality cache
  static final String _cachedPersonality = '';

  final List<Map<String, String>> _messages = [];

  // Keyword sets for smart context injection
  static const _studentKeywords = {
    'student', 'who', 'room', 'detail', 'stay', 'live', 'hostel', 'name',
    'list', 'enroll', 'occupant', 'resident', 'bed', 'contact',
  };
  static const _complaintKeywords = {
    'complaint', 'issue', 'problem', 'report', 'damage', 'broken',
  };

  static bool _hasKeyword(String text, Set<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  int _extractRoomNum(String rNo) {
    final match = RegExp(r'\d+').firstMatch(rNo);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 9999;
    }
    return 9999;
  }

  String _normalizeDepartment(String rawDept) {
    final d = rawDept.toUpperCase().trim();
    if (d.isEmpty) return 'General / Unassigned';

    if (d.contains('FC') || d.contains('COMMUNICATION')) {
      return 'Fashion Communication (FC)';
    } else if (d.contains('AD') || d.contains('ACCESSORY')) {
      return 'Accessory Design (AD)';
    } else if (d.contains('FD') || d.contains('FASHION DESIGN') || d.contains('F.D')) {
      return 'Fashion Design (FD)';
    } else if (d.contains('TD') || d.contains('T.D') || d.contains('TEXTILE')) {
      return 'Textile Design (TD)';
    } else if (d.contains('LD') || d.contains('LEATHER')) {
      return 'Leather Design (LD)';
    } else if (d.contains('DFT') || d.contains('FTECH') || d.contains('FT') || d.contains('TECHNOLOGY')) {
      return 'Fashion Technology (FT)';
    } else if (d.contains('MFM') || d.contains('MANAGEMENT')) {
      return 'Master of Fashion Management (MFM)';
    }

    return rawDept.trim();
  }

  /// Streaming — yields incremental chunks for instant UI feel
  Stream<String> sendMessageStream(
    String text,
    List<Message> previousMessages,
    List<StudentModel> currentStudents,
    List<Map<String, dynamic>> roomsData,
    List<Map<String, dynamic>> attendanceData,
    List<Map<String, dynamic>> complaintsData,
    List<Map<String, dynamic>> rulesData,
  ) async* {
    final lowerText = text.toLowerCase();
    final allTexts = [
      lowerText,
      ...previousMessages.reversed.take(4).map((m) => m.text.toLowerCase()),
    ];
    final allTextsString = allTexts.join(' ');

    // Detect active hostel from conversation
    String activeHostel = '';
    for (final t in allTexts) {
      if (t.contains('boys') || t.contains('boy')) { activeHostel = 'boys'; break; }
      else if (t.contains('umsawli')) { activeHostel = 'umsawli'; break; }
      else if (t.contains('nongthymmai')) { activeHostel = 'nongthymmai'; break; }
      else if (t.contains('girl') || t.contains('girls')) { activeHostel = 'girls_ambiguous'; break; }
    }

    // Filter to active hostel
    List<StudentModel> filteredStudents = List<StudentModel>.from(currentStudents);
    List<Map<String, dynamic>> filteredRooms = roomsData;
    List<Map<String, dynamic>> filteredRules = rulesData;

    if (activeHostel == 'boys') {
      filteredStudents = currentStudents.where((s) => s.hostel.toLowerCase().contains('boy')).toList();
      filteredRooms = roomsData.where((r) => (r['hostelId'] ?? r['hostel_name']).toString().toLowerCase().contains('boy')).toList();
      filteredRules = rulesData.where((r) => r['hostel_name'].toString().toLowerCase().contains('boy')).toList();
    } else if (activeHostel == 'umsawli') {
      filteredStudents = currentStudents.where((s) => s.hostel.toLowerCase().contains('umsawli')).toList();
      filteredRooms = roomsData.where((r) => (r['hostelId'] ?? r['hostel_name']).toString().toLowerCase().contains('umsawli')).toList();
      filteredRules = rulesData.where((r) => r['hostel_name'].toString().toLowerCase().contains('umsawli')).toList();
    } else if (activeHostel == 'nongthymmai') {
      filteredStudents = currentStudents.where((s) => s.hostel.toLowerCase().contains('nongthymmai')).toList();
      filteredRooms = roomsData.where((r) => (r['hostelId'] ?? r['hostel_name']).toString().toLowerCase().contains('nongthymmai')).toList();
      filteredRules = rulesData.where((r) => r['hostel_name'].toString().toLowerCase().contains('nongthymmai')).toList();
    }

    // Sort students in ascending numerical order of their room numbers (Room 1, 2, 3, 4...)
    filteredStudents.sort((a, b) {
      final numA = _extractRoomNum(a.roomNo);
      final numB = _extractRoomNum(b.roomNo);
      if (numA != numB) return numA.compareTo(numB);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // Group students by room number in ascending order
    Map<String, List<StudentModel>> roomWiseStudents = {};
    for (var s in filteredStudents) {
      final cleanRoom = s.roomNo.replaceAll(RegExp(r'^(BH|UG|NG)[-\s]*', caseSensitive: false), '').trim();
      final roomKey = cleanRoom.isEmpty ? 'Unassigned' : cleanRoom;
      roomWiseStudents.putIfAbsent(roomKey, () => []).add(s);
    }

    final sortedRoomKeys = roomWiseStudents.keys.toList()
      ..sort((a, b) {
        final nA = _extractRoomNum(a);
        final nB = _extractRoomNum(b);
        if (nA != nB) return nA.compareTo(nB);
        return a.compareTo(b);
      });

    // Pre-calculated metrics
    final totalStudentsCount = filteredStudents.length;
    final totalRoomsCount = filteredRooms.length;
    final totalCapacityCount = filteredRooms.fold<int>(0, (s, i) => s + (int.tryParse(i['capacity']?.toString() ?? '0') ?? 2));
    
    final fullyOccupiedCount = roomWiseStudents.values.where((list) => list.length >= 2).length;

    Map<String, Map<String, int>> hostelBreakdowns = {};
    for (final hostelName in ['Boys Hostel', 'Umsawli Girls', 'Nongthymmai Girls']) {
      final hRooms = roomsData.where((r) {
        final id = (r['hostelId'] ?? r['hostel_id'] ?? '').toString().toLowerCase();
        if (hostelName == 'Boys Hostel') return id.contains('boy');
        if (hostelName == 'Umsawli Girls') return id.contains('umsawli');
        if (hostelName == 'Nongthymmai Girls') return id.contains('nongthymmai');
        return false;
      }).toList();
      final hStudents = currentStudents.where((s) {
        final h = s.hostel.toLowerCase();
        if (hostelName == 'Boys Hostel') return h.contains('boy');
        if (hostelName == 'Umsawli Girls') return h.contains('umsawli');
        if (hostelName == 'Nongthymmai Girls') return h.contains('nongthymmai');
        return false;
      }).toList();

      Map<String, int> hRoomCounts = {};
      for (var s in hStudents) {
        final rKey = s.roomNo.replaceAll(RegExp(r'^(BH|UG|NG)[-\s]*', caseSensitive: false), '').trim();
        if (rKey.isNotEmpty) {
          hRoomCounts[rKey] = (hRoomCounts[rKey] ?? 0) + 1;
        }
      }
      final hFullRooms = hRoomCounts.values.where((count) => count >= 2).length;
      final rawCap = hRooms.fold<int>(0, (s, i) => s + (int.tryParse(i['capacity']?.toString() ?? '0') ?? 2));
      final hCapacity = rawCap > 0 ? rawCap : (hRooms.length * 2);

      hostelBreakdowns[hostelName] = {
        'rooms': hRooms.length,
        'capacity': hCapacity,
        'occupied': hStudents.length,
        'available': (hCapacity - hStudents.length) > 0 ? (hCapacity - hStudents.length) : 0,
        'fullRooms': hFullRooms,
      };
    }

    // Build lean context string
    final ctx = StringBuffer('SYSTEM CONTEXT - LIVE HOSTEL METRICS & ROOM DIRECTORY:\n\n');

    if (activeHostel == 'girls_ambiguous') {
      ctx.writeln('ACTION REQUIRED: User asked about "Girls Hostel" but there are TWO girls hostels. Ask which one: Umsawli or Nongthymmai.\n');
    } else if (activeHostel.isNotEmpty) {
      ctx.writeln('FILTERED METRICS (${activeHostel.toUpperCase()} HOSTEL):\n- Total Rooms: $totalRoomsCount\n- Capacity: $totalCapacityCount beds\n- Occupancy: $totalStudentsCount students\n- Available: ${totalCapacityCount - totalStudentsCount} beds\n- Full rooms (2 students): $fullyOccupiedCount\n');
    } else {
      ctx.writeln('ALL HOSTELS SUMMARY:');
      for (final entry in hostelBreakdowns.entries) {
        final m = entry.value;
        ctx.writeln('${entry.key}: Rooms=${m['rooms']} | Capacity=${m['capacity']} | Occupied=${m['occupied']} | Available=${m['available']} | Full Rooms (2 students)=${m['fullRooms']}');
      }
    }

    // Department breakdown pre-calculation with smart normalization
    Map<String, List<StudentModel>> departmentWiseStudents = {};
    for (var s in filteredStudents) {
      final normDept = _normalizeDepartment(s.department);
      departmentWiseStudents.putIfAbsent(normDept, () => []).add(s);
    }

    // Always inject room-wise occupancy directory in ascending room order
    ctx.writeln('\nLIVE ROOM-WISE OCCUPANCY & STUDENT DIRECTORY (Sorted in Ascending Room Order):');
    if (sortedRoomKeys.isEmpty) {
      ctx.writeln('No room assignments found.');
    } else {
      for (final rKey in sortedRoomKeys) {
        final occupants = roomWiseStudents[rKey]!;
        final count = occupants.length;
        final statusStr = count >= 2 ? 'FULL (2/2)' : (count == 1 ? '1/2 Occupied (1 Bed Available)' : 'Vacant');
        final studentDetails = occupants.map((s) => '${s.name} (${s.rollNo}, ${s.department})').join(' & ');
        ctx.writeln('- Room $rKey [$statusStr]: $studentDetails');
      }
    }

    ctx.writeln('\nLIVE DEPARTMENT-WISE BREAKDOWN & RESIDENT DIRECTORY (${activeHostel.isEmpty ? "ALL HOSTELS" : activeHostel.toUpperCase()}):');
    if (departmentWiseStudents.isEmpty) {
      ctx.writeln('No department data available.');
    } else {
      for (final entry in departmentWiseStudents.entries) {
        final deptName = entry.key;
        final occupants = entry.value;
        final names = occupants.map((s) => '${s.name} (Room: ${s.roomNo.isEmpty ? "Unassigned" : s.roomNo})').join(', ');
        ctx.writeln('- $deptName [Total: ${occupants.length} student(s)]: $names');
      }
    }

    // Smart injection: complaints
    if (_hasKeyword(allTextsString, _complaintKeywords)) {
      ctx.writeln('\nCOMPLAINTS:\n${jsonEncode(complaintsData.map((c) => {'student': c['student_name'], 'type': c['issue_type'], 'status': c['status']}).toList())}');
    }

    // Smart injection: students (capped at 25 for ultra-fast response)
    if (_hasKeyword(allTextsString, _studentKeywords)) {
      if (filteredStudents.isEmpty) {
        ctx.writeln('\nSTUDENTS DATA: No students found for this hostel.');
      } else {
        final subset = filteredStudents.take(25).toList();
        ctx.writeln('\nSTUDENTS DATA:\n${jsonEncode(subset.map((s) => {
          'name': s.name,
          'room': s.roomNo.replaceAll(RegExp(r'(BH|UG|NG)[-\s]*', caseSensitive: false), ''),
          'contact': s.contactNo,
        }).toList())}');
      }
    }

    // ALWAYS inject Hostel Rules and Committee Members into System Context!
    ctx.writeln('''

OFFICIAL NIFT HOSTEL COMMITTEE MEMBERS & WARDENS DIRECTORY:
1. Ms. Rimi Das, Assoc. Prof. & Joint Director
2. Dr. Ngamkholen Haokip, Asst. Prof.
3. Dr. Lisa L Pachuau, Asst. Prof.
4. Dr. Natalie Diengdoh, Asst. Prof. & SDAC
5. Ms. Thricepetal Sancley, Asst. Warden, Nongthymmai Girls' Hostel (Contact: 87947 21187)
6. Mr. Quest R. Sanate, Asst. Warden, NIFT Campus Boys' Hostel (Contact: 9774164689, 8974012998)
7. Ms. Macfelia Khongwir, MTS, NIFT Campus Girls' Hostel / Umsawli Girls (Contact: 94369 98161)
''');

    final targetRules = filteredRules.isNotEmpty ? filteredRules : rulesData;
    for (final ruleData in targetRules) {
      final raw = ruleData['extracted_text']?.toString() ?? '';
      if (raw.isEmpty) continue;
      try {
        final List<dynamic> rulesList = jsonDecode(raw);
        ctx.writeln('\nOFFICIAL HOSTEL RULES for ${ruleData['hostel_name']}:');
        for (final r in rulesList) {
          ctx.writeln('[${r['rule_number'] ?? "Rule"}] ${r['title']} (${r['category']}): ${r['description']}');
        }
      } catch (e) {
        final truncated = raw.length > 3000 ? '${raw.substring(0, 3000)}\n...[TRUNCATED]' : raw;
        ctx.writeln('\nOFFICIAL HOSTEL RULES:\n$truncated');
      }
    }

    _messages.add({'role': 'user', 'content': text});

    final adminPersonality = _cachedPersonality;

    // Time context
    final nowLocal = DateTime.now().toLocal();
    final offset = nowLocal.timeZoneOffset;
    final tzSign = offset.isNegative ? '-' : '+';
    final tzHrs = offset.inHours.abs().toString().padLeft(2, '0');
    final tzMins = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final tzOffsetStr = '$tzSign$tzHrs:$tzMins';

    final machineProtocols = '\n\n=== MANDATORY SYSTEM PROTOCOLS (NEVER BREAK THESE) ===\n'
        'Current Local Date and Time: $nowLocal (Timezone: $tzOffsetStr)\n'
        '1. ACCURATE LIVE ROOM DATA: You have full access to LIVE ROOM-WISE OCCUPANCY & STUDENT DIRECTORY in the context. Never state that room wise occupancy is not provided.\n'
        '2. ASCENDING ROOM ORDER: Always list rooms and students in ascending numerical order by room number (e.g. Room 1, 2, 3, 4... or starting from 4, 5, 6... if lowest occupied room is 4).\n'
        '3. ROOM CAPACITY RULE: In all NIFT Hostels, EVERY room has a capacity of EXACTLY 2 BEDS / 2 STUDENTS (Double Occupancy).\n'
        '   - A room with 2 students is 100% FULL. NEVER state or imply that a room with 2 students is not full.\n'
        '   - A room with 1 student has 1 bed available.\n'
        '   - A room with 0 students is completely vacant (2 beds available).\n'
        '4. REMINDER: If user asks to set a reminder, append at end: [REMINDER|YYYY-MM-DDTHH:mm:ss$tzOffsetStr|Title|Message]\n'
        '   Use LOCAL timezone ($tzOffsetStr).\n'
        '5. RULES: Quote rule heading and number exactly as in context. Never invent a rule number.\n'
        '6. NIFT DEPARTMENT ABBREVIATIONS:\n'
        '   - FC = Fashion Communication\n'
        '   - AD = Accessory Design / Apparel Design\n'
        '   - FD = Fashion Design\n'
        '   - TD = Textile Design\n'
        '   - LD = Leather Design\n'
        '   - DFT / FTech / FT = Fashion Technology\n'
        '   - MFM = Master of Fashion Management\n'
        '   - When users ask about FC, AD, FD, etc., match both short codes and full department names!\n'
        '7. HOSTEL COMMITTEE & WARDENS: You have full access to OFFICIAL HOSTEL RULES & COMMITTEE MEMBERS in context. When asked about hostel committee members, wardens, staff, or contacts, provide the exact names, designations, and phone numbers.\n'
        '8. FORMAT: NEVER use ** or * or #. Use EMOJIS for structure. Keep responses concise.\n';

    final fullSystem = '$adminPersonality$machineProtocols\n$ctx';
    debugPrint('--- AI CONTEXT STRING ---');
    debugPrint(fullSystem);
    debugPrint('-------------------------');

    final historyStart = _messages.length > 8 ? _messages.length - 8 : 0;
    final payloadMessages = [
      {'role': 'system', 'content': fullSystem},
      ..._messages.sublist(historyStart),
    ];

    // 1. GROQ STREAMING (PRIMARY ENGINE)
    if (AppConfig.groqKeys.isNotEmpty) {
      final groqModels = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'mixtral-8x7b-32768'];
      for (final groqKey in AppConfig.groqKeys) {
        for (final groqModel in groqModels) {
          try {
            final request = http.Request('POST', Uri.parse('https://api.groq.com/openai/v1/chat/completions'));
            request.headers['Authorization'] = 'Bearer $groqKey';
            request.headers['Content-Type'] = 'application/json';
            request.body = jsonEncode({
              'model': groqModel,
              'messages': payloadMessages,
              'temperature': 0.2,
              'stream': true,
            });
            final client = http.Client();
            final streamedResponse = await client.send(request).timeout(const Duration(seconds: 15));

            if (streamedResponse.statusCode == 200) {
              final fullReply = StringBuffer();
              bool reminderStarted = false;

              await for (final line in streamedResponse.stream.transform(const Utf8Decoder()).transform(const LineSplitter())) {
                if (line.startsWith('data: ') && line != 'data: [DONE]') {
                  try {
                    final j = jsonDecode(line.substring(6));
                    final delta = j['choices']?[0]?['delta']?['content'];
                    if (delta is String && delta.isNotEmpty) {
                      fullReply.write(delta);
                      if (!reminderStarted) {
                        final full = fullReply.toString();
                        if (full.contains('[REMINDER|')) {
                          reminderStarted = true;
                          yield full.split('[REMINDER|')[0].trim();
                        } else {
                          yield full;
                        }
                      }
                    }
                  } catch (_) {}
                }
              }
              client.close();
              final cleanReply = fullReply.toString().split('[REMINDER|')[0].trim();
              if (!reminderStarted) yield cleanReply;
              await _processReminders(fullReply.toString());
              _messages.add({'role': 'assistant', 'content': cleanReply});
              return; // Groq succeeded! Return immediately without touching Gemini.
            }
            client.close();
            debugPrint('Groq key (ending in ${groqKey.substring(groqKey.length - 4)}) model $groqModel HTTP ${streamedResponse.statusCode}. Trying next Groq model/key...');
          } catch (e) {
            debugPrint('Groq key (ending in ${groqKey.substring(groqKey.length - 4)}) model $groqModel error: $e');
          }
        }
      }
      debugPrint('All Groq keys and models exhausted. Falling back to Gemini...');
    }

    // GEMINI FALLBACK
    final geminiModels = ['gemini-flash-latest', 'gemini-3.6-flash', 'gemini-2.0-flash-lite', 'gemini-2.0-flash'];
    for (final apiKey in AppConfig.activeKeys) {
      for (final gModel in geminiModels) {
        try {
          final model = GenerativeModel(
            model: gModel,
            apiKey: apiKey,
            generationConfig: GenerationConfig(temperature: 0.2),
          );
          final geminiPrompt = StringBuffer();
          for (final msg in payloadMessages) {
            switch (msg['role']) {
              case 'system': geminiPrompt.writeln('SYSTEM INSTRUCTION: ${msg['content']}');
              case 'user': geminiPrompt.writeln('USER: ${msg['content']}');
              default: geminiPrompt.writeln('ASSISTANT: ${msg['content']}');
            }
          }
          final fullReply = StringBuffer();
          bool reminderStarted = false;

          await for (final chunk in model.generateContentStream([Content.text(geminiPrompt.toString())])) {
            if (chunk.text != null && chunk.text!.isNotEmpty) {
              fullReply.write(chunk.text!);
              if (!reminderStarted) {
                final full = fullReply.toString();
                if (full.contains('[REMINDER|')) {
                  reminderStarted = true;
                  yield full.split('[REMINDER|')[0].trim();
                } else {
                  yield full;
                }
              }
            }
          }
          final cleanReply = fullReply.toString().split('[REMINDER|')[0].trim();
          if (!reminderStarted) yield cleanReply;
          await _processReminders(fullReply.toString());
          _messages.add({'role': 'assistant', 'content': cleanReply});
          return; // Gemini succeeded! Return immediately.
        } catch (e) {
          debugPrint('Gemini model $gModel error: $e');
          continue;
        }
      }
    }

    _messages.removeLast();
    final offlineReply = StringBuffer('⚠️ AI Server Quota Limit Reached (Free Tier)\n\n');
    offlineReply.writeln('Here is the live hostel summary from local database:\n');
    offlineReply.writeln('🏠 Boys Hostel: ${hostelBreakdowns['Boys Hostel']?['occupied'] ?? 0}/${hostelBreakdowns['Boys Hostel']?['capacity'] ?? 0} beds occupied (${hostelBreakdowns['Boys Hostel']?['available'] ?? 0} available)');
    offlineReply.writeln('🏠 Umsawli Girls: ${hostelBreakdowns['Umsawli Girls']?['occupied'] ?? 0}/${hostelBreakdowns['Umsawli Girls']?['capacity'] ?? 0} beds occupied (${hostelBreakdowns['Umsawli Girls']?['available'] ?? 0} available)');
    offlineReply.writeln('🏠 Nongthymmai Girls: ${hostelBreakdowns['Nongthymmai Girls']?['occupied'] ?? 0}/${hostelBreakdowns['Nongthymmai Girls']?['capacity'] ?? 0} beds occupied (${hostelBreakdowns['Nongthymmai Girls']?['available'] ?? 0} available)\n');
    offlineReply.writeln('💡 Note: You can update the Gemini/Groq API key in the Supabase app_config table to restore full AI capabilities.');
    yield offlineReply.toString();
  }

  Future<void> _processReminders(String reply) async {
    if (!reply.contains('[REMINDER|')) return;
    try {
      final tagStart = reply.indexOf('[REMINDER|');
      final tagEnd = reply.indexOf(']', tagStart);
      if (tagEnd == -1) return;

      final parts = reply.substring(tagStart + 10, tagEnd).split('|');
      if (parts.length < 3) return;

      final dateStr = parts[0].trim();
      final title = parts[1].trim();
      final message = parts[2].trim();

      final cleanDateStr = dateStr.length >= 19 ? dateStr.substring(0, 19) : dateStr;
      DateTime? scheduledDate = DateTime.tryParse(cleanDateStr);
      if (scheduledDate != null) {
        scheduledDate = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day,
            scheduledDate.hour, scheduledDate.minute, scheduledDate.second);
      }

      final nowId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await NotificationService().showNow(
        id: nowId,
        title: '🔔 Reminder Set: $title',
        body: 'Scheduled: ${scheduledDate?.toLocal() ?? dateStr}. $message',
      );

      if (scheduledDate != null && scheduledDate.isAfter(DateTime.now())) {
        await NotificationService().scheduleReminder(
          id: (scheduledDate.millisecondsSinceEpoch.remainder(100000) + 1),
          title: 'set $title',
          body: message,
          scheduledDate: scheduledDate,
        );
      }

      try {
        final dt = scheduledDate ?? DateTime.now();
        final off = dt.timeZoneOffset;
        final sign = off.isNegative ? '-' : '+';
        final hrs = off.inHours.abs().toString().padLeft(2, '0');
        final mins = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
        await Supabase.instance.client.from('reminders').insert({
          'title': title, 'message': message, 'priority': 'Medium',
          'due_date': '${dt.toIso8601String()}$sign$hrs:$mins',
        });
        hasNewReminder.value = true;
      } catch (dbErr) {
        debugPrint('Reminder sync failed: $dbErr');
      }
    } catch (e) {
      debugPrint('Reminder processing error: $e');
    }
  }
}
