import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PrescriptionPdfGenerator {
  static Future<void> generateAndPrintPrescription({
    required Map<String, dynamic> appointment,
    required String doctorName,
  }) async {
    final pdf = pw.Document();
    
    final formattedDate = appointment['completed_at'] != null 
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(appointment['completed_at']).toLocal())
        : DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey, width: 2)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('NIFT Hostel Shillong', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.SizedBox(height: 4),
                        pw.Text('Medical Clinic', style: pw.TextStyle(fontSize: 16, color: PdfColors.blueGrey700)),
                        pw.SizedBox(height: 2),
                        pw.Text('Umsawli, Shillong, Meghalaya', style: pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey500)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(doctorName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.Text('Medical Officer', style: pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey500)),
                        pw.SizedBox(height: 4),
                        pw.Text('Date: $formattedDate', style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Patient Details
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Patient Name:', appointment['student_name'] ?? 'N/A'),
                        pw.SizedBox(height: 8),
                        _buildDetailRow('Roll No:', appointment['student_roll_no'] ?? 'N/A'),
                        pw.SizedBox(height: 8),
                        _buildDetailRow('Department:', appointment['department'] ?? 'N/A'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Hostel:', appointment['hostel'] ?? 'N/A'),
                        pw.SizedBox(height: 8),
                        _buildDetailRow('Room No:', appointment['room_no'] ?? 'N/A'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),

              // Rx Symbol
              pw.Text('Rx', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic, color: PdfColors.blue900)),
              pw.SizedBox(height: 10),

              // Doctor Notes / Diagnosis
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Text(
                  appointment['doctor_notes'] ?? 'No notes provided.',
                  style: const pw.TextStyle(fontSize: 14, lineSpacing: 2),
                ),
              ),
              
              if (appointment['warden_notes'] != null && appointment['warden_notes'].toString().isNotEmpty) ...[
                pw.SizedBox(height: 30),
                pw.Text('Warden Notes / Symptoms:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey)),
                pw.SizedBox(height: 5),
                pw.Text(
                  appointment['warden_notes'],
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ],

              pw.Spacer(),
              
              // Footer / Signature
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(height: 40),
                      pw.Container(width: 150, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 5),
                      pw.Text('Signature / Stamp', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('This is a system generated prescription.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Prescription_${appointment['student_name']?.toString().replaceAll(' ', '_') ?? 'NIFT'}.pdf',
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blueGrey800)),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }
}
