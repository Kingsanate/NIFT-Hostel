import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../chat/chat_palette.dart';
import '../services/api_service.dart';
import 'models/student_model.dart';
import 'services/extraction_service.dart';
import '../main.dart'; // For AppConfig
import 'services/image_helper.dart';

class ProcessingPage extends StatefulWidget {
  final String imagePath;
  final Uint8List imageBytes;
  final String selectedHostel;

  const ProcessingPage({
    super.key,
    required this.imagePath,
    required this.imageBytes,
    required this.selectedHostel,
  });

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  _Phase _phase = _Phase.analyzing;
  StudentModel? _student;

  @override
  void initState() {
    super.initState();
    _runExtraction();
  }

  Future<void> _runExtraction() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.extracting);

    List<String> apiKeys = AppConfig.scannerKeys;
    StudentModel parsedData;
    bool isAiFallback = false;
    String errorMessage = 'AI server limit reached. Document attached — please verify details.';

    try {
      if (apiKeys.isEmpty) {
        isAiFallback = true;
        parsedData = StudentModel.demoExtracted(
          photoPath: widget.imagePath,
          hostel: widget.selectedHostel,
        );
        final String? fastFaceBase64 = await ImageHelper.cropFaceFromImage(widget.imagePath);
        if (fastFaceBase64 != null) {
          parsedData = parsedData.copyWith(
            profilePhotoBase64: fastFaceBase64,
            photoPath: fastFaceBase64,
          );
        }
      } else {
        final service = ExtractionService(apiKeys: apiKeys);

        // Run AI Extraction and Face Detection in PARALLEL for maximum speed
        final aiFuture = service.extractFromImage(
          imagePath: widget.imagePath,
          imageBytes: widget.imageBytes,
          selectedHostel: widget.selectedHostel,
        ).catchError((localError) {
          debugPrint('Local extraction error: $localError');
          errorMessage = localError.toString();
          isAiFallback = true;
          return StudentModel.demoExtracted(
            photoPath: widget.imagePath,
            hostel: widget.selectedHostel,
          );
        });

        final faceFuture = ImageHelper.cropFaceFromImage(widget.imagePath)
            .timeout(const Duration(seconds: 3), onTimeout: () => null)
            .catchError((_) => null); // Ignore face crop errors

        // Wait for both to finish concurrently
        final results = await Future.wait([aiFuture, faceFuture]);
        
        parsedData = results[0] as StudentModel;
        final String? fastFaceBase64 = results[1] as String?;

        if (fastFaceBase64 != null && fastFaceBase64.isNotEmpty) {
          parsedData = parsedData.copyWith(
            profilePhotoBase64: fastFaceBase64,
            photoPath: fastFaceBase64,
          );
        }
      }

      if (!mounted) return;

      String prefix = widget.selectedHostel.contains('Nongthymmai') ? 'NG-' : widget.selectedHostel.contains('Girls') ? 'GH-' : 'BH-';
      parsedData = parsedData.copyWith(roomNo: prefix);

      setState(() {
        _phase = _Phase.done;
        _student = parsedData;
      });

      if (isAiFallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: ChatPalette.accentAmber,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Unexpected error in processing: $e');
      if (!mounted) return;
      // Never pop the page! Fallback to editing form so user can input data.
      String prefix = widget.selectedHostel.contains('Nongthymmai') ? 'NG-' : widget.selectedHostel.contains('Girls') ? 'GH-' : 'BH-';
      final fallbackStudent = StudentModel.demoExtracted(
        photoPath: widget.imagePath,
        hostel: widget.selectedHostel,
      ).copyWith(
        roomNo: prefix,
        profilePhotoBase64: null,
      );

      setState(() {
        _phase = _Phase.done;
        _student = fallbackStudent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatPalette.background,
      body: SafeArea(
        child: Column(children: [
          _TopBar(phase: _phase),
          Expanded(
            child: _phase == _Phase.done && _student != null
                ? _EditableFormView(
                    student: _student!, formImageBytes: widget.imageBytes)
                : _AnalyzingView(phase: _phase),
          ),
        ]),
      ),
    );
  }
}

enum _Phase { analyzing, extracting, done }

// ── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final _Phase phase;
  const _TopBar({required this.phase});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ChatPalette.canvas,
        border: Border(bottom: BorderSide(color: ChatPalette.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Icon(Icons.arrow_back_rounded,
              color: ChatPalette.muted, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('AI Extraction',
                  style: TextStyle(
                      color: ChatPalette.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text(
                phase == _Phase.analyzing
                    ? 'Analyzing document…'
                    : phase == _Phase.extracting
                        ? 'Extracting fields…'
                        : 'Review & confirm details',
                style:
                    TextStyle(color: ChatPalette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (phase == _Phase.done
                    ? ChatPalette.accentGreen
                    : ChatPalette.accent)
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: (phase == _Phase.done
                        ? ChatPalette.accentGreen
                        : ChatPalette.accent)
                    .withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: phase == _Phase.done
                    ? ChatPalette.accentGreen
                    : ChatPalette.accent,
                shape: BoxShape.circle,
              ),
            )
                .animate(
                    onPlay: phase == _Phase.done ? null : (c) => c.repeat())
                .fadeOut(duration: 600.ms)
                .then()
                .fadeIn(duration: 600.ms),
            SizedBox(width: 5),
            Text(
              phase == _Phase.done ? 'Complete' : 'Processing',
              style: TextStyle(
                  color: phase == _Phase.done
                      ? ChatPalette.accentGreen
                      : ChatPalette.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Analyzing view ────────────────────────────────────────────────────────────
class _AnalyzingView extends StatelessWidget {
  final _Phase phase;
  const _AnalyzingView({required this.phase});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: ChatPalette.surface,
            shape: BoxShape.circle,
            border: Border.all(color: ChatPalette.border),
          ),
          child: Icon(Icons.document_scanner_outlined,
              color: ChatPalette.accent, size: 28),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
                duration: 1400.ms,
                color: ChatPalette.accent.withValues(alpha: 0.4))
            .then()
            .shimmer(duration: 1400.ms),
        SizedBox(height: 18),
        Text('Reading Form',
            style: TextStyle(
                color: ChatPalette.text,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Text(
            phase == _Phase.extracting
                ? 'Extracting text and student photo…'
                : 'Detecting document boundaries…',
            style:
                TextStyle(color: ChatPalette.muted, fontSize: 13)),
        SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: ChatPalette.accent, shape: BoxShape.circle),
            )
                .animate(onPlay: (c) => c.repeat())
                .moveY(
                    begin: 0,
                    end: -8,
                    delay: Duration(milliseconds: i * 180),
                    duration: 450.ms,
                    curve: Curves.easeOut)
                .then()
                .moveY(begin: -8, end: 0, duration: 450.ms),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ── Editable Form View ────────────────────────────────────────────────────────
class _EditableFormView extends StatefulWidget {
  final StudentModel student;
  final Uint8List formImageBytes;
  const _EditableFormView(
      {required this.student, required this.formImageBytes});

  @override
  State<_EditableFormView> createState() => _EditableFormViewState();
}

class _EditableFormViewState extends State<_EditableFormView> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _rollNoCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _semCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _genderCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _roomCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    
    // Auto-detect gender based on hostel
    String initialGender = s.gender;
    if (initialGender.isEmpty || initialGender == 'Pending') {
      if (s.hostel.toLowerCase().contains('boy')) {
        initialGender = 'Male';
      } else if (s.hostel.toLowerCase().contains('girl')) {
        initialGender = 'Female';
      }
    }

    // Auto-prefix room number based on hostel
    String initialRoom = s.roomNo;
    if (initialRoom.isEmpty || initialRoom == 'Pending') {
      if (s.hostel.toLowerCase().contains('nongthymmai')) {
        initialRoom = 'NG-';
      } else if (s.hostel.toLowerCase().contains('boy')) {
        initialRoom = 'BH-';
      } else if (s.hostel.toLowerCase().contains('girl')) {
        initialRoom = 'GH-';
      }
    }

    _nameCtrl = TextEditingController(text: s.name);
    _rollNoCtrl = TextEditingController(text: s.rollNo);
    _deptCtrl = TextEditingController(text: s.department);
    _semCtrl = TextEditingController(text: s.semester);
    _dobCtrl = TextEditingController(text: s.dateOfBirth);
    _genderCtrl = TextEditingController(text: initialGender);
    _contactCtrl = TextEditingController(text: s.contactNo);
    _emailCtrl = TextEditingController(text: s.emailId);
    _roomCtrl = TextEditingController(text: initialRoom);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollNoCtrl.dispose();
    _deptCtrl.dispose();
    _semCtrl.dispose();
    _dobCtrl.dispose();
    _genderCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    final updated = StudentModel(
      id: widget.student.id,
      name: _nameCtrl.text,
      rollNo: _rollNoCtrl.text,
      department: _deptCtrl.text,
      semester: _semCtrl.text,
      dateOfBirth: _dobCtrl.text,
      gender: _genderCtrl.text,
      contactNo: _contactCtrl.text,
      emailId: _emailCtrl.text,
      roomNo: _roomCtrl.text,
      hostel: widget.student.hostel,
      photoPath: widget.student.photoPath,
      profilePhotoBase64: widget.student.profilePhotoBase64,
      createdAt: widget.student.createdAt,
    );
    
    try {
      final allStudents = await ApiService.fetchStudents();
      final existing = allStudents.where((s) => (s['rollNo'] ?? s['roll_no'] ?? '').toString().trim().toUpperCase() == updated.rollNo.trim().toUpperCase()).toList();
      if (existing.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Student with this Roll No already exists!', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: ChatPalette.accentRose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      String? finalPhotoPath = updated.photoPath;
      if (updated.profilePhotoBase64 != null && updated.profilePhotoBase64!.isNotEmpty) {
        try {
          final res = await ApiService.uploadFacePhoto(
            base64Image: updated.profilePhotoBase64!,
            rollNo: updated.rollNo,
          );
          if (res['url'] != null) {
            finalPhotoPath = res['url'];
          }
        } catch (e) {
          debugPrint('Failed to upload face: $e');
        }
      }

      final studentToSave = updated.copyWith(photoPath: finalPhotoPath, profilePhotoBase64: null);
      Map<String, dynamic> payload = studentToSave.toBackend();
      
      final res = await ApiService.createStudent(payload);
      final insertedData = res['student'] ?? payload;
      final finalStudent = StudentModel.fromBackend(insertedData, updated.hostel);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Student Successfully Saved!', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.only(bottom: 20, left: 20, right: 20),
        ),
      );
      
      // Pop processing page
      Navigator.of(context).pop(finalStudent);
    } catch (e) {
      debugPrint('Error saving student to cloud: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving to cloud: $e'),
          backgroundColor: ChatPalette.accentDeep,
        ),
      );
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(ChatPalette.accentDeep),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20),
            Text('Saving to Cloud...', style: TextStyle(color: ChatPalette.text, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    final hasStudentPhoto = widget.student.profilePhotoBase64 != null &&
        widget.student.profilePhotoBase64!.isNotEmpty;
    final faceBytes = hasStudentPhoto
        ? base64Decode(widget.student.profilePhotoBase64!.split(',').last)
        : null;
    final initials = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase()
        : 'S';

    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Student profile header ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ChatPalette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ChatPalette.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Student face photo or initials avatar
                GestureDetector(
                  onTap: faceBytes == null ? null : () {
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(faceBytes, fit: BoxFit.contain),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 100,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: ChatPalette.accent.withValues(alpha: 0.5),
                          width: 2),
                      color: ChatPalette.canvasDeep,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: faceBytes != null
                          ? Image.memory(faceBytes, fit: BoxFit.cover)
                          : Center(
                              child: Text(initials,
                                  style: TextStyle(
                                      color: ChatPalette.accent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nameCtrl.text,
                            style: TextStyle(
                                color: ChatPalette.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        SizedBox(height: 3),
                        Text(_rollNoCtrl.text,
                            style: TextStyle(
                                color: ChatPalette.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: ChatPalette.accentGreen
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: ChatPalette.accentGreen
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: ChatPalette.accentGreen, size: 10),
                                SizedBox(width: 4),
                                Text(
                                    faceBytes != null
                                        ? 'Photo extracted'
                                        : 'No photo found',
                                    style: TextStyle(
                                        color: faceBytes != null
                                            ? ChatPalette.accentGreen
                                            : ChatPalette.muted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                              ]),
                        ),
                      ]),
                ),
                // Small thumbnail of scanned form
                GestureDetector(
                  onTap: () {
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(widget.formImageBytes, fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      widget.formImageBytes,
                      width: 44,
                      height: 56,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
              ]),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.08),

            SizedBox(height: 10),

            // ── Info notice ─────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: ChatPalette.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ChatPalette.accent.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: ChatPalette.accent, size: 13),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'AI-extracted data. Tap any field to correct mistakes before saving.',
                      style: TextStyle(
                          color: ChatPalette.muted,
                          fontSize: 11)),
                ),
              ]),
            ).animate().fadeIn(delay: 100.ms),

            SizedBox(height: 10),

            // ── Editable fields card ─────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              decoration: BoxDecoration(
                color: ChatPalette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ChatPalette.border),
              ),
              child: Column(children: [
                _row(
                  _f('Name', _nameCtrl, Icons.person_outline),
                  _f('Roll No', _rollNoCtrl, Icons.badge_outlined),
                ),
                _row(
                  _f('Department', _deptCtrl, Icons.school_outlined),
                  _f('Semester', _semCtrl, Icons.calendar_today_outlined),
                ),
                _row(
                  _f('Date of Birth', _dobCtrl, Icons.cake_outlined),
                  _f('Gender', _genderCtrl, Icons.wc_outlined),
                ),
                _row(
                  _f('Contact', _contactCtrl, Icons.phone_outlined),
                  _f('Room No', _roomCtrl, Icons.bed_outlined),
                ),
                _f('Email ID', _emailCtrl, Icons.email_outlined),
              ]),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.08),
          ],
        ),
      ),

      // ── Bottom action bar ───────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: ChatPalette.canvas,
          border: Border(top: BorderSide(color: ChatPalette.border)),
        ),
        child: Row(children: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.replay_rounded, size: 14),
            label: Text('Re-scan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: ChatPalette.accentRose,
              side: BorderSide(
                  color: ChatPalette.accentRose.withValues(alpha: 0.4)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _confirm,
              icon: Icon(Icons.check_rounded, size: 15),
              label: Text('Confirm & Save',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ChatPalette.accentDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  // Helper: side-by-side row
  Widget _row(Widget a, Widget b) => Row(children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ]);

  // Helper: compact text field
  Widget _f(String label, TextEditingController ctrl, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(
            color: ChatPalette.text,
            fontSize: 12,
            fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              color: ChatPalette.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w400),
          filled: true,
          fillColor: ChatPalette.canvas,
          prefixIcon: Icon(icon, color: ChatPalette.dim, size: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ChatPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ChatPalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ChatPalette.accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}
