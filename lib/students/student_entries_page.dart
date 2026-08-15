import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../chat/chat_palette.dart';
import '../scanner/models/student_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/student_repository.dart';
import 'student_record_page.dart';

// Top-level cache to survive hot reloads and avoid State static issues in dart2js
final Map<String, String?> globalMockBookingTypes = {};
final Map<String, DateTime?> globalMockBookingTimes = {};
final Set<String> globalCancelledBookings = <String>{};

class StudentEntriesPage extends StatefulWidget {
  final List<StudentModel> entries;
  final VoidCallback onScanNew;
  final VoidCallback? onBack;
  final Function(String id)? onDeleteStudent;
  final Function(StudentModel student)? onUpdateStudent;

  const StudentEntriesPage({
    super.key,
    required this.entries,
    required this.onScanNew,
    this.onBack,
    this.onDeleteStudent,
    this.onUpdateStudent,
  });

  @override
  State<StudentEntriesPage> createState() => _StudentEntriesPageState();
}

class _StudentEntriesPageState extends State<StudentEntriesPage>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _hostelFilter = 'All';
  Timer? _debounceTimer;
  StreamSubscription? _medSub;
  final Map<String, DateTime> _liveBookings = {};
  final Map<String, String> _liveBookingTypes = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _medSub = WebSocketService.instance.events.listen((event) {
      if (event['type'] != 'MEDICAL_CHANGED') return;
      final data = event['data'];
      if (data is! Map<String, dynamic>) return;
      final apt = data['appointment'];
      final action = data['action']?.toString() ?? '';
      final studentId = apt is Map<String, dynamic>
          ? (apt['student_id']?.toString() ?? '')
          : (data['student_id']?.toString() ?? '');
      final rollNo = apt is Map<String, dynamic>
          ? (apt['roll_no']?.toString() ?? apt['student_roll_no']?.toString() ?? '')
          : (data['roll_no']?.toString() ?? '');

      if (!mounted) return;
      setState(() {
        if (action == 'delete') {
          if (studentId.isNotEmpty) {
            globalCancelledBookings.add(studentId);
            _liveBookings.remove(studentId);
            _liveBookingTypes.remove(studentId);
            globalMockBookingTypes.remove(studentId);
            globalMockBookingTimes.remove(studentId);
          }
          if (rollNo.isNotEmpty) {
            globalCancelledBookings.add(rollNo);
            _liveBookings.remove(rollNo);
            _liveBookingTypes.remove(rollNo);
            globalMockBookingTypes.remove(rollNo);
            globalMockBookingTimes.remove(rollNo);
          }
        } else if (apt is Map<String, dynamic>) {
          if (studentId.isNotEmpty) globalCancelledBookings.remove(studentId);
          if (rollNo.isNotEmpty) globalCancelledBookings.remove(rollNo);
          final created =
              DateTime.tryParse(apt['created_at']?.toString() ?? '') ??
                  DateTime.now();
          final rawType = (apt['appointment_type'] ?? apt['type'] ?? '')
              .toString()
              .toLowerCase();
          final type = (rawType.contains('counsel') || rawType.contains('counsell'))
              ? 'counsellor'
              : 'doctor';
          if (studentId.isNotEmpty) {
            _liveBookings[studentId] = created;
            _liveBookingTypes[studentId] = type;
            globalMockBookingTypes[studentId] = type;
            globalMockBookingTimes[studentId] = created;
          }
          if (rollNo.isNotEmpty) {
            _liveBookings[rollNo] = created;
            _liveBookingTypes[rollNo] = type;
            globalMockBookingTypes[rollNo] = type;
            globalMockBookingTimes[rollNo] = created;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    _medSub?.cancel();
    super.dispose();
  }

  List<StudentModel> get _filtered {
    final all = widget.entries;
    final list = all.where((s) {
      final q = _query.toLowerCase();
      final matchQ = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.rollNo.toLowerCase().contains(q) ||
          s.department.toLowerCase().contains(q) ||
          s.roomNo.toLowerCase().contains(q);
      final matchH = _hostelFilter == 'All' || s.hostel == _hostelFilter;
      return matchQ && matchH;
    }).toList();

    // Sort list systematically: Hostel -> Room No (alphanumerically) -> Student Name
    list.sort((a, b) {
      const hostelOrder = {
        'Boys Hostel': 1,
        'Umsawli Girls': 2,
        'Nongthymmai Girls': 3,
      };
      final orderA = hostelOrder[a.hostel] ?? 99;
      final orderB = hostelOrder[b.hostel] ?? 99;
      if (orderA != orderB) {
        return orderA.compareTo(orderB);
      }

      final r1 = a.roomNo.replaceAll(RegExp(r'^Room\s+', caseSensitive: false), '').trim();
      final r2 = b.roomNo.replaceAll(RegExp(r'^Room\s+', caseSensitive: false), '').trim();

      final regex = RegExp(r'^([a-zA-Z\s\-]*?)(\d+)$');
      final match1 = regex.firstMatch(r1);
      final match2 = regex.firstMatch(r2);

      if (match1 != null && match2 != null) {
        final prefix1 = match1.group(1) ?? '';
        final prefix2 = match2.group(1) ?? '';

        final prefixComp = prefix1.toLowerCase().compareTo(prefix2.toLowerCase());
        if (prefixComp != 0) {
          return prefixComp;
        }

        final num1 = int.tryParse(match1.group(2) ?? '0') ?? 0;
        final num2 = int.tryParse(match2.group(2) ?? '0') ?? 0;
        if (num1 != num2) {
          return num1.compareTo(num2);
        }
      } else {
        final strComp = r1.toLowerCase().compareTo(r2.toLowerCase());
        if (strComp != 0) {
          return strComp;
        }
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final list = _filtered;
    final allStudents = widget.entries;
    final total = allStudents.length;
    final boysCount = allStudents.where((s) => s.hostel == 'Boys Hostel').length;
    final umsawliCount = allStudents.where((s) => s.hostel == 'Umsawli Girls').length;
    final nongthymmaiCount = allStudents.where((s) => s.hostel == 'Nongthymmai Girls').length;

    return Container(
      color: ChatPalette.background,
      child: Column(children: [
        _EntriesHeader(
          total: total,
          onScanNew: widget.onScanNew,
          onBack: widget.onBack,
        ),
        _StatsRow(
          total: total,
          boysCount: boysCount,
          umsawliCount: umsawliCount,
          nongthymmaiCount: nongthymmaiCount,
        ),
        _SearchBar(ctrl: _searchCtrl, onChanged: (v) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _query = v);
          });
        }),
        _FilterChips(
          selected: _hostelFilter,
          onChanged: (v) => setState(() => _hostelFilter = v),
        ),
        Expanded(
          child: list.isEmpty
              ? _EmptyList()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final student = list[i];
                    final isCancelled = globalCancelledBookings.contains(student.id) ||
                        globalCancelledBookings.contains(student.rollNo);
                    final isBooked = !isCancelled && (
                        _liveBookings.containsKey(student.id) ||
                        _liveBookings.containsKey(student.rollNo) ||
                        globalMockBookingTimes.containsKey(student.id) ||
                        globalMockBookingTimes.containsKey(student.rollNo) ||
                        (student.medicalBookingTime != null && student.medicalBookingType != null)
                    );
                    final bTime = isCancelled
                        ? null
                        : (_liveBookings[student.id] ??
                            _liveBookings[student.rollNo] ??
                            globalMockBookingTimes[student.id] ??
                            globalMockBookingTimes[student.rollNo] ??
                            student.medicalBookingTime);
                    final bType = isCancelled
                        ? null
                        : (_liveBookingTypes[student.id] ??
                            _liveBookingTypes[student.rollNo] ??
                            globalMockBookingTypes[student.id] ??
                            globalMockBookingTypes[student.rollNo] ??
                            student.medicalBookingType);

                    return _StudentCard(
                      student: student,
                      index: i,
                      isLiveBooked: isBooked,
                      liveTime: bTime,
                      liveType: bType,
                      onDelete: widget.onDeleteStudent,
                      onUpdate: widget.onUpdateStudent,
                      onBookingChanged: (studentId, rollNo, type, time) {
                        setState(() {
                          if (type == null) {
                            globalCancelledBookings.add(studentId);
                            globalCancelledBookings.add(rollNo);
                            _liveBookings.remove(studentId);
                            _liveBookings.remove(rollNo);
                            _liveBookingTypes.remove(studentId);
                            _liveBookingTypes.remove(rollNo);
                            globalMockBookingTypes.remove(studentId);
                            globalMockBookingTypes.remove(rollNo);
                            globalMockBookingTimes.remove(studentId);
                            globalMockBookingTimes.remove(rollNo);
                          } else {
                            globalCancelledBookings.remove(studentId);
                            globalCancelledBookings.remove(rollNo);
                            _liveBookings[studentId] = time ?? DateTime.now();
                            _liveBookings[rollNo] = time ?? DateTime.now();
                            _liveBookingTypes[studentId] = type;
                            _liveBookingTypes[rollNo] = type;
                            globalMockBookingTypes[studentId] = type;
                            globalMockBookingTypes[rollNo] = type;
                            globalMockBookingTimes[studentId] = time ?? DateTime.now();
                            globalMockBookingTimes[rollNo] = time ?? DateTime.now();
                          }
                        });
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────
class _EntriesHeader extends StatelessWidget {
  final int total;
  final VoidCallback onScanNew;
  final VoidCallback? onBack;
  const _EntriesHeader({
    required this.total,
    required this.onScanNew,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: ChatPalette.background,
          border: Border(bottom: BorderSide(color: ChatPalette.borderSoft)),
        ),
        child: Row(children: [
          // ← Back button
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: 'Back to Chat',
              icon: Icon(
                Icons.arrow_back_rounded,
                color: ChatPalette.muted,
                size: 22,
              ),
              style: IconButton.styleFrom(
                minimumSize: Size(40, 40),
                hoverColor: ChatPalette.surfaceHover,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            )
          else
            SizedBox(width: 8),
          Icon(Icons.people_alt_rounded,
              color: ChatPalette.accent, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text('Student Entries',
                style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          // Scan new button
          GestureDetector(
            onTap: onScanNew,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1557B0), Color(0xFF1A73E8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 16),
                SizedBox(width: 5),
                Text('Scan New',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Stats row ──────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total, boysCount, umsawliCount, nongthymmaiCount;
  const _StatsRow({
    required this.total,
    required this.boysCount,
    required this.umsawliCount,
    required this.nongthymmaiCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _StatChip(value: '$total', label: 'Total', color: ChatPalette.accent)),
          SizedBox(width: 8),
          Expanded(child: _StatChip(value: '$boysCount', label: 'Boys', color: ChatPalette.accentBlue)),
          SizedBox(width: 8),
          Expanded(child: _StatChip(value: '$umsawliCount', label: 'Umsawli', color: ChatPalette.accentGreen)),
          SizedBox(width: 8),
          Expanded(child: _StatChip(value: '$nongthymmaiCount', label: 'Nongthymmai', color: ChatPalette.accentAmber)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatChip(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: ChatPalette.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

// ── Search bar ─────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: ChatPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: ChatPalette.borderGlow.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: ChatPalette.accentDeep.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Row(children: [
          SizedBox(width: 14),
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: ChatPalette.gradientPrimary,
            ).createShader(b),
            child: Icon(Icons.search_rounded,
                color: Colors.white, size: 18),
          ),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              style: TextStyle(
                  color: ChatPalette.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name, roll no, dept, room…',
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle:
                    TextStyle(color: ChatPalette.dim, fontSize: 14),
              ),
            ),
          ),
          if (ctrl.text.isNotEmpty)
            IconButton(
              onPressed: () {
                ctrl.clear();
                onChanged('');
              },
              icon: Icon(Icons.close_rounded,
                  color: ChatPalette.dim, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ]),
      ),
    );
  }
}

// ── Filter chips ───────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterChips({required this.selected, required this.onChanged});

  static const _chipColors = [
    [Color(0xFF334DFF), Color(0xFF7C8FFF)],
    [Color(0xFF4D7CFF), Color(0xFF7C8FFF)],
    [Color(0xFF00C17A), Color(0xFF00F5A0)],
    [Color(0xFFFF8C00), Color(0xFFFFB340)],
  ];

  @override
  Widget build(BuildContext context) {
    const options = ['All', 'Boys Hostel', 'Umsawli Girls', 'Nongthymmai Girls'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ...options.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(e.value),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: selected == e.value
                        ? LinearGradient(
                            colors: _chipColors[e.key % _chipColors.length])
                        : null,
                    color: selected == e.value ? null : ChatPalette.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected == e.value
                          ? _chipColors[e.key % _chipColors.length].first
                          : ChatPalette.border,
                    ),
                    boxShadow: selected == e.value
                        ? [
                            BoxShadow(
                              color: _chipColors[e.key % _chipColors.length]
                                  .first
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                          color: selected == e.value
                              ? Colors.white
                              : ChatPalette.dim,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Student card ───────────────────────────────────────────────────────────────
class _StudentCard extends StatefulWidget {
  final StudentModel student;
  final int index;
  final bool isLiveBooked;
  final DateTime? liveTime;
  final String? liveType;
  final Function(String)? onDelete;
  final Function(StudentModel)? onUpdate;
  final Function(String studentId, String rollNo, String? type, DateTime? time)? onBookingChanged;

  const _StudentCard({
    required this.student,
    required this.index,
    this.isLiveBooked = false,
    this.liveTime,
    this.liveType,
    this.onDelete,
    this.onUpdate,
    this.onBookingChanged,
  });

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  bool _expanded = false;
  Uint8List? _cachedPhotoBytes; // cached once — avoids base64Decode in every build()

  @override
  void initState() {
    super.initState();
    _decodePhoto(widget.student);
  }

  @override
  void didUpdateWidget(_StudentCard old) {
    super.didUpdateWidget(old);
    if (old.student.profilePhotoBase64 != widget.student.profilePhotoBase64) {
      _decodePhoto(widget.student);
    }
  }

  void _decodePhoto(StudentModel s) {
    try {
      if (s.profilePhotoBase64 != null && s.profilePhotoBase64!.isNotEmpty) {
        _cachedPhotoBytes = base64Decode(s.profilePhotoBase64!.split(',').last);
      } else {
        _cachedPhotoBytes = null;
      }
    } catch (_) {
      _cachedPhotoBytes = null;
    }
  }

  void _shareStudent() {
    final s = widget.student;
    final text = '''
Student: ${s.name}
Roll No: ${s.rollNo}
Department: ${s.department}
Room: ${s.roomNo}
Contact: ${s.contactNo}
Email: ${s.emailId}
Hostel: ${s.hostel}
''';
    // ignore: deprecated_member_use
    Share.share(text, subject: 'Student Details: ${s.name}');
  }

  void _deleteStudent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ChatPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ChatPalette.accentRose.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: ChatPalette.accentRose.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ChatPalette.accentRose.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_forever_rounded, color: ChatPalette.accentRose, size: 28),
              ),
              const SizedBox(height: 20),
              Text('Remove Student?', 
                  style: TextStyle(color: ChatPalette.text, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to completely remove ${widget.student.name} from the database? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ChatPalette.dim, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: ChatPalette.surfaceHigh,
                      ),
                      child: Text('Cancel', style: TextStyle(color: ChatPalette.text, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: ChatPalette.accentRose,
                      ),
                      child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;

    final studentId = widget.student.id;
    // 1. Instantly close detail modal (0ms UI lag)
    if (mounted) Navigator.pop(context);

    // 2. Instantly update UI and local state
    if (widget.onDelete != null) widget.onDelete!(studentId);

    // 3. Show instant confirmation snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Student deleted successfully', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: ChatPalette.accentRose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // 4. Background server deletion
    ApiService.deleteStudent(studentId).catchError((e) {
      debugPrint('Background delete failed for $studentId: $e');
      return false;
    });
  }

  void _updateBooking(String? type, {String? notes}) {
    final studentId = widget.student.id;
    final rollNo = widget.student.rollNo;

    final raw = type?.toLowerCase();
    final isCouns = raw != null &&
        (raw.contains('counsel') || raw.contains('counsell'));
    final normType = raw == null ? null : (isCouns ? 'counsellor' : 'doctor');
    final updatedTime = normType != null ? DateTime.now() : null;

    // 1. Instantly update global cache (0ms lag)
    if (normType != null) {
      globalCancelledBookings.remove(studentId);
      globalCancelledBookings.remove(rollNo);
      globalMockBookingTypes[studentId] = normType;
      globalMockBookingTypes[rollNo] = normType;
      globalMockBookingTimes[studentId] = updatedTime;
      globalMockBookingTimes[rollNo] = updatedTime;
    } else {
      globalCancelledBookings.add(studentId);
      globalCancelledBookings.add(rollNo);
      globalMockBookingTypes.remove(studentId);
      globalMockBookingTypes.remove(rollNo);
      globalMockBookingTimes.remove(studentId);
      globalMockBookingTimes.remove(rollNo);
    }

    // 2. Instantly notify parent widget so list reflects cancellation/booking immediately
    widget.onBookingChanged?.call(studentId, rollNo, normType, updatedTime);

    // 3. Update single source of truth in StudentRepository
    final updatedStudent = widget.student.copyWith(
      medicalBookingType: normType,
      medicalBookingTime: updatedTime,
      clearMedicalBooking: normType == null,
    );
    StudentRepository.updateStudent(updatedStudent);
    if (widget.onUpdate != null) {
      widget.onUpdate!(updatedStudent);
    }

    // 4. Immediately rebuild local card
    if (mounted) setState(() {});

    // 5. INSTANT (0.0 sec) SNACKBAR FEEDBACK — popup shows immediately!
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (normType != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Booked for ${normType == 'doctor' ? 'Campus Doctor' : 'Campus Counselor'} ✓',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: normType == 'doctor'
              ? ChatPalette.accentBlue
              : ChatPalette.accentAmber,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Appointment cancelled ✓',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Color(0xFF4A5568),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10))),
          duration: Duration(seconds: 2),
        ));
      }
    }

    // 6. Background network request (non-blocking, zero UI lag)
    if (normType != null) {
      ApiService.bookAppointment(
        studentId,
        normType,
        notes: notes ?? 'Booked by Warden',
        studentData: widget.student,
        createdAt: updatedTime,
      ).catchError((e) {
        debugPrint('Background booking error: $e');
        return false;
      });
    } else {
      ApiService.cancelAppointment(studentId, rollNo: rollNo).catchError((e) {
        debugPrint('Background cancellation error: $e');
        return false;
      });
    }
  }

  void _openStudentRecord() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => StudentRecordPage(
          student: widget.student.copyWith(
            medicalBookingType: _currentBookingType,
            medicalBookingTime: _currentBookingTime,
          ),
          onUpdateStudent: (updated) {
            if (widget.onUpdate != null) widget.onUpdate!(updated);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _showBookingSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: ChatPalette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ChatPalette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ChatPalette.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.medical_services_rounded,
                      color: ChatPalette.accentBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book Appointment',
                        style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.student.name} · Room ${widget.student.roomNo}',
                        style: TextStyle(
                          color: ChatPalette.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close_rounded, color: ChatPalette.dim, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Two Provider Options (Doctor & Counselor)
            Row(
              children: [
                // Option 1: Campus Doctor
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _updateBooking('doctor');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                      decoration: BoxDecoration(
                        color: ChatPalette.accentBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ChatPalette.accentBlue.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ChatPalette.accentBlue.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.local_hospital_rounded,
                                color: ChatPalette.accentBlue, size: 26),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Doctor',
                            style: TextStyle(
                              color: ChatPalette.accentBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Checkup & Treatment',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ChatPalette.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Option 2: Campus Counselor
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _updateBooking('counsellor');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                      decoration: BoxDecoration(
                        color: ChatPalette.accentAmber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ChatPalette.accentAmber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ChatPalette.accentAmber.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.psychology_rounded,
                                color: ChatPalette.accentAmber, size: 26),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Counselor',
                            style: TextStyle(
                              color: ChatPalette.accentAmber,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mental Wellbeing',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ChatPalette.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }


  void _editStudent() async {
    final nameCtrl = TextEditingController(text: widget.student.name);
    final rollCtrl = TextEditingController(text: widget.student.rollNo);
    final roomCtrl = TextEditingController(text: widget.student.roomNo);
    final contactCtrl = TextEditingController(text: widget.student.contactNo);
    final emailCtrl = TextEditingController(text: widget.student.emailId);

    Widget buildPremiumField(String label, IconData icon, TextEditingController controller) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: controller,
          style: TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: ChatPalette.muted, fontSize: 14),
            prefixIcon: Icon(icon, color: ChatPalette.accent.withValues(alpha: 0.7), size: 20),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ChatPalette.borderSoft.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ChatPalette.borderSoft.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ChatPalette.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      );
    }

    final result = await showDialog<StudentModel>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: ChatPalette.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ChatPalette.borderSoft.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: ChatPalette.accent.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: ChatPalette.borderSoft.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ChatPalette.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.edit_note_rounded, color: ChatPalette.accent),
                    ),
                    SizedBox(width: 16),
                    Text('Edit Student',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildPremiumField('Full Name', Icons.person_outline, nameCtrl),
                      buildPremiumField('Roll Number', Icons.badge_outlined, rollCtrl),
                      buildPremiumField('Room Number', Icons.meeting_room_outlined, roomCtrl),
                      buildPremiumField('Contact No.', Icons.phone_outlined, contactCtrl),
                      buildPremiumField('Email ID', Icons.email_outlined, emailCtrl),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: ChatPalette.borderSoft.withValues(alpha: 0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        foregroundColor: ChatPalette.muted,
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          ctx,
                          widget.student.copyWith(
                            name: nameCtrl.text,
                            rollNo: rollCtrl.text,
                            roomNo: roomCtrl.text,
                            contactNo: contactCtrl.text,
                            emailId: emailCtrl.text,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChatPalette.accentGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().scale(begin: const Offset(0.95, 0.95), duration: 200.ms, curve: Curves.easeOutCubic).fadeIn(),
      ),
    );

    if (result != null) {
      try {
        await ApiService.updateStudent(result.id, result.toBackend());
        if (widget.onUpdate != null) widget.onUpdate!(result);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully saved!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              backgroundColor: ChatPalette.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String? get _currentBookingType {
    // 1. If explicitly cancelled locally, return null immediately (0ms instant revert)
    if (globalCancelledBookings.contains(widget.student.id) ||
        globalCancelledBookings.contains(widget.student.rollNo)) {
      return null;
    }

    // 2. Check local cache
    if (globalMockBookingTypes.containsKey(widget.student.id)) {
      return globalMockBookingTypes[widget.student.id];
    }
    if (globalMockBookingTypes.containsKey(widget.student.rollNo)) {
      return globalMockBookingTypes[widget.student.rollNo];
    }

    // 3. Live stream from medical_appointments
    if (widget.isLiveBooked) {
      final live = widget.liveType;
      if (live == 'doctor' || live == 'counsellor') return live;
      return 'doctor';
    }

    return widget.student.medicalBookingType;
  }

  DateTime? get _currentBookingTime {
    // 1. If explicitly cancelled locally, return null immediately (0ms instant revert)
    if (globalCancelledBookings.contains(widget.student.id) ||
        globalCancelledBookings.contains(widget.student.rollNo)) {
      return null;
    }

    if (globalMockBookingTimes.containsKey(widget.student.id)) {
      return globalMockBookingTimes[widget.student.id];
    }
    if (globalMockBookingTimes.containsKey(widget.student.rollNo)) {
      return globalMockBookingTimes[widget.student.rollNo];
    }
    if (widget.isLiveBooked) return widget.liveTime;
    return widget.student.medicalBookingTime;
  }

  Color? get _bookingAccentColor {
    final type = _currentBookingType;
    if (type == 'doctor') return ChatPalette.accentBlue;
    if (type == 'counsellor') return ChatPalette.accentAmber;
    return null;
  }

  String _initials(String name) =>
      name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase();

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final bType = _currentBookingType;
    final bTime = _currentBookingTime;
    final isBooked = bType != null && bTime != null;

    // Overlay state onto student model
    final s = widget.student.copyWith(
      medicalBookingType: bType,
      medicalBookingTime: bTime,
      clearMedicalBooking: !isBooked,
    );

    final bookingColor = _bookingAccentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBooked
              ? (bookingColor ?? ChatPalette.border)
              : (_expanded ? ChatPalette.accent.withValues(alpha: 0.45) : ChatPalette.border),
          width: isBooked ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isBooked
                ? (bookingColor?.withValues(alpha: 0.12) ?? Colors.black.withValues(alpha: 0.04))
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isBooked ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        // Main row
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // Avatar circle
              GestureDetector(
                onTap: () {
                  final hasPhoto = (s.profilePhotoBase64 != null && s.profilePhotoBase64!.isNotEmpty)
                      || (s.photoPath != null && s.photoPath!.isNotEmpty);
                  if (!hasPhoto) return;

                  ImageProvider? imgProvider;
                  if (s.profilePhotoBase64 != null && s.profilePhotoBase64!.isNotEmpty) {
                    try {
                      imgProvider = MemoryImage(base64Decode(s.profilePhotoBase64!.split(',').last));
                    } catch (_) {}
                  }
                  imgProvider ??= s.photoPath != null ? NetworkImage(s.photoPath!) : null;
                  if (imgProvider == null) return;

                  showDialog(
                    context: context,
                    barrierColor: Colors.black87,
                    builder: (ctx) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                            ),
                          ),
                          Flexible(
                            child: Container(
                              width: 240,
                              height: 240,
                              decoration: const BoxDecoration(
                                color: Colors.black26,
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: Image(
                                  image: imgProvider!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isBooked
                        ? (bookingColor?.withValues(alpha: 0.12) ?? ChatPalette.surfaceHigh)
                        : ChatPalette.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isBooked
                          ? (bookingColor?.withValues(alpha: 0.6) ?? ChatPalette.border)
                          : ChatPalette.borderSoft,
                      width: isBooked ? 1.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _cachedPhotoBytes != null
                      ? Image.memory(
                          _cachedPhotoBytes!,
                          fit: BoxFit.cover,
                        )
                      : s.photoPath != null
                          ? Image.network(s.photoPath!, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                _initials(s.name),
                                style: TextStyle(
                                  color: isBooked ? bookingColor : ChatPalette.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        color: ChatPalette.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.department} · ${s.semester}',
                      style: TextStyle(
                        color: ChatPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Tag(
                          label: s.rollNo,
                          color: isBooked ? bookingColor! : ChatPalette.accent,
                        ),
                        _Tag(
                          label: 'Room ${s.roomNo}',
                          color: ChatPalette.accentGreen,
                        ),
                        if (isBooked)
                          _Tag(
                            label: s.medicalBookingType == 'counsellor'
                                ? '● Counselor'
                                : '● Doctor',
                            color: bookingColor!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Right side
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeAgo(s.createdAt),
                    style: TextStyle(
                      color: ChatPalette.dim,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _expanded
                            ? ChatPalette.accent.withValues(alpha: 0.1)
                            : ChatPalette.surfaceHigh,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _expanded
                              ? ChatPalette.accent.withValues(alpha: 0.3)
                              : ChatPalette.border,
                        ),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _expanded ? ChatPalette.accent : ChatPalette.dim,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),

        // Expanded details
        if (_expanded)
          Container(
            decoration: BoxDecoration(
              color: ChatPalette.canvas,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(
                top: BorderSide(color: ChatPalette.borderSoft),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _DetailGrid(student: s),
              const SizedBox(height: 12),

              // Active Appointment Banner if Booked
              if (isBooked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (bookingColor ?? ChatPalette.accentBlue).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (bookingColor ?? ChatPalette.accentBlue).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        s.medicalBookingType == 'counsellor'
                            ? Icons.psychology_rounded
                            : Icons.local_hospital_rounded,
                        color: bookingColor ?? ChatPalette.accentBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booked for ${s.medicalBookingType == 'counsellor' ? 'Campus Counselor' : 'Campus Doctor'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: bookingColor ?? ChatPalette.accentBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            if (s.medicalBookingTime != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Time: ${s.medicalBookingTime!.toLocal().toString().split('.')[0]}',
                                style: TextStyle(
                                    color: (bookingColor ?? ChatPalette.accentBlue).withValues(alpha: 0.8),
                                    fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _updateBooking(null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: (bookingColor ?? ChatPalette.accentBlue).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.close_rounded,
                              color: bookingColor ?? ChatPalette.accentBlue, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Primary Action Buttons Row (Student Record + Book Appointment)
              Row(
                children: [
                  // Button 1: Student Record
                  Expanded(
                    child: GestureDetector(
                      onTap: _openStudentRecord,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: ChatPalette.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ChatPalette.accent.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_shared_rounded,
                                color: ChatPalette.accent, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              'Student Record',
                              style: TextStyle(
                                color: ChatPalette.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Button 2: Book for Doctor & Counselor / Cancel Booking
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (isBooked) {
                          _updateBooking(null);
                        } else {
                          _showBookingSheet();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isBooked
                              ? ChatPalette.accentRose.withValues(alpha: 0.08)
                              : ChatPalette.accentBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isBooked
                                ? ChatPalette.accentRose.withValues(alpha: 0.4)
                                : ChatPalette.accentBlue.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isBooked ? ChatPalette.accentRose : ChatPalette.accentBlue)
                                  .withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isBooked
                                  ? Icons.cancel_outlined
                                  : Icons.medical_services_outlined,
                              color: isBooked
                                  ? ChatPalette.accentRose
                                  : ChatPalette.accentBlue,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isBooked
                                  ? 'Cancel Booking'
                                  : 'Book for Doctor & Counselor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isBooked
                                    ? ChatPalette.accentRose
                                    : ChatPalette.accentBlue,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Action buttons
              Row(children: [
                Expanded(
                  child: _CardActionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: ChatPalette.accent,
                    onTap: _editStudent,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _CardActionBtn(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    color: ChatPalette.accentGreen,
                    onTap: _shareStudent,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _CardActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove',
                    color: ChatPalette.accentRose,
                    onTap: _deleteStudent,
                  ),
                ),
              ]),
            ]),
          )
              .animate()
              .fadeIn(duration: 200.ms)
              .slideY(begin: -0.05, curve: Curves.easeOut),
      ]),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: min(widget.index * 60, 300)),
            duration: 300.ms)
        .slideX(begin: 0.05, curve: Curves.easeOut);
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 6,
            )
          ],
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2)),
      );
}

class _DetailGrid extends StatelessWidget {
  final StudentModel student;
  const _DetailGrid({required this.student});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Date of Birth', student.dateOfBirth),
      ('Gender', student.gender),
      ('Contact No.', student.contactNo),
      ('Email ID', student.emailId),
    ];
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 90,
            child: Text(item.$1,
                style: TextStyle(
                    color: ChatPalette.dim,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(item.$2,
                style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      )).toList(),
    );
  }
}

class _CardActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

// ── Empty list state ──────────────────────────────────────────────────────────
class _EmptyList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ChatPalette.accentDeep.withValues(alpha: 0.15),
                  ChatPalette.accent.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                  color: ChatPalette.accentDeep.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.search_off_rounded,
                color: ChatPalette.accent, size: 32),
          ),
          SizedBox(height: 16),
          Text('No students found',
              style: TextStyle(
                  color: ChatPalette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Try a different search or filter',
              style: TextStyle(color: ChatPalette.dim, fontSize: 13)),
        ]),
      );
}
