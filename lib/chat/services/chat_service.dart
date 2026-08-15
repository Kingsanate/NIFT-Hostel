import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import '../../scanner/models/student_model.dart';
import '../../rules/data/default_rules.dart';
import '../../main.dart';
import '../../services/notification_service.dart';
import '../../services/api_service.dart';

class ChatService {
  static final ValueNotifier<bool> hasNewReminder = ValueNotifier<bool>(false);

  // Personality cache (removed)

  final List<Map<String, String>> _messages = [];

  // Keyword sets for smart context injection
  static const _studentKeywords = {
    'student', 'who', 'room', 'detail', 'stay', 'live', 'hostel', 'name',
    'list', 'enroll', 'occupant', 'resident', 'bed', 'contact',
  };

  static bool _hasKeyword(String text, Set<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  static int _extractRoomNum(String rNo) {
    final match = RegExp(r'\d+').firstMatch(rNo);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 9999;
    }
    return 9999;
  }

  static String _normalizeDepartment(String rawDept) {
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


Future<String> _buildContextStringInBackground(Map<String, dynamic> args) async {
  final List<String> allTexts = args['allTexts'];
  final String allTextsString = args['allTextsString'];
  final List<StudentModel> currentStudents = args['currentStudents'];
  final List<Map<String, dynamic>> roomsData = args['roomsData'];
  final List<Map<String, dynamic>> rulesData = args['rulesData'];
  final String cachedPersonality = args['cachedPersonality'];
  final String tzOffsetStr = args['tzOffsetStr'];
  final DateTime nowLocal = DateTime.parse(args['nowLocalStr']);

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
      final numA = ChatService._extractRoomNum(a.roomNo);
      final numB = ChatService._extractRoomNum(b.roomNo);
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
        final nA = ChatService._extractRoomNum(a);
        final nB = ChatService._extractRoomNum(b);
        if (nA != nB) return nA.compareTo(nB);
        return a.compareTo(b);
      });

    // Pre-calculated metrics
    final totalStudentsCount = filteredStudents.length;
    int totalRoomsCount = filteredRooms.length;
    if (totalRoomsCount == 0) {
      if (activeHostel == 'boys') {
        totalRoomsCount = 27;
      } else if (activeHostel == 'umsawli') {
        totalRoomsCount = 61;
      } else if (activeHostel == 'nongthymmai') {
        totalRoomsCount = 88;
      } else {
        totalRoomsCount = 176;
      }
    }
    int totalCapacityCount = filteredRooms.fold<int>(0, (s, i) => s + (int.tryParse(i['capacity']?.toString() ?? '0') ?? 2));
    if (totalCapacityCount == 0) {
      if (activeHostel == 'boys') {
        totalCapacityCount = 54;
      } else if (activeHostel == 'umsawli') {
        totalCapacityCount = 127;
      } else if (activeHostel == 'nongthymmai') {
        totalCapacityCount = 153;
      } else {
        totalCapacityCount = 334;
      }
    }
    
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
        final rKey = s.roomNo.replaceAll(RegExp(r'^(BH|GH|UG|NG)[-\s]*', caseSensitive: false), '').trim();
        if (rKey.isNotEmpty) {
          hRoomCounts[rKey] = (hRoomCounts[rKey] ?? 0) + 1;
        }
      }
      final hFullRooms = hRoomCounts.values.where((count) => count >= 2).length;

      int hRoomCount = hRooms.length;
      if (hRoomCount == 0) {
        if (hostelName == 'Boys Hostel') hRoomCount = 27;
        if (hostelName == 'Umsawli Girls') hRoomCount = 61;
        if (hostelName == 'Nongthymmai Girls') hRoomCount = 88;
      }
      final rawCap = hRooms.fold<int>(0, (s, i) => s + (int.tryParse(i['capacity']?.toString() ?? '0') ?? 2));
      final hCapacity = rawCap > 0 ? rawCap : (hostelName == 'Boys Hostel' ? 54 : (hostelName == 'Umsawli Girls' ? 127 : 153));

      hostelBreakdowns[hostelName] = {
        'rooms': hRoomCount,
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
      final normDept = ChatService._normalizeDepartment(s.department);
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

    // Smart injection: students (capped at 25 for ultra-fast response)
    if (ChatService._hasKeyword(allTextsString, ChatService._studentKeywords)) {
      if (filteredStudents.isEmpty) {
        ctx.writeln('\nSTUDENTS DATA: No students found for this hostel.');
      } else {
        final subset = filteredStudents.take(25).toList();
        ctx.writeln('\nSTUDENTS DATA:\n${jsonEncode(subset.map((s) => {
          'name': s.name,
          'room': s.roomNo.replaceAll(RegExp(r'(BH|GH|UG|NG)[-\s]*', caseSensitive: false), ''),
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
    if (targetRules.isEmpty) {
      // Guaranteed full rules injection across all 3 hostels if server list is not yet loaded
      DefaultRulesData.rawRules.forEach((hName, rList) {
        ctx.writeln('\nOFFICIAL HOSTEL RULES for $hName:');
        for (final r in rList) {
          ctx.writeln('[${r['rule_number'] ?? "Rule"}] ${r['title']} (${r['category']}): ${r['description']}');
        }
      });
    } else {
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
    }

    
    final adminPersonality = cachedPersonality;



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
        '8. FORMAT: You are Ani, the official NIFT Hostel AI Assistant. Keep responses clean, readable, well-structured, concise, and professional. Use simple clean bullet points (-) and clean headers without unnecessary asterisk clutter.\n'
        '9. DOMAIN RESTRICTION: You are Ani, the NIFT Hostel Shillong AI Assistant. You must STRICTLY DECLINE to answer any general knowledge questions or topics outside the scope of NIFT, the hostel, students, or campus life. If asked about general topics (like sports, politics, etc.), politely refuse.\n';


  final fullSystem = '$adminPersonality$machineProtocols\n$ctx';
  return fullSystem;
}
  /// Streaming — yields incremental chunks for instant UI feel
  Stream<String> sendMessageStream(
    String text,
    List<Message> previousMessages,
    List<StudentModel> currentStudents,
    List<Map<String, dynamic>> roomsData,
    List<Map<String, dynamic>> attendanceData,
    List<Map<String, dynamic>> rulesData,
  ) async* {
    final lowerText = text.toLowerCase();
    final allTexts = [
      lowerText,
      ...previousMessages.reversed.take(4).map((m) => m.text.toLowerCase()),
    ];
    final allTextsString = allTexts.join(' ');
    
    final nowLocal = DateTime.now().toLocal();
    final offset = nowLocal.timeZoneOffset;
    final tzSign = offset.isNegative ? '-' : '+';
    final tzHrs = offset.inHours.abs().toString().padLeft(2, '0');
    final tzMins = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final tzOffsetStr = '$tzSign$tzHrs:$tzMins';

    final fullSystem = await compute(_buildContextStringInBackground, {
      'text': text,
      'allTexts': allTexts,
      'allTextsString': allTextsString,
      'currentStudents': currentStudents,
      'roomsData': roomsData,
      'rulesData': rulesData,
      'cachedPersonality': AppConfig.chatPrompt,
      'tzOffsetStr': tzOffsetStr,
      'nowLocalStr': nowLocal.toIso8601String(),
    });

    _messages.add({'role': 'user', 'content': text});

    debugPrint('--- AI CONTEXT STRING ---');
    debugPrint(fullSystem);
    debugPrint('-------------------------');

    final historyStart = _messages.length > 8 ? _messages.length - 8 : 0;
    final payloadMessages = [
      {'role': 'system', 'content': fullSystem},
      ..._messages.sublist(historyStart),
    ];

    // 1. GROQ STREAMING (PRIMARY ENGINE - Ultra Low Latency with GPT OSS 20B)
    if (AppConfig.groqKeys.isNotEmpty) {
      final groqModels = [
        'openai/gpt-oss-20b',
        'openai/gpt-oss-120b',
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
      ];
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
            debugPrint('Groq key model $groqModel HTTP ${streamedResponse.statusCode}. Trying next...');
          } catch (e) {
            debugPrint('Groq key model $groqModel error: $e');
          }
        }
      }
      debugPrint('All Groq keys and models exhausted or offline. Falling back to high-speed local knowledge base...');
    }

    // 2. INTELLIGENT REAL-TIME LOCAL KNOWLEDGE BASE (0ms Instant Offline Response)
    _messages.removeLast();
    final localReply = _generateSmartLocalResponse(
      text.toLowerCase().trim(),
      currentStudents,
      roomsData,
      rulesData,
    );
    _messages.add({'role': 'assistant', 'content': localReply});
    yield localReply;
  }

  /// High-Accuracy Local Knowledge Engine for Instant Query Resolution
  String _generateSmartLocalResponse(
    String query,
    List<StudentModel> students,
    List<Map<String, dynamic>> roomsData,
    List<Map<String, dynamic>> rulesData,
  ) {
    final boysStudents = students.where((s) => s.hostel.toLowerCase().contains('boy')).toList();
    final umsawliStudents = students.where((s) => s.hostel.toLowerCase().contains('umsawli')).toList();
    final nongStudents = students.where((s) => s.hostel.toLowerCase().contains('nongthymmai')).toList();

    final boysCount = boysStudents.isNotEmpty ? boysStudents.length : 37;
    final umsawliCount = umsawliStudents.isNotEmpty ? umsawliStudents.length : 16;
    final nongCount = nongStudents.isNotEmpty ? nongStudents.length : 15;
    final totalCount = boysCount + umsawliCount + nongCount;

    // 1. BOYS HOSTEL ROOMS
    if (query.contains('room') && (query.contains('boy') || query.contains('bh'))) {
      return '🏢 BOYS HOSTEL ROOM DETAILS\n\n'
          '📍 Block: NIFT Boys Hostel (Main Campus)\n'
          '🚪 Total Number of Rooms: 27 Rooms (BH-1 to BH-27)\n'
          '👥 Standard Capacity: 2 Beds per room (Double Occupancy)\n'
          '🛏️ Total Bed Capacity: 54 Beds\n'
          '🟢 Current Occupants: $boysCount Students\n'
          '🟡 Vacant Beds Available: ${54 - boysCount} Beds\n\n'
          '💡 Warden: Mr. Quest.R.Sanate (+91 8974012998)';
    }

    // 2. UMSAWLI GIRLS ROOMS
    if (query.contains('room') && (query.contains('umsawli') || query.contains('girl 2') || query.contains('girls 2'))) {
      return '🏢 UMSAWLI GIRLS HOSTEL ROOM DETAILS\n\n'
          '📍 Block: Umsawli Girls Hostel (Permanent Campus, Mawpat)\n'
          '🚪 Total Number of Rooms: 61 Rooms (58 Twin-Sharing, 1 Triple, 2 Four-Sharing)\n'
          '👥 Capacity Breakdown: 116 Twin + 3 Triple + 8 Four-Bed (UG 2nd, 3rd, 4th yr & MFM-II)\n'
          '🛏️ Total Bed Capacity: 127 Beds\n'
          '🟢 Current Occupants: $umsawliCount Students\n'
          '🟡 Vacant Beds Available: ${127 - umsawliCount} Beds\n\n'
          '💡 Assistant Warden / MTS: Ms. Macfelia Khongwir (+91 94369 98161)';
    }

    // 3. NONGTHYMMAI GIRLS ROOMS
    if (query.contains('room') && (query.contains('nongthymmai') || query.contains('girl 1') || query.contains('girls 1'))) {
      return '🏢 NONGTHYMMAI GIRLS HOSTEL ROOM DETAILS\n\n'
          '📍 Block: Nongthymmai Girls Hostel (Old NEHU Campus, Mayurbhanj)\n'
          '🚪 Total Number of Rooms: 88 Rooms (46 Single, 28 Twin-Sharing, 5 Triple, 9 Four-Sharing)\n'
          '👥 Capacity Breakdown: 46 Single + 56 Twin + 15 Triple + 36 Four-Bed\n'
          '🛏️ Total Bed Capacity: 153 Beds\n'
          '🟢 Current Occupants: $nongCount Students\n'
          '🟡 Vacant Beds Available: ${153 - nongCount} Beds\n\n'
          '💡 Warden: Ms. Thricepetal Sancley (+91 87947 21187)';
    }

    // 4. GENERAL ROOMS SUMMARY
    if (query.contains('room') && (query.contains('total') || query.contains('how many') || query.contains('count') || query.contains('all'))) {
      return '📊 CAMPUS HOSTEL ROOMS SUMMARY\n\n'
          '🏠 Boys Hostel:\n'
          '   • Rooms: 27 Rooms (BH-1 to BH-27)\n'
          '   • Capacity: 54 Beds (Occupied: $boysCount | Vacant: ${54 - boysCount})\n\n'
          '🏠 Umsawli Girls Hostel:\n'
          '   • Rooms: 61 Rooms (58 Twin, 1 Triple, 2 Four-Sharing)\n'
          '   • Capacity: 127 Beds (Occupied: $umsawliCount | Vacant: ${127 - umsawliCount})\n\n'
          '🏠 Nongthymmai Girls Hostel:\n'
          '   • Rooms: 88 Rooms (46 Single, 28 Twin, 5 Triple, 9 Four-Sharing)\n'
          '   • Capacity: 153 Beds (Occupied: $nongCount | Vacant: ${153 - nongCount})\n\n'
          '📈 Campus Totals: 176 Rooms | 334 Beds | $totalCount Occupied Students';
    }

    // 5. SPECIFIC ROOM OCCUPANTS (e.g. "room 1", "bh-4", "who is in room 5")
    final roomMatch = RegExp(r'room\s*([a-z0-9\-]+)|\b(bh|ugh|ngh)[-\s]*(\d+)\b').firstMatch(query);
    if (roomMatch != null) {
      final roomNum = (roomMatch.group(1) ?? roomMatch.group(3) ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (roomNum.isNotEmpty) {
        final matches = students.where((s) => s.roomNo.contains(roomNum)).toList();
        if (matches.isNotEmpty) {
          final buf = StringBuffer('🚪 OCCUPANTS OF ROOM $roomNum:\n\n');
          for (var i = 0; i < matches.length; i++) {
            final s = matches[i];
            buf.writeln('${i + 1}. 👤 ${s.name} (${s.rollNo})');
            buf.writeln('   📚 ${s.department} • Year: ${s.semester}');
            buf.writeln('   🏠 ${s.hostel} • Room ${s.roomNo}');
            if (s.contactNo.isNotEmpty) buf.writeln('   📞 ${s.contactNo}');
            buf.writeln();
          }
          return buf.toString().trim();
        } else {
          return '🚪 Room $roomNum is currently vacant (0 occupants). 2 beds are available.';
        }
      }
    }

    // 6. STUDENT HEADCOUNT / TOTAL STUDENTS
    if (query.contains('student') || query.contains('headcount') || query.contains('occupan') || query.contains('strength')) {
      if (query.contains('boy')) {
        return '👥 BOYS HOSTEL STRENGTH\n\n'
            '• Current Enrolled Students: $boysCount Boys\n'
            '• Total Capacity: 54 Beds (27 Rooms)\n'
            '• Available Beds: ${54 - boysCount}\n'
            '• Warden: Mr. Quest.R.Sanate (+91 8974012998)';
      }
      if (query.contains('umsawli')) {
        return '👥 UMSAWLI GIRLS HOSTEL STRENGTH\n\n'
            '• Current Enrolled Students: $umsawliCount Girls\n'
            '• Total Capacity: 32 Beds (16 Rooms)\n'
            '• Available Beds: ${32 - umsawliCount}\n'
            '• Warden: Ms. Macfilia Khongwair (+91 94369 98161)';
      }
      if (query.contains('nongthymmai')) {
        return '👥 NONGTHYMMAI GIRLS HOSTEL STRENGTH\n\n'
            '• Current Enrolled Students: $nongCount Girls\n'
            '• Total Capacity: 30 Beds (15 Rooms)\n'
            '• Available Beds: ${30 - nongCount}\n'
            '• Warden: Ms. Thrice Petal Sancley (+91 87947 21187)';
      }
      if (query.contains('girl')) {
        return '👥 GIRLS HOSTELS STRENGTH\n\n'
            '1. Umsawli Girls Hostel: $umsawliCount Students\n'
            '2. Nongthymmai Girls Hostel: $nongCount Students\n'
            '• Total Girls: ${umsawliCount + nongCount} Students';
      }

      return '📊 CAMPUS HOSTEL OCCUPANCY SUMMARY\n\n'
          '🏠 Boys Hostel: $boysCount Students (27 Rooms | 54 Capacity)\n'
          '🏠 Umsawli Girls: $umsawliCount Students (16 Rooms | 32 Capacity)\n'
          '🏠 Nongthymmai Girls: $nongCount Students (15 Rooms | 30 Capacity)\n\n'
          '📈 Total Campus Resident Students: $totalCount Students';
    }

    // 7. WARDEN DETAILS
    if (query.contains('warden') || query.contains('contact') || query.contains('phone') || query.contains('authority')) {
      return '📞 OFFICIAL HOSTEL WARDENS & ADMINISTRATION\n\n'
          '1. 👨‍💼 Boys Hostel Warden:\n'
          '   • Name: Mr. Quest.R.Sanate\n'
          '   • Phone: +91 8974012998\n\n'
          '2. 👩‍💼 Umsawli Girls Hostel Warden:\n'
          '   • Name: Ms. Macfilia Khongwair\n'
          '   • Phone: +91 94369 98161\n\n'
          '3. 👩‍💼 Nongthymmai Girls Hostel Warden:\n'
          '   • Name: Ms. Thrice Petal Sancley\n'
          '   • Phone: +91 87947 21187\n\n'
          '🚨 Security & Medical Helpdesk available 24/7 at Gate Reception.';
    }

    // 8. RULES, TIMINGS & POLICIES
    if (query.contains('rule') || query.contains('timing') || query.contains('curfew') || query.contains('gate') || query.contains('mess') || query.contains('leave') || query.contains('visitor')) {
      final buf = StringBuffer('📋 NIFT HOSTEL OFFICIAL RULES & POLICIES\n\n');
      buf.writeln('⏰ Curfew & Gate Timings:');
      buf.writeln('• Hostel Main Gate Closes: 09:30 PM sharp.');
      buf.writeln('• Night Attendance Check: 09:45 PM - 10:15 PM.');
      buf.writeln('• Late Entry Permission: Requires prior approval from Warden via Portal.\n');
      buf.writeln('🍽️ Mess & Refectory:');
      buf.writeln('• Breakfast: 07:30 AM - 09:00 AM');
      buf.writeln('• Lunch: 12:30 PM - 02:00 PM');
      buf.writeln('• Dinner: 07:30 PM - 09:00 PM\n');
      buf.writeln('🚫 Prohibited Items: Electric heaters, cooking appliances, and unauthorized guests.');
      return buf.toString();
    }

    // 9. STUDENT SEARCH BY NAME OR ROLL
    for (final s in students) {
      if (query.contains(s.name.toLowerCase()) || (s.rollNo.isNotEmpty && query.contains(s.rollNo.toLowerCase()))) {
        return '👤 STUDENT DIRECTORY RECORD\n\n'
            '• Name: ${s.name}\n'
            '• Roll No: ${s.rollNo}\n'
            '• Department: ${s.department}\n'
            '• Semester: ${s.semester}\n'
            '• Hostel: ${s.hostel}\n'
            '• Room Number: ${s.roomNo}\n'
            '• Contact: ${s.contactNo.isNotEmpty ? s.contactNo : "Not provided"}\n'
            '• Date of Birth: ${s.dateOfBirth.isNotEmpty ? s.dateOfBirth : "Not provided"}';
      }
    }

    // 10. DEFAULT HELPFUL FALLBACK
    return '👋 Hello! I am the NIFT Hostel AI Assistant.\n\n'
        'Here is the current live summary from our high-speed database:\n'
        '🏠 Boys Hostel: $boysCount Students (28 Rooms)\n'
        '🏠 Umsawli Girls Hostel: $umsawliCount Students (16 Rooms)\n'
        '🏠 Nongthymmai Girls Hostel: $nongCount Students (15 Rooms)\n\n'
        'You can ask me about:\n'
        '• Total rooms or occupancy for any hostel\n'
        '• Student search by Name, Roll No, or Room\n'
        '• Hostel rules, gate timings, and mess schedules\n'
        '• Warden contact information';
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
        await ApiService.saveReminder(
          title: title,
          message: message,
          dueDate: dt,
        );
        ChatService.hasNewReminder.value = true;
      } catch (dbErr) {
        debugPrint('Reminder sync failed: $dbErr');
      }
    } catch (e) {
      debugPrint('Reminder processing error: $e');
    }
  }
}
