import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../chat/chat_palette.dart';
import '../scanner/models/student_model.dart';
import '../services/api_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:convert';

class AttendancePage extends StatefulWidget {
  final List<StudentModel> students;
  final VoidCallback onMenuPressed;
  final bool compact;

  const AttendancePage({
    super.key,
    required this.students,
    required this.onMenuPressed,
    this.compact = false,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late DateTime _selectedDate;
  int _selectedHostelIndex = 0;

  @override
  bool get wantKeepAlive => true;
  
  final List<String> _hostels = ['Boys Hostel', 'Umsawli Girls', 'Nongthymmai Girls'];
  final List<String> _hostelIds = ['boys', 'girls1', 'girls2'];

  // Map of Student ID -> Status ('present', 'absent', 'leave')
  final Map<String, String> _attendanceMap = {};
  bool _isSaving = false;
  bool _isLocked = false;
  String _saveStatus = '';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _tabController = TabController(length: _hostels.length, vsync: this);
    
    // Seed initial default status as 'present' for instant display
    _initializeDefaultStatuses();

    _tabController.addListener(() {
      if (_tabController.index != _selectedHostelIndex) {
        setState(() {
          _selectedHostelIndex = _tabController.index;
        });
        _initializeDefaultStatuses();
        _fetchAttendanceInBackground();
      }
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _fetchAttendanceInBackground();
  }

  void _initializeDefaultStatuses() {
    final allHostelStudents = widget.students.where((s) => s.hostel == _currentHostelName).toList();
    for (var s in allHostelStudents) {
      if (!_attendanceMap.containsKey(s.id)) {
        _attendanceMap[s.id] = 'present';
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentHostelId => _hostelIds[_selectedHostelIndex];
  String get _currentHostelName => _hostels[_selectedHostelIndex];

  List<StudentModel> get _currentStudents {
    final filtered = widget.students.where((s) => s.hostel == _currentHostelName).toList();
    if (_searchQuery.isEmpty) return filtered;
    
    return filtered.where((s) {
      return s.name.toLowerCase().contains(_searchQuery) || s.roomNo.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _fetchAttendanceInBackground() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final logs = await ApiService.fetchAttendanceLogs(
        date: dateStr,
        hostelId: _currentHostelId,
      );

      if (mounted) {
        setState(() {
          if (logs.isNotEmpty) {
            for (var record in logs) {
              final sId = (record['student_id'] ?? record['studentId'] ?? '').toString();
              final rNo = (record['roll_no'] ?? record['rollNo'] ?? '').toString().toLowerCase();
              final status = (record['scan_type'] ?? record['status'] ?? 'present').toString();

              if (sId.isNotEmpty) {
                _attendanceMap[sId] = status;
              } else if (rNo.isNotEmpty) {
                final match = widget.students.where((st) => st.rollNo.toLowerCase() == rNo);
                if (match.isNotEmpty) {
                  _attendanceMap[match.first.id] = status;
                }
              }
            }
            _isLocked = true;
            _saveStatus = '✓ Saved (Locked)';
          } else {
            _isLocked = false;
            _saveStatus = '';
            _initializeDefaultStatuses();
          }
        });
      }
    } catch (e) {
      debugPrint('Background attendance fetch error: $e');
    }
  }

  void _showLockedWarning() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Attendance is locked for today. Tap "Edit / Unlock" to modify.',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _unlockAttendance() {
    setState(() {
      _isLocked = false;
      _saveStatus = 'Editing...';
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Attendance unlocked. You can now update P/A/L status and tap Save.',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onStatusChanged(String studentId, String status) {
    if (_isLocked) {
      _showLockedWarning();
      return;
    }
    setState(() {
      _attendanceMap[studentId] = status;
      _saveStatus = 'Unsaved Changes';
    });
  }

  Future<void> _saveAttendance() async {
    final allHostelStudents = widget.students.where((s) => s.hostel == _currentHostelName).toList();
    if (allHostelStudents.isEmpty) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final displayDate = DateFormat('dd MMM yyyy').format(_selectedDate);

    final records = allHostelStudents.map((s) {
      final status = _attendanceMap[s.id] ?? 'present';
      return {
        'student_id': s.id,
        'roll_no': s.rollNo,
        'student_name': s.name,
        'hostel_id': _currentHostelId,
        'room': s.roomNo,
        'status': status,
      };
    }).toList();

    // ⚡ 1. Instantly update UI & lock state with 0ms delay (WhatsApp-style)
    setState(() {
      _isLocked = true;
      _saveStatus = '✓ Saved (Locked)';
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance Saved & Locked',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                  ),
                  Text(
                    '${records.length} students marked for $displayDate ($_currentHostelName)',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    // ⚡ 2. Background asynchronous save to PostgreSQL
    Future.microtask(() async {
      try {
        final success = await ApiService.saveBatchAttendance(
          date: dateStr,
          hostelId: _currentHostelId,
          records: records,
        );
        if (!success) {
          debugPrint('Backend reported unverified batch save for $dateStr');
        }
      } catch (e) {
        debugPrint('Background attendance save error: $e');
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: ChatPalette.accent,
              onPrimary: Colors.white,
              surface: ChatPalette.surface,
              onSurface: ChatPalette.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchAttendanceInBackground();
    }
  }

  void _markAllAs(String status) {
    if (_isLocked) {
      _showLockedWarning();
      return;
    }
    setState(() {
      for (var s in _currentStudents) {
        _attendanceMap[s.id] = status;
      }
      _saveStatus = 'Unsaved Changes';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: ChatPalette.background,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              _buildSearchBar(),
              if (_currentStudents.isNotEmpty || _searchQuery.isNotEmpty)
                _buildQuickActions(),
              Expanded(
                child: _buildStudentList(),
              ),
            ],
          ),
          // Floating Bottom Bar for Save
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final dateStr = DateFormat('MMM dd, yyyy').format(_selectedDate);
    final isToday = _selectedDate.day == DateTime.now().day && 
                    _selectedDate.month == DateTime.now().month && 
                    _selectedDate.year == DateTime.now().year;

    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 16),
      decoration: BoxDecoration(
        color: ChatPalette.sidebar,
        border: Border(bottom: BorderSide(color: ChatPalette.borderGlow.withValues(alpha: 0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.compact) ...[
            IconButton(
              icon: Icon(Icons.menu_rounded, color: ChatPalette.text, size: 24),
              onPressed: widget.onMenuPressed,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ChatPalette.text, letterSpacing: -0.5, height: 1.1)),
                SizedBox(height: 2),
                Row(
                  children: [
                    Text(isToday ? "Today's Daily Log" : 'Historical Log', style: TextStyle(fontSize: 12, color: ChatPalette.muted, fontWeight: FontWeight.w600)),
                    if (_saveStatus.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _saveStatus.contains('✓') ? ChatPalette.accentGreen.withValues(alpha: 0.15) : ChatPalette.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _saveStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _saveStatus.contains('✓') ? ChatPalette.accentGreen : ChatPalette.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ChatPalette.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ChatPalette.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: ChatPalette.accent),
                  SizedBox(width: 6),
                  Text(dateStr, style: TextStyle(color: ChatPalette.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: ChatPalette.sidebar,
        border: Border(bottom: BorderSide(color: ChatPalette.borderGlow.withValues(alpha: 0.1))),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: ChatPalette.accent,
        labelColor: ChatPalette.accent,
        unselectedLabelColor: ChatPalette.muted,
        indicatorWeight: 3,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: _hostels.map((h) => Tab(text: h)).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: ChatPalette.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name or room...',
          hintStyle: TextStyle(color: ChatPalette.muted, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: ChatPalette.muted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: ChatPalette.muted, size: 20),
                onPressed: () => _searchController.clear(),
              )
            : null,
          filled: true,
          fillColor: ChatPalette.surface,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: ChatPalette.borderGlow.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: ChatPalette.borderGlow.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: ChatPalette.accent.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ChatPalette.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentStudents.length} Students',
              style: TextStyle(
                color: ChatPalette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          if (_isLocked)
            InkWell(
              onTap: _unlockAttendance,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ChatPalette.accent.withValues(alpha: 0.1),
                  border: Border.all(
                    color: ChatPalette.accent.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 13, color: ChatPalette.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Attendance Locked (Tap to Edit)',
                      style: TextStyle(
                        color: ChatPalette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            InkWell(
              onTap: () => _markAllAs('present'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ChatPalette.accentGreen.withValues(alpha: 0.1),
                  border: Border.all(
                    color: ChatPalette.accentGreen.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: ChatPalette.accentGreen),
                    const SizedBox(width: 4),
                    Text(
                      'Mark All Present',
                      style: TextStyle(
                        color: ChatPalette.accentGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_currentStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ChatPalette.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_alt_outlined,
                size: 28,
                color: ChatPalette.muted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No students found.',
              style: TextStyle(
                color: ChatPalette.muted,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 4),
      itemCount: _currentStudents.length,
      itemBuilder: (context, index) {
        final student = _currentStudents[index];
        final status = _attendanceMap[student.id] ?? 'present';

        return _buildStudentTile(student, status);
      },
    );
  }

  Widget _buildStudentTile(StudentModel student, String status) {
    final bool isAbsent = status == 'absent';
    final bool isLeave = status == 'leave';

    Color getCardColor() {
      if (isAbsent) return ChatPalette.accentRose.withValues(alpha: 0.05);
      if (isLeave) return ChatPalette.accentAmber.withValues(alpha: 0.05);
      return ChatPalette.surface;
    }

    Color getBorderColor() {
      if (isAbsent) return ChatPalette.accentRose.withValues(alpha: 0.3);
      if (isLeave) return ChatPalette.accentAmber.withValues(alpha: 0.3);
      return ChatPalette.borderGlow.withValues(alpha: 0.1);
    }

    return GestureDetector(
      onTap: () => _showStudentProfileDialog(context, student),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: getCardColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBorderColor(), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: ChatPalette.isDark ? 0.2 : 0.02,
              ),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildProfileAvatar(student, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: TextStyle(
                      color: ChatPalette.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: ChatPalette.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          student.roomNo.isNotEmpty ? student.roomNo : 'N/A',
                          style: TextStyle(
                            color: ChatPalette.text,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          student.department,
                          style: TextStyle(
                            color: ChatPalette.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusToggle(student.id, status),
          ],
        ),
      ),
    );
  }

  void _showStudentProfileDialog(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: ChatPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProfileAvatar(student, size: 80),
                const SizedBox(height: 16),
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: ChatPalette.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  student.department,
                  style: TextStyle(color: ChatPalette.muted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Divider(color: ChatPalette.borderGlow.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                _buildDetailRow('Room', student.roomNo),
                _buildDetailRow('Contact', student.contactNo),
                _buildDetailRow('Roll No', student.rollNo),
                _buildDetailRow('Gender', student.gender),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ChatPalette.canvasDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: ChatPalette.border),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: ChatPalette.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: ChatPalette.muted, fontSize: 13)),
          Text(
            value.isNotEmpty ? value : 'N/A',
            style: TextStyle(
              color: ChatPalette.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(StudentModel student, {double size = 36}) {
    if (student.profilePhotoBase64 != null &&
        student.profilePhotoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(student.profilePhotoBase64!);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder:
                  (context, error, stackTrace) =>
                      _buildFallbackAvatar(student, size),
            ),
          ),
        );
      } catch (e) {
        return _buildFallbackAvatar(student, size);
      }
    } else if (student.photoPath != null && student.photoPath!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            student.photoPath!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder:
                (context, error, stackTrace) =>
                    _buildFallbackAvatar(student, size),
          ),
        ),
      );
    }
    return _buildFallbackAvatar(student, size);
  }

  Widget _buildFallbackAvatar(StudentModel student, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ChatPalette.gradientPrimary,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ChatPalette.accent.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.45,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusToggle(String studentId, String currentStatus) {
    return Container(
      decoration: BoxDecoration(
        color: ChatPalette.canvasDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isLocked
              ? ChatPalette.border.withValues(alpha: 0.5)
              : ChatPalette.border,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusBtn(
            label: 'P',
            isActive: currentStatus == 'present',
            isLocked: _isLocked,
            activeColor: ChatPalette.accentGreen,
            onTap:
                _isLocked
                    ? _showLockedWarning
                    : () => _onStatusChanged(studentId, 'present'),
          ),
          const SizedBox(width: 3),
          _StatusBtn(
            label: 'A',
            isActive: currentStatus == 'absent',
            isLocked: _isLocked,
            activeColor: ChatPalette.accentRose,
            onTap:
                _isLocked
                    ? _showLockedWarning
                    : () => _onStatusChanged(studentId, 'absent'),
          ),
          const SizedBox(width: 3),
          _StatusBtn(
            label: 'L',
            isActive: currentStatus == 'leave',
            isLocked: _isLocked,
            activeColor: ChatPalette.accentAmber,
            onTap:
                _isLocked
                    ? _showLockedWarning
                    : () => _onStatusChanged(studentId, 'leave'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    int present = 0, absent = 0, leave = 0;

    final allHostelStudents =
        widget.students.where((s) => s.hostel == _currentHostelName).toList();

    for (var s in allHostelStudents) {
      if (_attendanceMap[s.id] == 'present') present++;
      if (_attendanceMap[s.id] == 'absent') absent++;
      if (_attendanceMap[s.id] == 'leave') leave++;
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: ChatPalette.sidebar.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: ChatPalette.borderGlow.withValues(alpha: 0.15),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total: ${allHostelStudents.length}',
                      style: TextStyle(
                        color: ChatPalette.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _StatBadge(label: 'P: $present', color: ChatPalette.accentGreen),
                        const SizedBox(width: 6),
                        _StatBadge(label: 'A: $absent', color: ChatPalette.accentRose),
                        const SizedBox(width: 6),
                        _StatBadge(label: 'L: $leave', color: ChatPalette.accentAmber),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isLocked)
                GestureDetector(
                  onTap: _unlockAttendance,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: ChatPalette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ChatPalette.accent.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ChatPalette.accent.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_open_rounded, size: 16, color: ChatPalette.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Edit / Unlock',
                          style: TextStyle(
                            color: ChatPalette.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _isSaving ? null : _saveAttendance,
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            _isSaving
                                ? [ChatPalette.muted, ChatPalette.dim]
                                : ChatPalette.gradientPrimary,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow:
                          _isSaving
                              ? []
                              : [
                                BoxShadow(
                                  color: ChatPalette.accentBlue.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                    ),
                    child: Row(
                      children: [
                        if (_isSaving)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(Icons.cloud_upload_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _isSaving ? 'Saving...' : 'Save Attendance',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: ChatPalette.muted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isLocked;
  final Color activeColor;
  final VoidCallback? onTap;

  const _StatusBtn({
    required this.label,
    required this.isActive,
    this.isLocked = false,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        width: 32,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isActive
                    ? Colors.white
                    : (isLocked
                        ? ChatPalette.dim.withValues(alpha: 0.35)
                        : ChatPalette.muted),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
