import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/entry_models.dart';
import '../../services/student_repository.dart';
import '../../scanner/models/student_model.dart';

/// Month-report and Single Leave Application PDF generation for NIFT Hostel.
class PdfService {
  /// Robust image resolver for Base64 (with or without data URI prefix) and remote URLs.
  static Future<pw.ImageProvider?> _resolveImage(String? base64Str, String? urlStr) async {
    if (base64Str != null && base64Str.trim().isNotEmpty) {
      try {
        String clean = base64Str.trim();
        if (clean.contains(',')) {
          clean = clean.split(',').last.trim();
        }
        clean = clean.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
        final bytes = base64Decode(clean);
        if (bytes.isNotEmpty) {
          return pw.MemoryImage(bytes);
        }
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
      }
    }

    if (urlStr != null && urlStr.trim().isNotEmpty) {
      try {
        String fullUrl = urlStr.trim();
        if (fullUrl.startsWith('/')) {
          fullUrl = 'https://nifthostelshillong.duckdns.org$fullUrl';
        }
        final res = await http.get(Uri.parse(fullUrl)).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return pw.MemoryImage(res.bodyBytes);
        }
      } catch (e) {
        debugPrint('Error fetching url image: $e');
      }
    }
    return null;
  }

  static Future<void> exportLateEntries({
    required String hostel,
    required DateTime month,
    required List<LateEntryRecord> records,
  }) async {
    final sorted = [...records]..sort((a, b) => b.entryAt.compareTo(a.entryAt));
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final generatedAt =
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _header(hostel, 'Late Entry Report', monthLabel),
          pw.SizedBox(height: 22),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Student Name', 'Roll No', 'Date', 'Time'],
            data: [
              for (var i = 0; i < sorted.length; i++)
                [
                  '${i + 1}',
                  sorted[i].name,
                  sorted[i].rollNo,
                  DateFormat('dd MMM yyyy').format(sorted[i].entryAt),
                  DateFormat('hh:mm a').format(sorted[i].entryAt),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1E3A8A),
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFE2E8F0),
              width: 0.5,
            ),
          ),
          if (sorted.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: pw.Center(
                child: pw.Text(
                  'No late entries recorded for $monthLabel.',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey700),
                ),
              ),
            ),
          pw.SizedBox(height: 36),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total entries: ${sorted.length}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Generated: $generatedAt',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );

    final fileName = 'Late_Entry_Report_${hostel.replaceAll(' ', '_')}_${monthLabel.replaceAll(' ', '_')}.pdf';
    await _deliverPdf(doc, fileName);
  }

  static Future<void> exportLeaveApprovals({
    required String hostel,
    required DateTime month,
    required List<LeaveApprovalRecord> records,
  }) async {
    final sorted = [...records]
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final generatedAt =
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _header(hostel, 'Leave Approval Report', monthLabel),
          pw.SizedBox(height: 22),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Student Name', 'Roll No', 'Date', 'Form Status'],
            data: [
              for (var i = 0; i < sorted.length; i++)
                [
                  '${i + 1}',
                  sorted[i].name,
                  sorted[i].rollNo,
                  DateFormat('dd MMM yyyy').format(sorted[i].appliedAt),
                  ((sorted[i].formImageBase64 == null || sorted[i].formImageBase64!.isEmpty) &&
                   (sorted[i].formImageUrl == null || sorted[i].formImageUrl!.isEmpty))
                      ? 'Not attached'
                      : 'Attached ✓',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1E3A8A),
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFE2E8F0),
              width: 0.5,
            ),
          ),
          if (sorted.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: pw.Center(
                child: pw.Text(
                  'No leave approvals recorded for $monthLabel.',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey700),
                ),
              ),
            ),
          pw.SizedBox(height: 36),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total applications: ${sorted.length}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Generated: $generatedAt',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );

    final fileName = 'Leave_Approval_Report_${hostel.replaceAll(' ', '_')}_${monthLabel.replaceAll(' ', '_')}.pdf';
    await _deliverPdf(doc, fileName);
  }

  /// Single leave application → PDF containing student profile card + photo + attached document.
  static Future<void> exportSingleLeave({
    required LeaveApprovalRecord record,
  }) async {
    final doc = pw.Document();
    final dateLabel = DateFormat('dd MMM yyyy, hh:mm a').format(record.appliedAt);

    // 1. Resolve matched student for missing fields and profile photo
    StudentModel? matchedStudent;
    final allStudents = StudentRepository.studentsNotifier.value;
    final cleanRoll = record.rollNo.replaceAll(RegExp(r'[\/\-\s]'), '').toLowerCase();
    for (final s in allStudents) {
      final sClean = s.rollNo.replaceAll(RegExp(r'[\/\-\s]'), '').toLowerCase();
      if (s.id == record.studentId ||
          s.rollNo.toLowerCase() == record.rollNo.toLowerCase() ||
          (cleanRoll.isNotEmpty && sClean == cleanRoll)) {
        matchedStudent = s;
        break;
      }
    }

    final displayName = record.name.isNotEmpty ? record.name : (matchedStudent?.name ?? 'Student');
    final displayRoll = record.rollNo.isNotEmpty ? record.rollNo : (matchedStudent?.rollNo ?? '—');
    final displayDept = record.department.isNotEmpty ? record.department : (matchedStudent?.department ?? '—');
    final displaySem = record.semester.isNotEmpty ? record.semester : (matchedStudent?.semester ?? '—');
    final displayRoom = record.roomNo.isNotEmpty && record.roomNo != '—' ? record.roomNo : (matchedStudent?.roomNo ?? '—');
    final displayHostel = record.hostel.isNotEmpty ? record.hostel : (matchedStudent?.hostel ?? 'Hostel');

    // 2. Resolve Profile Photo
    final photoSource = (record.photoBase64 != null && record.photoBase64!.isNotEmpty)
        ? record.photoBase64
        : matchedStudent?.profilePhotoBase64;
    final profileImageProvider = await _resolveImage(photoSource, null);

    // 3. Resolve Attached Leave Form Document
    final formImageProvider = await _resolveImage(record.formImageBase64, record.formImageUrl);

    // Page 1: Student Profile Details + Form Preview / Document
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(displayHostel, 'Official Leave Application', dateLabel),
            pw.SizedBox(height: 14),

            // Profile Card with Photo Avatar
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _infoRow('Student Name', displayName),
                        _infoRow('Roll No', displayRoll),
                        _infoRow('Department', displayDept),
                        _infoRow('Semester', displaySem),
                        _infoRow('Room No', displayRoom.isEmpty ? '—' : displayRoom),
                        _infoRow('Hostel', displayHostel),
                        _infoRow('Application Date', dateLabel),
                        _infoRow('Status', 'APPROVED'),
                      ],
                    ),
                  ),
                  if (profileImageProvider != null) ...[
                    pw.SizedBox(width: 14),
                    pw.Container(
                      width: 75,
                      height: 90,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColor.fromInt(0xFF94A3B8), width: 1),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 6,
                        verticalRadius: 6,
                        child: pw.Image(profileImageProvider, fit: pw.BoxFit.cover),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Attached Document Heading
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Attached Leave Application Document',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF1E3A8A),
                  ),
                ),
                pw.Text(
                  formImageProvider != null ? 'Verified Document Attached' : 'No Document Attached',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    color: formImageProvider != null ? PdfColor.fromInt(0xFF16A34A) : PdfColors.grey600,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Attached Document Container
            if (formImageProvider != null)
              pw.Expanded(
                child: pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF1F5F9),
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 1),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Center(
                    child: pw.Image(
                      formImageProvider,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              )
            else
              pw.Container(
                height: 180,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xFFCBD5E1),
                    style: pw.BorderStyle.dashed,
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'No document image was attached to this application record.',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ),
              ),
            
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('NIFT Hostel Administration — Confidential Document',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
      ),
    );

    final fileName = 'Leave_Application_${displayRoll}_${displayName.replaceAll(' ', '_')}.pdf';
    await _deliverPdf(doc, fileName);
  }

  /// Delivers PDF seamlessly across Web, Android, and iOS.
  static Future<void> _deliverPdf(pw.Document doc, String fileName) async {
    try {
      final pdfBytes = await doc.save();

      // On Web, Printing.layoutPdf immediately opens the native browser print/save PDF window
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: fileName,
        );
        return;
      }

      // On mobile devices, share the PDF file directly
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(pdfBytes, name: fileName, mimeType: 'application/pdf')],
            subject: fileName,
          ),
        );
      } catch (_) {
        // Fallback to Printing dialog
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: fileName,
        );
      }
    } catch (e) {
      debugPrint('Error delivering PDF: $e');
    }
  }

  static pw.Widget _header(String hostel, String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'NATIONAL INSTITUTE OF FASHION TECHNOLOGY, SHILLONG',
          style: pw.TextStyle(
            fontSize: 8,
            letterSpacing: 1.1,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF64748B),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '$title — $hostel',
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF0F172A),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: pw.TextStyle(
            fontSize: 9.5,
            color: PdfColor.fromInt(0xFF64748B),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColor.fromInt(0xFFE2E8F0), thickness: 1),
      ],
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 105,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(
            ':  ',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '—' : value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
