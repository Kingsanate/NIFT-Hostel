import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img_lib;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../chat/chat_palette.dart';
import '../../scanner/models/student_model.dart';
import '../../services/api_service.dart';
import '../../services/student_repository.dart';
import 'leave_approval_detail_page.dart';
import 'models/entry_models.dart';
import 'widgets/smooth_route.dart';
import 'widgets/student_avatar.dart';
import 'widgets/student_search_bar.dart';

/// "Leave Approval" tab — search a student, capture the hard-copy
/// leave application form, and store it merged with the student profile.
class LeaveApprovalTab extends StatefulWidget {
  final String hostel;
  final DateTime month;
  final List<LeaveApprovalRecord> records;
  final List<Color> gradient;
  final Color glowColor;
  final ValueChanged<LeaveApprovalRecord> onAdd;
  final ValueChanged<String> onDelete;

  const LeaveApprovalTab({
    super.key,
    required this.hostel,
    required this.month,
    required this.records,
    required this.gradient,
    required this.glowColor,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<LeaveApprovalTab> createState() => _LeaveApprovalTabState();
}

class _LeaveApprovalTabState extends State<LeaveApprovalTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next != _query) {
      setState(() => _query = next);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;

    return ValueListenableBuilder<List<StudentModel>>(
      valueListenable: StudentRepository.studentsNotifier,
      builder: (context, allStudents, _) {
        final hostelStudents = allStudents
            .where((s) => matchesHostel(s, widget.hostel))
            .toList();

        final searchResults = isSearching
            ? hostelStudents.where((s) => matchesQuery(s, _query)).toList()
            : <StudentModel>[];

        final monthRecords = widget.records
            .where((r) => r.inMonth(widget.month.year, widget.month.month))
            .toList()
          ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed search bar at the top
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
              child: StudentSearchBar(
                controller: _searchController,
                hint: 'Search student to attach leave form…',
                onChanged: (_) => _onSearchChanged(),
                onClear: _clearSearch,
              ),
            ),
            // Full-height scrollable body occupying all remaining space
            Expanded(
              child: isSearching
                  ? StudentSearchResultsView(
                      students: searchResults,
                      query: _query,
                      glowColor: widget.glowColor,
                      actionTooltip: 'Attach Leave Form',
                      onSelected: (student) {
                        _openCaptureFlow(student);
                        _clearSearch();
                      },
                      onClear: _clearSearch,
                    )
                  : monthRecords.isEmpty
                      ? _buildEmpty()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(22, 4, 22, 80),
                          children: [
                            for (final rec in monthRecords)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _LeaveRow(
                                  record: rec,
                                  glowColor: widget.glowColor,
                                  onDelete: widget.onDelete,
                                  onTap: () => Navigator.of(context).push(
                                    smoothSlideRoute(
                                      LeaveApprovalDetailPage(
                                        record: rec,
                                        onUpdateRecord: (updated) {
                                          widget.onAdd(updated);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ChatPalette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ChatPalette.border),
            ),
            child: Icon(Icons.description_outlined,
                size: 24, color: ChatPalette.muted),
          ),
          const SizedBox(height: 12),
          Text(
            'No leave applications this month',
            style: TextStyle(
              color: ChatPalette.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Search a student above to attach a leave form.',
            style: TextStyle(color: ChatPalette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _openCaptureFlow(StudentModel student) async {
    final picked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ChatPalette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attach Leave Form',
                style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                StudentAvatar(
                  photoBase64: student.profilePhotoBase64,
                  fallbackIcon: student.gender == 'Female'
                      ? Icons.girl_rounded
                      : Icons.person_rounded,
                  fallbackColor: ChatPalette.accentDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        [
                          student.rollNo,
                          student.department,
                          if (student.roomNo.isNotEmpty)
                            'Room ${student.roomNo}',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: ChatPalette.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ActionButton(
              icon: Icons.document_scanner_rounded,
              label: (!kIsWeb && Platform.isAndroid)
                  ? 'Scan with Google ML Kit ✦'
                  : kIsWeb
                      ? 'Upload form photo'
                      : 'Capture form photo',
              color: ChatPalette.accentDeep,
              onTap: () => Navigator.of(sheetCtx).pop(true),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              color: ChatPalette.muted,
              onTap: () => Navigator.of(sheetCtx).pop(false),
            ),
          ],
        ),
      ),
    );

    // true → camera (or upload on web), false → gallery
    final imageBytes =
        picked == null ? null : await _pickImage(useCamera: picked);
    if (imageBytes == null || !mounted) return;

    final savedAt = DateTime.now();
    final duplicate = widget.records.any(
      (r) =>
          r.studentId == student.id &&
          r.appliedAt.year == savedAt.year &&
          r.appliedAt.month == savedAt.month &&
          r.appliedAt.day == savedAt.day,
    );

    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${student.name} already has a leave application today.'),
          backgroundColor: ChatPalette.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    String? formImageUrl;
    String? uploadError;

    // Show upload loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: ChatPalette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ChatPalette.borderSoft),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: ChatPalette.accentDeep, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text(
                    'Uploading form…',
                    style: TextStyle(color: ChatPalette.text, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(imageBytes.length / 1024).toStringAsFixed(0)} KB',
                    style: TextStyle(color: ChatPalette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Upload is best-effort — the record is always saved locally with the
    // base64 image so a scan is never lost on slow/offline connections.
    try {
      final res = await ApiService.uploadFormPhoto(
        imageBytes: imageBytes,
        rollNo: student.rollNo,
      );
      if (res['success'] == true && res['photoUrl'] != null) {
        formImageUrl = res['photoUrl'];
      } else {
        uploadError = res['error']?.toString() ?? 'photo upload failed';
      }
    } catch (e) {
      debugPrint('Failed to upload form image: $e');
      uploadError = e.toString();
    } finally {
      if (mounted) Navigator.of(context).pop(); // Close loading dialog
    }

    final record = LeaveApprovalRecord(
      id: 'LA${DateTime.now().microsecondsSinceEpoch}',
      studentId: student.id,
      name: student.name,
      rollNo: student.rollNo,
      hostel: widget.hostel,
      department: student.department,
      semester: student.semester,
      roomNo: student.roomNo,
      photoBase64: student.profilePhotoBase64,
      appliedAt: savedAt,
      formImageUrl: formImageUrl,
      formImageBase64: base64Encode(imageBytes),
    );

    widget.onAdd(record);
    if (!mounted) return;

    if (uploadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Leave form saved locally for ${student.name} — photo will sync to server when online.',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: ChatPalette.accentAmber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Leave form attached for ${student.name}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
          ],
        ),
        backgroundColor: ChatPalette.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Launches the best available document scanner for the current platform.
  /// Android  → Google ML Kit Document Scanner (auto-enhance, perspective
  ///             correction, stain/finger removal via SCANNER_MODE_FULL);
  ///             falls back to the camera if ML Kit is unavailable.
  /// iOS/Web  → image_picker fallback (camera or gallery).
  Future<Uint8List?> _pickImage({required bool useCamera}) async {
    try {
      // ── Android: Google ML Kit Document Scanner ─────────────────────────
      if (!kIsWeb && Platform.isAndroid && useCamera) {
        try {
          final options = DocumentScannerOptions(
            mode: ScannerMode.full, // full ML enhancement
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
        } catch (e) {
          debugPrint('ML Kit scan unavailable, falling back to camera: $e');
        }
      }

      // ── iOS / Web / Gallery fallback ────────────────────────────────────
      // Note: resize parameters are skipped on web — the web resizer is
      // canvas-based and can throw; _compressImage handles size reduction.
      final source = useCamera
          ? (kIsWeb ? ImageSource.gallery : ImageSource.camera)
          : ImageSource.gallery;
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: kIsWeb ? null : 88,
        maxWidth: kIsWeb ? null : 1600,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return _compressImage(bytes);
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open scanner. Try gallery instead.'),
            backgroundColor: ChatPalette.accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  /// Compresses [bytes] to JPEG until under [targetKB] kilobytes.
  /// Uses the 'image' package already in pubspec.yaml.
  Uint8List _compressImage(Uint8List bytes, {int targetKB = 900}) {
    if (bytes.length <= targetKB * 1024) return bytes;
    final decoded = img_lib.decodeImage(bytes);
    if (decoded == null) return bytes; // decode failed — return original

    // Progressively lower quality until under limit (min quality = 40)
    int quality = 85;
    Uint8List result = bytes;
    while (result.length > targetKB * 1024 && quality >= 40) {
      result = Uint8List.fromList(img_lib.encodeJpg(decoded, quality: quality));
      quality -= 10;
    }
    debugPrint('Compressed scan: ${bytes.length ~/ 1024}KB → ${result.length ~/ 1024}KB (quality=$quality)');
    return result;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: ChatPalette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ChatPalette.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 11),
            Text(label,
                style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  final LeaveApprovalRecord record;
  final Color glowColor;
  final ValueChanged<String> onDelete;
  final VoidCallback onTap;

  const _LeaveRow({
    required this.record,
    required this.glowColor,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final detail = [
      record.rollNo,
      record.department,
      if (record.semester.isNotEmpty) 'Sem ${record.semester}',
      if (record.roomNo.isNotEmpty) 'Room ${record.roomNo}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ChatPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ChatPalette.border),
        ),
        child: Row(
          children: [
            StudentAvatar(
              photoBase64: record.photoBase64,
              fallbackIcon: Icons.description_outlined,
              fallbackColor: glowColor,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ChatPalette.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Text(DateFormat('hh:mm a').format(record.appliedAt),
                style: TextStyle(
                    color: glowColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ChatPalette.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 12, color: ChatPalette.accentGreen),
                  const SizedBox(width: 4),
                  Text('Form',
                      style: TextStyle(
                          color: ChatPalette.accentGreen,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => onDelete(record.id),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ChatPalette.accentRose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    size: 16, color: ChatPalette.accentRose),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 20, color: ChatPalette.dim),
          ],
        ),
      ),
    );
  }
}
