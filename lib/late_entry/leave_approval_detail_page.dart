import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../chat/chat_palette.dart';
import '../../scanner/models/student_model.dart';
import '../../services/student_repository.dart';
import 'models/entry_models.dart';
import 'services/pdf_service.dart';
import 'widgets/student_avatar.dart';

/// Full-featured Leave Application detail view:
/// - Robust Student Profile Card (auto-resolves room, photo, department from repo or record)
/// - Attached Leave Form with full-screen zoom viewer
/// - Direct "Scan / Attach Form" button if document was missing or needs update
class LeaveApprovalDetailPage extends StatefulWidget {
  final LeaveApprovalRecord record;
  final ValueChanged<LeaveApprovalRecord>? onUpdateRecord;

  const LeaveApprovalDetailPage({
    super.key,
    required this.record,
    this.onUpdateRecord,
  });

  @override
  State<LeaveApprovalDetailPage> createState() =>
      _LeaveApprovalDetailPageState();
}

class _LeaveApprovalDetailPageState extends State<LeaveApprovalDetailPage> {
  late LeaveApprovalRecord _record;
  StudentModel? _matchedStudent;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _resolveStudentData();
  }

  void _resolveStudentData() {
    final all = StudentRepository.studentsNotifier.value;
    final cleanRoll =
        _record.rollNo.replaceAll(RegExp(r'[\/\-\s]'), '').toLowerCase();

    for (final s in all) {
      final sClean =
          s.rollNo.replaceAll(RegExp(r'[\/\-\s]'), '').toLowerCase();
      if (s.id == _record.studentId ||
          s.rollNo.toLowerCase() == _record.rollNo.toLowerCase() ||
          (cleanRoll.isNotEmpty && sClean == cleanRoll)) {
        _matchedStudent = s;
        break;
      }
    }
  }

  String get _displayName =>
      _record.name.isNotEmpty ? _record.name : (_matchedStudent?.name ?? 'Student');

  String get _displayRoll =>
      _record.rollNo.isNotEmpty ? _record.rollNo : (_matchedStudent?.rollNo ?? '—');

  String get _displayDept =>
      _record.department.isNotEmpty
          ? _record.department
          : (_matchedStudent?.department ?? '—');

  String get _displaySem =>
      _record.semester.isNotEmpty
          ? _record.semester
          : (_matchedStudent?.semester ?? '—');

  String get _displayRoom {
    if (_record.roomNo.isNotEmpty && _record.roomNo != '—') {
      return _record.roomNo;
    }
    if (_matchedStudent?.roomNo.isNotEmpty == true &&
        _matchedStudent!.roomNo != '—') {
      return _matchedStudent!.roomNo;
    }
    return '—';
  }

  String get _displayHostel =>
      _record.hostel.isNotEmpty ? _record.hostel : (_matchedStudent?.hostel ?? 'Hostel');

  String? get _displayPhoto =>
      _record.photoBase64?.isNotEmpty == true
          ? _record.photoBase64
          : _matchedStudent?.profilePhotoBase64;

  bool get _hasFormImage =>
      (_record.formImageBase64 != null &&
          _record.formImageBase64!.trim().isNotEmpty) ||
      (_record.formImageUrl != null &&
          _record.formImageUrl!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatPalette.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: ChatPalette.background,
                border:
                    Border(bottom: BorderSide(color: ChatPalette.borderSoft)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        Icon(Icons.arrow_back_rounded, color: ChatPalette.text),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Leave Application',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.picture_as_pdf_rounded,
                        color: ChatPalette.accentDeep),
                    onPressed: () =>
                        PdfService.exportSingleLeave(record: _record),
                    tooltip: 'Download PDF',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attached Leave Form',
                            style: TextStyle(
                                color: ChatPalette.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Submitted on ${DateFormat('dd MMM yyyy, hh:mm a').format(_record.appliedAt)}',
                            style: TextStyle(
                                color: ChatPalette.muted, fontSize: 12),
                          ),
                        ],
                      ),
                      if (_hasFormImage)
                        TextButton.icon(
                          onPressed: _openAttachSheet,
                          icon: Icon(Icons.refresh_rounded,
                              size: 15, color: ChatPalette.accentDeep),
                          label: Text(
                            'Replace',
                            style: TextStyle(
                                color: ChatPalette.accentDeep,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            backgroundColor:
                                ChatPalette.accentDeep.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFormImageSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudentAvatar(
                photoBase64: _displayPhoto,
                fallbackIcon: _displayName.toLowerCase().contains('g') &&
                        _displayHostel.contains('Girls')
                    ? Icons.girl_rounded
                    : Icons.person_rounded,
                fallbackColor: ChatPalette.accentDeep,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _displayRoll,
                      style: TextStyle(
                          color: ChatPalette.accentDeep,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ChatPalette.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: ChatPalette.accentGreen.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Approved',
                  style: TextStyle(
                      color: ChatPalette.accentGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: ChatPalette.borderSoft, height: 1),
          const SizedBox(height: 12),
          _InfoRow(label: 'Department', value: _displayDept),
          _InfoRow(label: 'Semester', value: _displaySem),
          _InfoRow(label: 'Room', value: _displayRoom),
          _InfoRow(label: 'Hostel', value: _displayHostel),
        ],
      ),
    );
  }

  Widget _buildFormImageSection() {
    if (_record.formImageBase64 != null &&
        _record.formImageBase64!.trim().isNotEmpty) {
      return _buildImageCard(
        imageWidget: Image.memory(
          base64Decode(_record.formImageBase64!.split(',').last),
          width: double.infinity,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _buildImageError(),
        ),
        onTapZoom: () => _openFullscreenViewer(
          title: 'Leave Application Form: $_displayName',
          imageBase64: _record.formImageBase64,
          imageUrl: _record.formImageUrl,
        ),
      );
    } else if (_record.formImageUrl != null &&
        _record.formImageUrl!.trim().isNotEmpty) {
      return _buildImageCard(
        imageWidget: Image.network(
          _record.formImageUrl!,
          width: double.infinity,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 240,
              decoration: BoxDecoration(
                color: ChatPalette.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: ChatPalette.accentDeep,
                  strokeWidth: 3,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _buildImageError(),
        ),
        onTapZoom: () => _openFullscreenViewer(
          title: 'Leave Application Form: $_displayName',
          imageBase64: _record.formImageBase64,
          imageUrl: _record.formImageUrl,
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: ChatPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ChatPalette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ChatPalette.accentAmber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.document_scanner_outlined,
                  size: 32, color: ChatPalette.accentAmber),
            ),
            const SizedBox(height: 12),
            Text(
              'No Scanned Form Attached',
              style: TextStyle(
                  color: ChatPalette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan or upload the hard-copy leave application submitted by the student.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ChatPalette.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openAttachSheet,
              icon: const Icon(Icons.add_a_photo_rounded, size: 16),
              label: const Text('Scan / Attach Form Now',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ChatPalette.accentDeep,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildImageCard({
    required Widget imageWidget,
    required VoidCallback onTapZoom,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onTap: onTapZoom,
            child: Stack(
              children: [
                imageWidget,
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded,
                            color: Colors.white, size: 15),
                        SizedBox(width: 4),
                        Text(
                          'Tap to zoom',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
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
  }

  Widget _buildImageError() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatPalette.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded,
                color: ChatPalette.accentRose, size: 30),
            const SizedBox(height: 8),
            Text(
              'Form image could not be displayed',
              style: TextStyle(color: ChatPalette.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  void _openAttachSheet() async {
    final picked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ChatPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ChatPalette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Attach Leave Form',
                style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                icon: const Icon(Icons.document_scanner_rounded, size: 18),
                label: Text(
                  (!kIsWeb && Platform.isAndroid)
                      ? 'Scan with Google ML Kit'
                      : 'Capture form photo',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChatPalette.accentDeep,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(sheetCtx).pop(false),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ChatPalette.text,
                  side: BorderSide(color: ChatPalette.border),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;
    final imageBytes = await _pickImage(useCamera: picked);
    if (imageBytes == null || !mounted) return;

    final base64Str = base64Encode(imageBytes);

    setState(() {
      _record = _record.copyWith(
        formImageBase64: base64Str,
      );
    });

    widget.onUpdateRecord?.call(_record);

    // Save to Hive & background backend sync
    await EntryStore.saveLeaveApprovals([_record, ...await EntryStore.loadLeaveApprovals()]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Leave form successfully attached and saved!'),
          backgroundColor: ChatPalette.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<Uint8List?> _pickImage({required bool useCamera}) async {
    try {
      if (!kIsWeb && Platform.isAndroid && useCamera) {
        try {
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
          return await file.readAsBytes();
        } catch (e) {
          debugPrint('ML Kit scan unavailable, falling back to camera: $e');
        }
      }

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
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  void _openFullscreenViewer({
    required String title,
    String? imageBase64,
    String? imageUrl,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.white),
                onPressed: () =>
                    PdfService.exportSingleLeave(record: _record),
                tooltip: 'Download PDF',
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: imageBase64 != null && imageBase64.isNotEmpty
                  ? Image.memory(
                      base64Decode(imageBase64.split(',').last),
                      fit: BoxFit.contain,
                    )
                  : (imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.contain)
                      : const Icon(Icons.broken_image_rounded,
                          color: Colors.white54, size: 60)),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                  color: ChatPalette.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                  color: ChatPalette.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
