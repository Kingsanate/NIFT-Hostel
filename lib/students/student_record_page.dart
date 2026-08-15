import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img_lib;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../chat/chat_palette.dart';
import '../scanner/models/student_model.dart';
import '../services/api_service.dart';
import '../services/student_record_cache.dart';
import 'models/medical_treatment_model.dart';

class StudentRecordPage extends StatefulWidget {
  final StudentModel student;
  final Function(StudentModel updatedStudent)? onUpdateStudent;

  const StudentRecordPage({
    super.key,
    required this.student,
    this.onUpdateStudent,
  });

  @override
  State<StudentRecordPage> createState() => _StudentRecordPageState();
}

class _StudentRecordPageState extends State<StudentRecordPage>
    with SingleTickerProviderStateMixin {
  late StudentModel _student;
  late TabController _tabController;

  List<Map<String, dynamic>> _leaveRecords = [];
  List<Map<String, dynamic>> _lateRecords = [];
  List<MedicalTreatmentRecord> _treatmentRecords = [];

  Uint8List? _cachedPhotoBytes;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
    _tabController = TabController(length: 4, vsync: this);
    _decodePhoto();

    // ⚡ WhatsApp-style 0ms Instant Cache Loading:
    final cachedLeaves = StudentRecordCache.getLeaves(_student.rollNo);
    final cachedLate = StudentRecordCache.getLateEntries(_student.rollNo);
    final cachedTreatments = StudentRecordCache.getTreatments(_student.rollNo);

    _leaveRecords = cachedLeaves ?? [];
    _lateRecords = cachedLate ?? [];
    _treatmentRecords = cachedTreatments ?? [];

    // Silent background sync with Oracle backend (stale-while-revalidate)
    _fetchStudentRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _decodePhoto() {
    try {
      if (_student.profilePhotoBase64 != null &&
          _student.profilePhotoBase64!.isNotEmpty) {
        _cachedPhotoBytes =
            base64Decode(_student.profilePhotoBase64!.split(',').last);
      } else {
        _cachedPhotoBytes = null;
      }
    } catch (_) {
      _cachedPhotoBytes = null;
    }
  }

  Future<void> _fetchStudentRecords() async {
    _fetchLeaves();
    _fetchLateEntries();
    _fetchTreatments();
  }

  Future<void> _fetchLeaves() async {
    try {
      final list =
          await ApiService.fetchLeaveApprovals(rollNo: _student.rollNo);
      StudentRecordCache.setLeaves(_student.rollNo, list);
      if (mounted) {
        setState(() {
          _leaveRecords = list;
        });
      }
    } catch (e) {
      debugPrint('Silent leave sync notice: $e');
    }
  }

  Future<void> _fetchLateEntries() async {
    try {
      final list = await ApiService.fetchLateEntries(rollNo: _student.rollNo);
      StudentRecordCache.setLateEntries(_student.rollNo, list);
      if (mounted) {
        setState(() {
          _lateRecords = list;
        });
      }
    } catch (e) {
      debugPrint('Silent late entry sync notice: $e');
    }
  }

  Future<void> _fetchTreatments() async {
    try {
      final list = await ApiService.fetchMedicalTreatments(
        rollNo: _student.rollNo,
        studentId: _student.id,
      );
      final parsed =
          list.map((m) => MedicalTreatmentRecord.fromJson(m)).toList();
      StudentRecordCache.setTreatments(_student.rollNo, parsed);
      if (mounted) {
        setState(() {
          _treatmentRecords = parsed;
        });
      }
    } catch (e) {
      debugPrint('Silent medical sync notice: $e');
    }
  }

  void _shareStudentRecord() {
    final s = _student;
    final text = '''
📋 NIFT HOSTEL - STUDENT RECORD
======================================
Name: ${s.name}
Roll Number: ${s.rollNo}
Hostel: ${s.hostel} | Room: ${s.roomNo}
Department: ${s.department} (${s.semester})
Date of Birth: ${s.dateOfBirth}
Gender: ${s.gender}
Phone: ${s.contactNo}
Email: ${s.emailId}
Joining Date: ${s.joiningDate?.isNotEmpty == true ? s.joiningDate! : 'Not specified'}
Exit Date: ${s.exitDate?.isNotEmpty == true ? s.exitDate! : 'Active Resident'}
Blood Group: ${s.bloodGroup?.isNotEmpty == true ? s.bloodGroup! : 'N/A'}
Emergency Contact: ${s.emergencyContact?.isNotEmpty == true ? s.emergencyContact! : 'N/A'}
Guardian: ${s.guardianName?.isNotEmpty == true ? s.guardianName! : 'N/A'} (${s.guardianPhone?.isNotEmpty == true ? s.guardianPhone! : 'N/A'})

SUMMARY METRICS:
- Approved Leaves: ${_leaveRecords.length}
- Late Entries: ${_lateRecords.length}
- Hospital/Medical Treatments: ${_treatmentRecords.length}
======================================
''';
    // ignore: deprecated_member_use
    Share.share(text, subject: 'Student Record: ${s.name} (${s.rollNo})');
  }

  // ── REDESIGNED FULL-FEATURED THEME-MATCHED EDIT MODAL ───────────────────────
  void _openEditStudentModal() async {
    final nameCtrl = TextEditingController(text: _student.name);
    final rollCtrl = TextEditingController(text: _student.rollNo);
    final deptCtrl = TextEditingController(text: _student.department);
    final semCtrl = TextEditingController(text: _student.semester);
    final roomCtrl = TextEditingController(text: _student.roomNo);
    final phoneCtrl = TextEditingController(text: _student.contactNo);
    final emailCtrl = TextEditingController(text: _student.emailId);
    final dobCtrl = TextEditingController(text: _student.dateOfBirth);
    final joiningCtrl = TextEditingController(text: _student.joiningDate ?? '');
    final exitCtrl = TextEditingController(text: _student.exitDate ?? '');
    final emergencyCtrl =
        TextEditingController(text: _student.emergencyContact ?? '');
    final guardianNameCtrl =
        TextEditingController(text: _student.guardianName ?? '');
    final guardianPhoneCtrl =
        TextEditingController(text: _student.guardianPhone ?? '');
    final addressCtrl = TextEditingController(text: _student.address ?? '');
    final notesCtrl = TextEditingController(text: _student.notes ?? '');

    String selectedHostel = _student.hostel;
    String selectedGender = _student.gender.isNotEmpty ? _student.gender : 'Male';
    String selectedBloodGroup = _student.bloodGroup ?? '';

    final bloodGroupOptions = [
      '',
      'A+',
      'A-',
      'B+',
      'B-',
      'O+',
      'O-',
      'AB+',
      'AB-'
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.92,
            decoration: BoxDecoration(
              color: ChatPalette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: ChatPalette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Modal Handle
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: ChatPalette.dim.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Top Header Row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: ChatPalette.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.edit_note_rounded,
                            color: ChatPalette.accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Student Record',
                              style: TextStyle(
                                color: ChatPalette.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Update stay tenure, room & profile details',
                              style: TextStyle(
                                  color: ChatPalette.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: Icon(Icons.close_rounded,
                            color: ChatPalette.muted, size: 22),
                      ),
                    ],
                  ),
                ),
                Divider(color: ChatPalette.border, height: 1),

                // Scrollable Form Sections
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      // ── SECTION 1: HOSTEL RECORD ───────────────────────
                      _buildSectionHeader(
                        icon: Icons.domain_rounded,
                        title: 'HOSTEL RECORD',
                        color: ChatPalette.accent,
                      ),
                      const SizedBox(height: 12),

                      // Joining & Exit Dates with Pickers
                      Row(
                        children: [
                          Expanded(
                            child: _buildInteractiveDateField(
                              label: 'Hostel Joining Date',
                              controller: joiningCtrl,
                              icon: Icons.login_rounded,
                              accentColor: ChatPalette.accentGreen,
                              onPick: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.tryParse(joiningCtrl.text) ?? now,
                                  firstDate: DateTime(2018),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    joiningCtrl.text =
                                        DateFormat('dd MMM yyyy').format(picked);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInteractiveDateField(
                              label: 'Hostel Exit Date',
                              controller: exitCtrl,
                              icon: Icons.logout_rounded,
                              accentColor: ChatPalette.accentAmber,
                              onPick: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.tryParse(exitCtrl.text) ?? now.add(const Duration(days: 365)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    exitCtrl.text =
                                        DateFormat('dd MMM yyyy').format(picked);
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Hostel Selection & Room No
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildDropdownField<String>(
                              label: 'Assigned Hostel',
                              icon: Icons.apartment_rounded,
                              value: selectedHostel,
                              items: const [
                                DropdownMenuItem(
                                    value: 'Boys Hostel',
                                    child: Text('Boys Hostel')),
                                DropdownMenuItem(
                                    value: 'Umsawli Girls',
                                    child: Text('Umsawli Girls')),
                                DropdownMenuItem(
                                    value: 'Nongthymmai Girls',
                                    child: Text('Nongthymmai Girls')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setModalState(() => selectedHostel = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildInputField(
                              label: 'Room No.',
                              controller: roomCtrl,
                              icon: Icons.meeting_room_outlined,
                              hint: 'e.g. BH-4',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── SECTION 2: ACADEMIC & IDENTIFICATION ─────────────────
                      _buildSectionHeader(
                        icon: Icons.school_rounded,
                        title: 'ACADEMIC & IDENTITY',
                        color: ChatPalette.accentBlue,
                      ),
                      const SizedBox(height: 12),

                      _buildInputField(
                        label: 'Full Name',
                        controller: nameCtrl,
                        icon: Icons.person_rounded,
                        hint: 'Student full name',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              label: 'Roll Number',
                              controller: rollCtrl,
                              icon: Icons.badge_outlined,
                              hint: 'e.g. BD-26-1841',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              label: 'Semester / Year',
                              controller: semCtrl,
                              icon: Icons.timeline_rounded,
                              hint: 'e.g. Sem 1 (1st Year)',
                            ),
                          ),
                        ],
                      ),
                      _buildInputField(
                        label: 'Department / Course',
                        controller: deptCtrl,
                        icon: Icons.menu_book_rounded,
                        hint: 'e.g. Fashion Design (B. Des)',
                      ),

                      const SizedBox(height: 24),

                      // ── SECTION 3: PERSONAL & MEDICAL ────────────────────────
                      _buildSectionHeader(
                        icon: Icons.medical_information_outlined,
                        title: 'PERSONAL & HEALTH',
                        color: ChatPalette.accentRose,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              label: 'Date of Birth',
                              controller: dobCtrl,
                              icon: Icons.cake_outlined,
                              hint: 'YYYY-MM-DD',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdownField<String>(
                              label: 'Gender',
                              icon: Icons.wc_rounded,
                              value: selectedGender,
                              items: const [
                                DropdownMenuItem(
                                    value: 'Male', child: Text('Male')),
                                DropdownMenuItem(
                                    value: 'Female', child: Text('Female')),
                                DropdownMenuItem(
                                    value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setModalState(() => selectedGender = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField<String>(
                              label: 'Blood Group',
                              icon: Icons.water_drop_outlined,
                              value: selectedBloodGroup,
                              items: bloodGroupOptions.map((bg) {
                                return DropdownMenuItem(
                                  value: bg,
                                  child: Text(bg.isEmpty ? 'Not specified' : bg),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setModalState(() => selectedBloodGroup = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              label: 'Student Contact Phone',
                              controller: phoneCtrl,
                              icon: Icons.phone_android_rounded,
                              hint: '+91 98765 43210',
                            ),
                          ),
                        ],
                      ),

                      _buildInputField(
                        label: 'Email Address',
                        controller: emailCtrl,
                        icon: Icons.alternate_email_rounded,
                        hint: 'student@nift.ac.in',
                      ),

                      const SizedBox(height: 24),

                      // ── SECTION 4: EMERGENCY & GUARDIAN ──────────────────────
                      _buildSectionHeader(
                        icon: Icons.family_restroom_rounded,
                        title: 'GUARDIAN & EMERGENCY CONTACT',
                        color: ChatPalette.accentAmber,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              label: 'Emergency Phone',
                              controller: emergencyCtrl,
                              icon: Icons.phone_in_talk_rounded,
                              hint: 'Immediate emergency contact',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              label: 'Guardian Phone',
                              controller: guardianPhoneCtrl,
                              icon: Icons.phone_outlined,
                              hint: "Parent's contact",
                            ),
                          ),
                        ],
                      ),

                      _buildInputField(
                        label: 'Guardian / Parent Name',
                        controller: guardianNameCtrl,
                        icon: Icons.person_outline_rounded,
                        hint: "Parent or local guardian's name",
                      ),

                      _buildInputField(
                        label: 'Permanent Address',
                        controller: addressCtrl,
                        icon: Icons.home_outlined,
                        hint: 'City, State, PIN Code',
                      ),

                      _buildInputField(
                        label: 'Special Remarks / Allergies',
                        controller: notesCtrl,
                        icon: Icons.notes_rounded,
                        hint: 'Medical allergies, dietary remarks, etc.',
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                // Save Action Footer
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ChatPalette.surface,
                    border: Border(top: BorderSide(color: ChatPalette.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            backgroundColor: ChatPalette.background,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: ChatPalette.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final updated = _student.copyWith(
                              name: nameCtrl.text.trim(),
                              rollNo: rollCtrl.text.trim(),
                              department: deptCtrl.text.trim(),
                              semester: semCtrl.text.trim(),
                              roomNo: roomCtrl.text.trim(),
                              hostel: selectedHostel,
                              gender: selectedGender,
                              contactNo: phoneCtrl.text.trim(),
                              emailId: emailCtrl.text.trim(),
                              dateOfBirth: dobCtrl.text.trim(),
                              joiningDate: joiningCtrl.text.trim(),
                              exitDate: exitCtrl.text.trim(),
                              bloodGroup: selectedBloodGroup.trim(),
                              emergencyContact: emergencyCtrl.text.trim(),
                              guardianName: guardianNameCtrl.text.trim(),
                              guardianPhone: guardianPhoneCtrl.text.trim(),
                              address: addressCtrl.text.trim(),
                              notes: notesCtrl.text.trim(),
                            );

                            Navigator.pop(sheetCtx);

                            setState(() => _student = updated);
                            if (widget.onUpdateStudent != null) {
                              widget.onUpdateStudent!(updated);
                            }

                            // Instant professional pop-up notification
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
                                      child: const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Changes Saved',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                fontSize: 13),
                                          ),
                                          Text(
                                            'Student record updated successfully',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                                margin:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            );

                            // Background Backend Sync
                            Future.microtask(() async {
                              try {
                                await ApiService.updateStudent(
                                    updated.id, updated.toBackend());
                              } catch (e) {
                                debugPrint('Failed to save student: $e');
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ChatPalette.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Save Changes',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveDateField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: ChatPalette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: ChatPalette.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ChatPalette.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.text.isNotEmpty
                        ? controller.text
                        : 'Select date…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: controller.text.isNotEmpty
                          ? ChatPalette.text
                          : ChatPalette.dim,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_rounded,
                    color: ChatPalette.dim, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: ChatPalette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(color: ChatPalette.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: ChatPalette.dim, fontSize: 12),
              prefixIcon: Icon(icon, color: ChatPalette.accent, size: 17),
              filled: true,
              fillColor: ChatPalette.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ChatPalette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ChatPalette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ChatPalette.accent),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: ChatPalette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ChatPalette.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ChatPalette.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: ChatPalette.surface,
                icon: Icon(Icons.arrow_drop_down_rounded,
                    color: ChatPalette.muted),
                style: TextStyle(color: ChatPalette.text, fontSize: 13),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── DOCUMENT SCANNER & CAMERA CAPTURE ──────────────────────────────────────────
  Future<Uint8List?> _pickPrescriptionDocument({required bool useCamera}) async {
    try {
      if (!kIsWeb && Platform.isAndroid && useCamera) {
        final options = DocumentScannerOptions(
          mode: ScannerMode.full,
          pageLimit: 1,
          isGalleryImport: false,
        );
        final scanner = DocumentScanner(options: options);
        final result = await scanner.scanDocument();
        final pages = result.images;
        if (pages.isEmpty) return null;
        final file = File(pages.first);
        final bytes = await file.readAsBytes();
        return _compressImage(bytes);
      }

      final source = useCamera
          ? (kIsWeb ? ImageSource.gallery : ImageSource.camera)
          : ImageSource.gallery;
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return _compressImage(bytes);
    } catch (e) {
      debugPrint('Prescription pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open scanner: $e. Try gallery instead.'),
            backgroundColor: ChatPalette.accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  Uint8List _compressImage(Uint8List bytes, {int targetKB = 900}) {
    if (bytes.length <= targetKB * 1024) return bytes;
    try {
      final decoded = img_lib.decodeImage(bytes);
      if (decoded == null) return bytes;
      int quality = 85;
      Uint8List compressed =
          Uint8List.fromList(img_lib.encodeJpg(decoded, quality: quality));
      while (compressed.length > targetKB * 1024 && quality > 30) {
        quality -= 15;
        compressed =
            Uint8List.fromList(img_lib.encodeJpg(decoded, quality: quality));
      }
      return compressed;
    } catch (_) {
      return bytes;
    }
  }

  void _openAddMedicalTreatmentModal() async {
    DateTime selectedDate = DateTime.now();
    DateTime? selectedFollowUp;
    Uint8List? scannedPrescriptionBytes;

    final hospitalCtrl = TextEditingController();
    final doctorCtrl = TextEditingController();
    final diagnosisCtrl = TextEditingController();
    final medicinesCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final costCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: ChatPalette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: ChatPalette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: ChatPalette.dim.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ChatPalette.accentBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.local_hospital_rounded,
                            color: ChatPalette.accentBlue, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Medical & Hospital Record',
                              style: TextStyle(
                                color: ChatPalette.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Record treatment & attach scanned prescription for ${_student.name}',
                              style: TextStyle(
                                  color: ChatPalette.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: Icon(Icons.close_rounded,
                            color: ChatPalette.muted, size: 22),
                      ),
                    ],
                  ),
                ),
                Divider(color: ChatPalette.border, height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'PRESCRIPTION / MEDICAL BILL SCAN',
                        style: TextStyle(
                          color: ChatPalette.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (scannedPrescriptionBytes == null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final bytes = await _pickPrescriptionDocument(
                                      useCamera: true);
                                  if (bytes != null) {
                                    setModalState(() =>
                                        scannedPrescriptionBytes = bytes);
                                  }
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    color: ChatPalette.accentBlue
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: ChatPalette.accentBlue
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.document_scanner_rounded,
                                          color: ChatPalette.accentBlue,
                                          size: 32),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Scan Document',
                                        style: TextStyle(
                                          color: ChatPalette.accentBlue,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Auto-perspective & enhance',
                                        style: TextStyle(
                                            color: ChatPalette.muted,
                                            fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final bytes = await _pickPrescriptionDocument(
                                      useCamera: false);
                                  if (bytes != null) {
                                    setModalState(() =>
                                        scannedPrescriptionBytes = bytes);
                                  }
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    color: ChatPalette.background,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: ChatPalette.border),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.photo_library_outlined,
                                          color: ChatPalette.accentGreen,
                                          size: 32),
                                      const SizedBox(height: 8),
                                      Text(
                                        'From Gallery',
                                        style: TextStyle(
                                          color: ChatPalette.text,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Upload photo or image',
                                        style: TextStyle(
                                            color: ChatPalette.muted,
                                            fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ChatPalette.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: ChatPalette.accentGreen
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  scannedPrescriptionBytes!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded,
                                            color: ChatPalette.accentGreen,
                                            size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Prescription Attached',
                                          style: TextStyle(
                                              color: ChatPalette.text,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${(scannedPrescriptionBytes!.length / 1024).toStringAsFixed(0)} KB • Ready to save',
                                      style: TextStyle(
                                          color: ChatPalette.muted,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => setModalState(
                                    () => scannedPrescriptionBytes = null),
                                tooltip: 'Remove / Re-scan',
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: ChatPalette.accentRose, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Text(
                        'TREATMENT DETAILS',
                        style: TextStyle(
                          color: ChatPalette.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: ChatPalette.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ChatPalette.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  color: ChatPalette.accentBlue, size: 18),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Treatment / Visit Date',
                                      style: TextStyle(
                                          color: ChatPalette.muted,
                                          fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd MMM yyyy (EEEE)')
                                        .format(selectedDate),
                                    style: TextStyle(
                                        color: ChatPalette.text,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Icon(Icons.edit_calendar_rounded,
                                  color: ChatPalette.dim, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildInputField(
                        label: 'Hospital / Clinic Name',
                        controller: hospitalCtrl,
                        icon: Icons.local_hospital_outlined,
                        hint:
                            'e.g. NEIGRIHMS, Woodland Hospital, Campus Clinic',
                      ),
                      _buildInputField(
                        label: 'Attending Doctor / Specialist',
                        controller: doctorCtrl,
                        icon: Icons.person_outline_rounded,
                        hint: 'e.g. Dr. P. Sangma, Dr. K. Sharma',
                      ),
                      _buildInputField(
                        label: 'Diagnosis / Symptoms',
                        controller: diagnosisCtrl,
                        icon: Icons.healing_rounded,
                        hint:
                            'e.g. High Fever & Viral Infection, Food Poisoning, Sprain',
                      ),
                      _buildInputField(
                        label: 'Prescribed Medicines & Instructions',
                        controller: medicinesCtrl,
                        icon: Icons.medication_outlined,
                        hint:
                            'e.g. Paracetamol 650mg TDS x 3 days, Antibiotics, 3 days bed rest',
                        maxLines: 3,
                      ),
                      _buildInputField(
                        label: 'Warden / Follow-up Notes',
                        controller: notesCtrl,
                        icon: Icons.notes_rounded,
                        hint:
                            'e.g. Parents informed, admitted overnight, given ORS',
                        maxLines: 2,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              label: 'Treatment / Bill Cost (₹)',
                              controller: costCtrl,
                              icon: Icons.currency_rupee_rounded,
                              hint: 'e.g. 1500',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedFollowUp ??
                                      DateTime.now()
                                          .add(const Duration(days: 3)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 180)),
                                );
                                if (picked != null) {
                                  setModalState(() => selectedFollowUp = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: ChatPalette.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: ChatPalette.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Follow-up Date',
                                        style: TextStyle(
                                            color: ChatPalette.muted,
                                            fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text(
                                      selectedFollowUp != null
                                          ? DateFormat('dd MMM yyyy')
                                              .format(selectedFollowUp!)
                                          : 'None / Select',
                                      style: TextStyle(
                                          color: selectedFollowUp != null
                                              ? ChatPalette.accentAmber
                                              : ChatPalette.dim,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Save button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ChatPalette.surface,
                    border: Border(top: BorderSide(color: ChatPalette.border)),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      final diagText = diagnosisCtrl.text.trim();
                      final hospText = hospitalCtrl.text.trim();
                      final medText = medicinesCtrl.text.trim();
                      if (diagText.isEmpty &&
                          hospText.isEmpty &&
                          medText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please enter a diagnosis, hospital name, or prescribed medicines.'),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      // 1. Instantly dismiss modal bottom sheet
                      Navigator.pop(modalCtx);

                      // 2. Prepare optimized lightweight base64 for instant 0ms image preview & fast upload
                      String? immediateBase64;
                      Uint8List? compressedBytes = scannedPrescriptionBytes;
                      if (scannedPrescriptionBytes != null &&
                          scannedPrescriptionBytes!.isNotEmpty) {
                        try {
                          final decoded = img_lib.decodeImage(scannedPrescriptionBytes!);
                          if (decoded != null) {
                            final resized = decoded.width > 900
                                ? img_lib.copyResize(decoded, width: 900)
                                : decoded;
                            compressedBytes = Uint8List.fromList(img_lib.encodeJpg(resized, quality: 75));
                            immediateBase64 = base64Encode(compressedBytes);
                          } else {
                            immediateBase64 = base64Encode(scannedPrescriptionBytes!);
                          }
                        } catch (_) {
                          immediateBase64 = base64Encode(scannedPrescriptionBytes!);
                        }
                      }

                      final localId =
                          'med_${DateTime.now().millisecondsSinceEpoch}';
                      final optimisticRecord = MedicalTreatmentRecord(
                        id: localId,
                        studentId: _student.id,
                        rollNo: _student.rollNo,
                        studentName: _student.name,
                        hostelId: _student.hostel,
                        treatmentDate: selectedDate,
                        hospitalName: hospText,
                        doctorName: doctorCtrl.text.trim(),
                        diagnosis: diagText.isNotEmpty
                            ? diagText
                            : 'Medical Consultation / Treatment',
                        medicinesPrescribed: medText,
                        notes: notesCtrl.text.trim(),
                        followUpDate: selectedFollowUp,
                        cost: double.tryParse(costCtrl.text.trim()) ?? 0.0,
                        prescriptionBase64: immediateBase64,
                        createdAt: DateTime.now(),
                      );

                      // 3. Instantly update the UI list & cache with 0ms delay
                      setState(() {
                        _treatmentRecords.insert(0, optimisticRecord);
                      });
                      StudentRecordCache.addTreatment(
                          _student.rollNo, optimisticRecord);

                      // 4. Instantly show clean & professional confirmation popup
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
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Medical Record Saved',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      'Prescription and treatment logged for ${_student.name}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      );

                      // 5. Background asynchronous backend sync
                      final capturedBytes = compressedBytes;
                      Future.microtask(() async {
                        String? prescriptionUrl;
                        String? prescriptionBase64 = immediateBase64;

                        if (capturedBytes != null &&
                            capturedBytes.isNotEmpty) {
                          try {
                            final uploadRes =
                                await ApiService.uploadFormPhoto(
                              imageBytes: capturedBytes,
                              rollNo: _student.rollNo,
                            );
                            if (uploadRes['success'] == true &&
                                uploadRes['photoUrl'] != null) {
                              prescriptionUrl = uploadRes['photoUrl'];
                            }
                          } catch (e) {
                            debugPrint(
                                'Background prescription upload notice: $e');
                          }
                        }

                        final treatmentPayload = {
                          'studentId': _student.id,
                          'rollNo': _student.rollNo,
                          'studentName': _student.name,
                          'hostelId': _student.hostel,
                          'treatmentDate': selectedDate.toIso8601String(),
                          'hospitalName': hospText,
                          'doctorName': doctorCtrl.text.trim(),
                          'diagnosis': diagText.isNotEmpty
                              ? diagText
                              : 'Medical Consultation / Treatment',
                          'medicinesPrescribed': medText,
                          'notes': notesCtrl.text.trim(),
                          'followUpDate':
                              selectedFollowUp?.toIso8601String(),
                          'cost': double.tryParse(costCtrl.text.trim()) ?? 0.0,
                          'prescriptionUrl': prescriptionUrl,
                          'prescriptionBase64': prescriptionBase64,
                        };

                        try {
                          final res = await ApiService.createMedicalTreatment(
                              treatmentPayload);
                          if (res['success'] == true &&
                              res['treatment'] != null) {
                            final saved = MedicalTreatmentRecord.fromJson(
                                res['treatment']);
                            final finalSaved = saved.copyWith(
                              prescriptionBase64:
                                  saved.prescriptionBase64 ?? immediateBase64,
                              prescriptionUrl:
                                  saved.prescriptionUrl ?? prescriptionUrl,
                            );
                            StudentRecordCache.addTreatment(
                                _student.rollNo, finalSaved);
                            if (mounted) {
                              setState(() {
                                final idx = _treatmentRecords
                                    .indexWhere((r) => r.id == localId);
                                if (idx != -1) {
                                  _treatmentRecords[idx] = finalSaved;
                                }
                              });
                            }
                          }
                        } catch (e) {
                          debugPrint('Background medical save notice: $e');
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ChatPalette.accentBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Save Medical Treatment Record',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _viewPrescriptionFullscreen(
      String title, String? imageUrl, String? base64Str) {
    if ((imageUrl == null || imageUrl.isEmpty) &&
        (base64Str == null || base64Str.isEmpty)) {
      return;
    }

    ImageProvider? provider;
    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        provider = MemoryImage(base64Decode(base64Str.split(',').last));
      } catch (_) {}
    }
    provider ??= imageUrl != null ? NetworkImage(imageUrl) : null;
    if (provider == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 26),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black54,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image(
                      image: provider!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _deleteTreatment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChatPalette.surface,
        title: Text('Delete Medical Record?',
            style: TextStyle(color: ChatPalette.text, fontSize: 16)),
        content: Text(
            'Are you sure you want to delete this treatment & prescription entry?',
            style: TextStyle(color: ChatPalette.muted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ChatPalette.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: ChatPalette.accentRose),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _treatmentRecords.removeWhere((t) => t.id == id);
    });
    StudentRecordCache.removeTreatment(_student.rollNo, id);

    try {
      await ApiService.deleteMedicalTreatment(id);
    } catch (e) {
      debugPrint('Delete treatment error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _student;

    return Scaffold(
      backgroundColor: ChatPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(s),
            _buildHeroProfile(s),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(s),
                  _buildMedicalTreatmentsTab(),
                  _buildLeaveApprovalsTab(),
                  _buildLateEntriesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Top Header ────────────────────────────────────────────────────────────
  Widget _buildHeader(StudentModel s) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        border: Border(bottom: BorderSide(color: ChatPalette.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded,
                color: ChatPalette.text, size: 22),
            tooltip: 'Back to Student Directory',
          ),
          const SizedBox(width: 4),
          Icon(Icons.folder_shared_rounded,
              color: ChatPalette.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Student Record',
                  style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${s.name} • ${s.rollNo}',
                  style: TextStyle(color: ChatPalette.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openEditStudentModal,
            icon: Icon(Icons.edit_note_rounded,
                color: ChatPalette.accent, size: 22),
            tooltip: 'Edit Student Record',
          ),
          IconButton(
            onPressed: _shareStudentRecord,
            icon: Icon(Icons.share_outlined,
                color: ChatPalette.accentGreen, size: 20),
            tooltip: 'Share Record',
          ),
        ],
      ),
    );
  }

  // ── 2. Hero Profile Banner ───────────────────────────────────────────────────
  Widget _buildHeroProfile(StudentModel s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        border: Border(bottom: BorderSide(color: ChatPalette.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final hasPhoto = (s.profilePhotoBase64 != null &&
                      s.profilePhotoBase64!.isNotEmpty) ||
                  (s.photoPath != null && s.photoPath!.isNotEmpty);
              if (hasPhoto) {
                _viewPrescriptionFullscreen(
                    s.name, s.photoPath, s.profilePhotoBase64);
              }
            },
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: ChatPalette.gradientPrimary,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ChatPalette.accent.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _cachedPhotoBytes != null
                  ? Image.memory(_cachedPhotoBytes!, fit: BoxFit.cover)
                  : s.photoPath != null
                      ? Image.network(s.photoPath!, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            s.name
                                .trim()
                                .split(' ')
                                .take(2)
                                .map((w) => w.isNotEmpty ? w[0] : '')
                                .join()
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ChatPalette.accentGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                ChatPalette.accentGreen.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        s.exitDate != null &&
                                s.exitDate!.toLowerCase().contains('exit')
                            ? 'Exited'
                            : 'Active Resident',
                        style: TextStyle(
                            color: ChatPalette.accentGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${s.department} • ${s.semester}',
                  style: TextStyle(color: ChatPalette.muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildPill(s.rollNo, ChatPalette.accent),
                    _buildPill('Room ${s.roomNo}', ChatPalette.accentGreen),
                    _buildPill(s.hostel, ChatPalette.accentAmber),
                    if (s.bloodGroup != null && s.bloodGroup!.isNotEmpty)
                      _buildPill('🩸 ${s.bloodGroup}', ChatPalette.accentRose),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ── 3. Tab Bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        border: Border(bottom: BorderSide(color: ChatPalette.border)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: ChatPalette.accent,
        indicatorWeight: 3,
        labelColor: ChatPalette.accent,
        unselectedLabelColor: ChatPalette.dim,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        tabs: [
          const Tab(
            icon: Icon(Icons.dashboard_outlined, size: 18),
            text: 'Overview & Stay',
          ),
          Tab(
            icon: Badge(
              label: Text('${_treatmentRecords.length}'),
              isLabelVisible: _treatmentRecords.isNotEmpty,
              backgroundColor: ChatPalette.accentBlue,
              child: const Icon(Icons.local_hospital_outlined, size: 18),
            ),
            text: 'Medical (${_treatmentRecords.length})',
          ),
          Tab(
            icon: Badge(
              label: Text('${_leaveRecords.length}'),
              isLabelVisible: _leaveRecords.isNotEmpty,
              backgroundColor: ChatPalette.accentGreen,
              child: const Icon(Icons.description_outlined, size: 18),
            ),
            text: 'Leaves (${_leaveRecords.length})',
          ),
          Tab(
            icon: Badge(
              label: Text('${_lateRecords.length}'),
              isLabelVisible: _lateRecords.isNotEmpty,
              backgroundColor: ChatPalette.accentAmber,
              child: const Icon(Icons.access_time_rounded, size: 18),
            ),
            text: 'Late Entry (${_lateRecords.length})',
          ),
        ],
      ),
    );
  }

  // ── TAB 1: REDESIGNED CLEAN LIGHT/DARK HARMONIOUS OVERVIEW & STAY CARD ───────
  Widget _buildOverviewTab(StudentModel s) {
    final joinDateDisplay = s.joiningDate?.isNotEmpty == true
        ? s.joiningDate!
        : DateFormat('dd MMM yyyy').format(s.createdAt);

    final isExited =
        s.exitDate != null && s.exitDate!.toLowerCase().contains('exit');
    final exitDateDisplay = s.exitDate?.isNotEmpty == true
        ? s.exitDate!
        : 'Active Resident';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── REDESIGNED HOSTEL STAY CARD (100% Theme Matched & Professional) ────
        Container(
          decoration: BoxDecoration(
            color: ChatPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ChatPalette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: ChatPalette.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.apartment_rounded,
                          color: ChatPalette.accent, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'HOSTEL RECORD',
                      style: TextStyle(
                        color: ChatPalette.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isExited
                                ? ChatPalette.accentRose
                                : ChatPalette.accentGreen)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isExited
                                  ? ChatPalette.accentRose
                                  : ChatPalette.accentGreen)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isExited
                                  ? ChatPalette.accentRose
                                  : ChatPalette.accentGreen,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isExited ? 'Exited' : 'Active Resident',
                            style: TextStyle(
                              color: isExited
                                  ? ChatPalette.accentRose
                                  : ChatPalette.accentGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: ChatPalette.border, height: 1),

              // Joining & Exit Tiles (Clean, High Contrast, Pastel Tinted)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Joined Date Tile
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ChatPalette.accentGreen
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: ChatPalette.accentGreen
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: ChatPalette.accentGreen
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.login_rounded,
                                          color: ChatPalette.accentGreen,
                                          size: 15),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'JOINED HOSTEL',
                                      style: TextStyle(
                                        color: ChatPalette.muted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  joinDateDisplay,
                                  style: TextStyle(
                                    color: ChatPalette.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Exit / Leave Tile
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: (isExited
                                      ? ChatPalette.accentRose
                                      : ChatPalette.accentAmber)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (isExited
                                        ? ChatPalette.accentRose
                                        : ChatPalette.accentAmber)
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: (isExited
                                                ? ChatPalette.accentRose
                                                : ChatPalette.accentAmber)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.event_available_rounded,
                                          color: isExited
                                              ? ChatPalette.accentRose
                                              : ChatPalette.accentAmber,
                                          size: 15),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'EXIT / STATUS',
                                      style: TextStyle(
                                        color: ChatPalette.muted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  exitDateDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isExited
                                        ? ChatPalette.accentRose
                                        : (exitDateDisplay == 'Active Resident'
                                            ? ChatPalette.accentGreen
                                            : ChatPalette.text),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Quick Stats Grid
        Text(
          'SUMMARY DISCIPLINE & MEDICAL STATS',
          style: TextStyle(
            color: ChatPalette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Leaves Approved',
                count: '${_leaveRecords.length}',
                color: ChatPalette.accentGreen,
                icon: Icons.description_outlined,
                onTap: () => _tabController.animateTo(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: 'Late Entries',
                count: '${_lateRecords.length}',
                color: ChatPalette.accentAmber,
                icon: Icons.access_time_rounded,
                onTap: () => _tabController.animateTo(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: 'Medical Visits',
                count: '${_treatmentRecords.length}',
                color: ChatPalette.accentBlue,
                icon: Icons.local_hospital_outlined,
                onTap: () => _tabController.animateTo(1),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Personal & Contact Info
        Text(
          'PERSONAL & GUARDIAN DETAILS',
          style: TextStyle(
            color: ChatPalette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ChatPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ChatPalette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDetailRow('Date of Birth', s.dateOfBirth),
              _buildDetailRow('Gender', s.gender),
              _buildDetailRow('Contact Phone', s.contactNo),
              _buildDetailRow('Email Address', s.emailId),
              _buildDetailRow('Blood Group', s.bloodGroup ?? 'Not provided'),
              _buildDetailRow(
                  'Emergency Phone', s.emergencyContact ?? 'Not provided'),
              _buildDetailRow(
                  'Guardian Name', s.guardianName ?? 'Not provided'),
              _buildDetailRow(
                  'Guardian Phone', s.guardianPhone ?? 'Not provided'),
              _buildDetailRow('Home Address', s.address ?? 'Not provided'),
              if (s.notes != null && s.notes!.isNotEmpty)
                _buildDetailRow('Special Remarks', s.notes!, isLast: true)
              else
                _buildDetailRow('Special Remarks', 'None', isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ChatPalette.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: ChatPalette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: TextStyle(
                  color: ChatPalette.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 2: MEDICAL & HOSPITAL TREATMENTS ─────────────────────────────────────
  Widget _buildMedicalTreatmentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TREATMENTS & PRESCRIPTIONS (${_treatmentRecords.length})',
                style: TextStyle(
                  color: ChatPalette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddMedicalTreatmentModal,
                icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                label: const Text('Add / Scan Record',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChatPalette.accentBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _treatmentRecords.isEmpty
              ? _buildEmptyState(
                  icon: Icons.local_hospital_outlined,
                  title: 'No Medical Treatments Logged',
                  subtitle:
                      'Tap "+ Add / Scan Record" above to upload hospital visits and prescriptions.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: _treatmentRecords.length,
                  itemBuilder: (ctx, i) {
                    final treat = _treatmentRecords[i];
                    return _buildTreatmentCard(treat);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTreatmentCard(MedicalTreatmentRecord treat) {
    final hasPrescription = (treat.prescriptionUrl != null &&
            treat.prescriptionUrl!.isNotEmpty) ||
        (treat.prescriptionBase64 != null &&
            treat.prescriptionBase64!.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ChatPalette.accentBlue.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(
                      color: ChatPalette.accentBlue.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    color: ChatPalette.accentBlue, size: 16),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a')
                      .format(treat.treatmentDate),
                  style: TextStyle(
                      color: ChatPalette.accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (treat.cost > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ChatPalette.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('₹${treat.cost.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: ChatPalette.accentAmber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: () => _deleteTreatment(treat.id),
                  child: Icon(Icons.delete_outline_rounded,
                      color: ChatPalette.accentRose, size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            treat.diagnosis,
                            style: TextStyle(
                              color: ChatPalette.text,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (treat.hospitalName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.apartment_rounded,
                                    color: ChatPalette.muted, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  treat.hospitalName,
                                  style: TextStyle(
                                      color: ChatPalette.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                          if (treat.doctorName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    color: ChatPalette.muted, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Dr. ${treat.doctorName}',
                                  style: TextStyle(
                                      color: ChatPalette.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasPrescription) ...[
                      GestureDetector(
                        onTap: () => _viewPrescriptionFullscreen(
                          'Prescription: ${treat.diagnosis}',
                          treat.prescriptionUrl,
                          treat.prescriptionBase64,
                        ),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: ChatPalette.accentBlue
                                    .withValues(alpha: 0.5)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (treat.prescriptionBase64 != null &&
                                  treat.prescriptionBase64!.isNotEmpty)
                                Image.memory(
                                  base64Decode(treat.prescriptionBase64!
                                      .split(',')
                                      .last),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: ChatPalette.background,
                                    child: Icon(Icons.broken_image_rounded,
                                        color: ChatPalette.dim, size: 20),
                                  ),
                                )
                              else if (treat.prescriptionUrl != null)
                                Image.network(
                                  treat.prescriptionUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: ChatPalette.background,
                                    child: Icon(Icons.broken_image_rounded,
                                        color: ChatPalette.dim, size: 20),
                                  ),
                                ),
                              Container(
                                color: Colors.black38,
                                child: const Center(
                                  child: Icon(Icons.zoom_in_rounded,
                                      color: Colors.white, size: 22),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (treat.medicinesPrescribed.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ChatPalette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ChatPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medicines & Instructions:',
                            style: TextStyle(
                                color: ChatPalette.accentBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(treat.medicinesPrescribed,
                            style: TextStyle(
                                color: ChatPalette.text, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
                if (treat.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Notes: ${treat.notes}',
                      style: TextStyle(color: ChatPalette.dim, fontSize: 11)),
                ],
                if (treat.followUpDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.event_repeat_rounded,
                          color: ChatPalette.accentAmber, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Follow-up: ${DateFormat('dd MMM yyyy').format(treat.followUpDate!)}',
                        style: TextStyle(
                            color: ChatPalette.accentAmber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 3: LEAVE APPROVALS (EXTRACTED FROM BACKEND) ──────────────────────────
  Widget _buildLeaveApprovalsTab() {
    return _leaveRecords.isEmpty
        ? _buildEmptyState(
            icon: Icons.description_outlined,
            title: 'No Leave Approvals Found',
            subtitle:
                'All leaves approved through the Scanner/Approval module are automatically extracted here.',
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _leaveRecords.length,
            itemBuilder: (ctx, i) {
              final leave = _leaveRecords[i];
              final appliedStr = leave['appliedAt'] ??
                  leave['applied_at'] ??
                  leave['createdAt'] ??
                  '';
              final appliedDt =
                  DateTime.tryParse(appliedStr) ?? DateTime.now();
              final formUrl =
                  leave['formImageUrl'] ?? leave['form_image_url'];
              final formBase64 =
                  leave['formImageBase64'] ?? leave['form_image_base64'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ChatPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ChatPalette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            ChatPalette.accentGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_outline_rounded,
                          color: ChatPalette.accentGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(appliedDt),
                                style: TextStyle(
                                    color: ChatPalette.text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ChatPalette.accentGreen
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Approved',
                                    style: TextStyle(
                                        color: ChatPalette.accentGreen,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Leave Application Form recorded for ${_student.hostel}',
                            style: TextStyle(
                                color: ChatPalette.muted, fontSize: 12),
                          ),
                          if (formUrl != null || formBase64 != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _viewPrescriptionFullscreen(
                                  'Leave Form: ${_student.name}',
                                  formUrl,
                                  formBase64),
                              child: Row(
                                children: [
                                  Icon(Icons.attachment_rounded,
                                      color: ChatPalette.accentGreen,
                                      size: 14),
                                  const SizedBox(width: 4),
                                  Text('View Attached Scanned Form',
                                      style: TextStyle(
                                          color: ChatPalette.accentGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          decoration:
                                              TextDecoration.underline)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  // ── TAB 4: LATE ENTRIES (EXTRACTED FROM BACKEND) ──────────────────────────────
  Widget _buildLateEntriesTab() {
    return _lateRecords.isEmpty
        ? _buildEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Clean Punctuality Record',
            subtitle:
                'No late entries have been recorded for this student at the gate.',
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _lateRecords.length,
            itemBuilder: (ctx, i) {
              final late = _lateRecords[i];
              final entryStr = late['entryAt'] ??
                  late['entry_at'] ??
                  late['actual_time'] ??
                  late['createdAt'] ??
                  '';
              final entryDt =
                  DateTime.tryParse(entryStr) ?? DateTime.now();
              final reason =
                  late['reason'] ?? 'Late entry recorded at hostel gate';
              final fine = late['fineAmount'] ?? late['fine_amount'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ChatPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ChatPalette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            ChatPalette.accentAmber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.access_time_rounded,
                          color: ChatPalette.accentAmber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(entryDt),
                                style: TextStyle(
                                    color: ChatPalette.text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              if (NumberFormat().parse(fine.toString()) > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ChatPalette.accentRose
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Fine: ₹$fine',
                                      style: TextStyle(
                                          color: ChatPalette.accentRose,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Reason: $reason',
                              style: TextStyle(
                                  color: ChatPalette.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: ChatPalette.dim.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: ChatPalette.text,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ChatPalette.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
