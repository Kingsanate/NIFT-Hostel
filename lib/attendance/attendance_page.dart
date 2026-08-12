import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../chat/chat_palette.dart';
import '../scanner/models/student_model.dart';
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

class _AttendancePageState extends State<AttendancePage> with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  int _selectedHostelIndex = 0;
  
  final List<String> _hostels = ['Boys Hostel', 'Umsawli Girls', 'Nongthymmai Girls'];
  final List<String> _hostelIds = ['boys', 'girls1', 'girls2'];

  // Map of Student ID -> Status ('present', 'absent', 'leave')
  Map<String, String> _attendanceMap = {};
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLocked = false;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _tabController = TabController(length: _hostels.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedHostelIndex) {
        setState(() {
          _selectedHostelIndex = _tabController.index;
        });
        _fetchAttendance();
      }
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _fetchAttendance();
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

  Future<void> _fetchAttendance() async {
    setState(() {
      _isLoading = true;
      _attendanceMap.clear();
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final res = await Supabase.instance.client
          .from('attendance_records')
          .select('student_id, status')
          .eq('hostel_id', _currentHostelId)
          .eq('date', dateStr);

      final newMap = <String, String>{};
      
      // We need to initialize for all students in this hostel, not just filtered ones
      final allHostelStudents = widget.students.where((s) => s.hostel == _currentHostelName).toList();

      if (res.isNotEmpty) {
        for (var record in res) {
          newMap[record['student_id'].toString()] = record['status'].toString();
        }
        if (mounted) {
          setState(() {
            _isLocked = true; // Data exists, lock the UI
          });
        }
      } else {
        // Defaults to 'present' if completely unmarked for the day
        for (var student in allHostelStudents) {
          newMap[student.id] = 'present';
        }
        if (mounted) {
          setState(() {
            _isLocked = false; // Fresh day, allow editing
          });
        }
      }

      if (mounted) {
        setState(() {
          _attendanceMap = newMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load attendance')),
        );
      }
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      final records = _attendanceMap.entries.map((e) => {
        'date': dateStr,
        'hostel_id': _currentHostelId,
        'student_id': e.key,
        'status': e.value,
      }).toList();

      if (records.isNotEmpty) {
        await Supabase.instance.client
            .from('attendance_records')
            .upsert(records, onConflict: 'date,student_id');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, color: ChatPalette.accentGreen, size: 22),
              SizedBox(width: 12),
              Text('Successfully saved attendance!', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            backgroundColor: ChatPalette.canvas,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _isLocked = true;
        });
      }
    } catch (e) {
      debugPrint('Error saving attendance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save attendance: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
      _fetchAttendance();
    }
  }

  void _markAllAs(String status) {
    setState(() {
      for (var s in _currentStudents) {
        _attendanceMap[s.id] = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                child: _isLoading 
                    ? Center(child: CircularProgressIndicator(color: ChatPalette.accent))
                    : _buildStudentList(),
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
                Text('Attendance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ChatPalette.text, letterSpacing: -0.5, height: 1.1)),
                SizedBox(height: 2),
                Text(isToday ? 'Today\'s Daily Log' : 'Historical Log', style: TextStyle(fontSize: 12, color: ChatPalette.muted, fontWeight: FontWeight.w600)),
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
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ChatPalette.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_currentStudents.length} Students', style: TextStyle(color: ChatPalette.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          Spacer(),
          if (!_isLocked)
            InkWell(
              onTap: () => _markAllAs('present'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ChatPalette.accentGreen.withValues(alpha: 0.1),
                border: Border.all(color: ChatPalette.accentGreen.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: ChatPalette.accentGreen),
                  SizedBox(width: 4),
                  Text('Mark All Present', style: TextStyle(color: ChatPalette.accentGreen, fontSize: 11, fontWeight: FontWeight.bold)),
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
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ChatPalette.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_alt_outlined, size: 36, color: ChatPalette.muted.withValues(alpha: 0.5)),
            ),
            SizedBox(height: 12),
            Text('No students found.', style: TextStyle(color: ChatPalette.muted, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 120, top: 4), // Extra padding for the floating bottom bar
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
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.all(12), // Reduced padding
        decoration: BoxDecoration(
          color: getCardColor(),
          borderRadius: BorderRadius.circular(12), // Reduced border radius
          border: Border.all(color: getBorderColor(), width: 1.2), // Thinner border
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: ChatPalette.isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            _buildProfileAvatar(student, size: 36),
            SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: TextStyle(color: ChatPalette.text, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Tighter padding
                      decoration: BoxDecoration(
                        color: ChatPalette.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(student.roomNo.isNotEmpty ? student.roomNo : 'N/A', style: TextStyle(color: ChatPalette.text, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        student.department, 
                        style: TextStyle(color: ChatPalette.muted, fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8), // Tighter spacing
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
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProfileAvatar(student, size: 80),
                SizedBox(height: 16),
                Text(student.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ChatPalette.text), textAlign: TextAlign.center),
                SizedBox(height: 4),
                Text(student.department, style: TextStyle(color: ChatPalette.muted, fontSize: 14), textAlign: TextAlign.center),
                SizedBox(height: 16),
                Divider(color: ChatPalette.borderGlow.withValues(alpha: 0.1)),
                SizedBox(height: 16),
                _buildDetailRow('Room', student.roomNo),
                _buildDetailRow('Contact', student.contactNo),
                _buildDetailRow('Roll No', student.rollNo),
                _buildDetailRow('Gender', student.gender),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ChatPalette.canvasDeep,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: ChatPalette.border)),
                    ),
                    child: Text('Close', style: TextStyle(color: ChatPalette.text, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: ChatPalette.muted, fontSize: 13)),
          Text(value.isNotEmpty ? value : 'N/A', style: TextStyle(color: ChatPalette.text, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(StudentModel student, {double size = 36}) {
    if (student.profilePhotoBase64 != null && student.profilePhotoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(student.profilePhotoBase64!);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(student, size),
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
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: ClipOval(
          child: Image.network(
            student.photoPath!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(student, size),
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
          BoxShadow(color: ChatPalette.accent.withValues(alpha: 0.3), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Center(
        child: Text(
          student.name.isNotEmpty ? student.name[0].toUpperCase() : '?', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.45)
        ),
      ),
    );
  }

  Widget _buildStatusToggle(String studentId, String currentStatus) {
    return Opacity(
      opacity: _isLocked ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: _isLocked ? ChatPalette.background : ChatPalette.canvasDeep,
          borderRadius: BorderRadius.circular(10), // Reduced
          border: Border.all(color: ChatPalette.border),
        ),
        padding: EdgeInsets.all(3), // Tighter padding
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusBtn(
            label: 'P',
            isActive: currentStatus == 'present',
            activeColor: _isLocked ? ChatPalette.muted : ChatPalette.accentGreen,
            onTap: _isLocked ? null : () => setState(() => _attendanceMap[studentId] = 'present'),
          ),
          SizedBox(width: 3),
          _StatusBtn(
            label: 'A',
            isActive: currentStatus == 'absent',
            activeColor: _isLocked ? ChatPalette.muted : ChatPalette.accentRose,
            onTap: _isLocked ? null : () => setState(() => _attendanceMap[studentId] = 'absent'),
          ),
          SizedBox(width: 3),
          _StatusBtn(
            label: 'L',
            isActive: currentStatus == 'leave',
            activeColor: _isLocked ? ChatPalette.muted : ChatPalette.accentAmber,
            onTap: _isLocked ? null : () => setState(() => _attendanceMap[studentId] = 'leave'),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBottomBar() {
    int present = 0, absent = 0, leave = 0;
    
    // Calculate total for the ENTIRE hostel regardless of search filter
    final allHostelStudents = widget.students.where((s) => s.hostel == _currentHostelName).toList();

    for (var s in allHostelStudents) {
      if (_attendanceMap[s.id] == 'present') present++;
      if (_attendanceMap[s.id] == 'absent') absent++;
      if (_attendanceMap[s.id] == 'leave') leave++;
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12), // Reduced padding
          decoration: BoxDecoration(
            color: ChatPalette.sidebar.withValues(alpha: 0.85),
            border: Border(top: BorderSide(color: ChatPalette.borderGlow.withValues(alpha: 0.15))),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: Offset(0, -3))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total: ${allHostelStudents.length}', style: TextStyle(color: ChatPalette.text, fontSize: 14, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        _StatBadge(label: 'P: $present', color: ChatPalette.accentGreen),
                        SizedBox(width: 6),
                        _StatBadge(label: 'A: $absent', color: ChatPalette.accentRose),
                        SizedBox(width: 6),
                        _StatBadge(label: 'L: $leave', color: ChatPalette.accentAmber),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _isLoading || _isSaving 
                    ? null 
                    : (_isLocked 
                        ? () => setState(() => _isLocked = false) 
                        : _saveAttendance),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isSaving 
                          ? [ChatPalette.muted, ChatPalette.dim]
                          : _isLocked
                              ? [ChatPalette.accent, ChatPalette.accent.withValues(alpha: 0.8)]
                              : ChatPalette.gradientPrimary,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isSaving ? [] : [
                      BoxShadow(
                        color: (_isLocked ? ChatPalette.accent : ChatPalette.accentBlue).withValues(alpha: 0.4), 
                        blurRadius: 10, 
                        offset: Offset(0, 3)
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_isSaving)
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        Icon(_isLocked ? Icons.edit_rounded : Icons.cloud_upload_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        _isSaving ? 'Saving...' : (_isLocked ? 'Edit' : 'Save'), 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)
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
        Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 3),
        Text(label, style: TextStyle(color: ChatPalette.muted, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  const _StatusBtn({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        width: 32, // Reduced size
        height: 28, // Reduced size
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6), // Reduced
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : ChatPalette.muted,
            fontWeight: FontWeight.w900,
            fontSize: 12, // Reduced font size
          ),
        ),
      ),
    );
  }
}
