import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/entry_models.dart';

/// Month-report PDF generation for Late Entries and Leave Approvals.
/// Uses pure Dart `pdf` + `share_plus` for fast, native document sharing and exporting.
class PdfService {
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

    final pdfBytes = await doc.save();
    final fileName = 'Late_Entry_Report_${hostel.replaceAll(' ', '_')}_${monthLabel.replaceAll(' ', '_')}.pdf';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(pdfBytes, name: fileName, mimeType: 'application/pdf')],
        subject: fileName,
      ),
    );
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
            headers: ['#', 'Student Name', 'Roll No', 'Date', 'Form'],
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

    final pdfBytes = await doc.save();
    final fileName = 'Leave_Approval_Report_${hostel.replaceAll(' ', '_')}_${monthLabel.replaceAll(' ', '_')}.pdf';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(pdfBytes, name: fileName, mimeType: 'application/pdf')],
        subject: fileName,
      ),
    );
  }

  /// Single leave application → PDF containing student details merged
  /// with the attached form image.
  static Future<void> exportSingleLeave({
    required LeaveApprovalRecord record,
  }) async {
    final doc = pw.Document();
    final monthLabel = DateFormat('dd MMM yyyy').format(record.appliedAt);

    pw.ImageProvider? formImageProvider;
    if (record.formImageUrl != null && record.formImageUrl!.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(record.formImageUrl!)).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          formImageProvider = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {}
    } else if (record.formImageBase64 != null && record.formImageBase64!.isNotEmpty) {
      formImageProvider = pw.MemoryImage(base64Decode(record.formImageBase64!));
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(record.hostel, 'Leave Application Form', monthLabel),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow('Student Name', record.name),
                  _infoRow('Roll No', record.rollNo),
                  _infoRow('Department', record.department),
                  _infoRow('Semester', record.semester),
                  _infoRow('Room No', record.roomNo.isEmpty ? '—' : record.roomNo),
                  _infoRow('Hostel', record.hostel),
                  _infoRow('Submitted At',
                      DateFormat('dd MMM yyyy, hh:mm a').format(record.appliedAt)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Attached Application Form',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF1E3A8A),
              ),
            ),
            pw.SizedBox(height: 10),
            if (formImageProvider != null)
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(
                    formImageProvider,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              )
            else
              pw.Container(
                height: 160,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                      color: PdfColor.fromInt(0xFFCBD5E1),
                      style: pw.BorderStyle.dashed),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'No form image attached',
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final pdfBytes = await doc.save();
    final fileName = 'Leave_Application_${record.rollNo}_${record.name.replaceAll(' ', '_')}.pdf';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(pdfBytes, name: fileName, mimeType: 'application/pdf')],
        subject: fileName,
      ),
    );
  }

  static pw.Widget _header(String hostel, String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'NIFT SHILLONG HOSTEL MANAGEMENT',
          style: pw.TextStyle(
            fontSize: 8.5,
            letterSpacing: 1.2,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF64748B),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          '$title — $hostel',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF0F172A),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColor.fromInt(0xFF64748B),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColor.fromInt(0xFFE2E8F0), thickness: 1),
      ],
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(
            ':  ',
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '—' : value,
              style: pw.TextStyle(
                fontSize: 9.5,
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
