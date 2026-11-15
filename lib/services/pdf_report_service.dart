import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/dose_log_report_item.dart';

class PdfReportService {
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFmt = DateFormat('hh:mm a');

  Future<Uint8List> generatePdfBytes({
    required List<DoseLogReportItem> logs,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    final total = logs.length;
    final taken = logs.where((l) => l.status.toLowerCase() == 'taken').length;
    final missed = logs.where((l) => l.status.toLowerCase() == 'missed').length;
    final adherenceRate = total > 0 ? ((taken / total) * 100).toStringAsFixed(1) : '0.0';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MEDREMIND CLINICAL REPORT',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Patient Adherence & Medication Log',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text('Generated: ${_dateFmt.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.teal, height: 20),

            // Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Period', '${_dateFmt.format(startDate)} to ${_dateFmt.format(endDate)}'),
                  _buildSummaryItem('Adherence Rate', '$adherenceRate%'),
                  _buildSummaryItem('Taken / Total', '$taken / $total'),
                  _buildSummaryItem('Missed Doses', '$missed'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table Title
            pw.Text('Chronological Dose Log',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),

            // Data Table
            pw.Table.fromTextArray(
              headers: ['Date', 'Time', 'Medication', 'Status', 'Stock', 'Notes'],
              data: logs.map((item) => [
                _dateFmt.format(item.scheduledTime),
                _timeFmt.format(item.scheduledTime),
                '${item.medicationName}\n(${item.dosage})',
                item.status,
                '${item.remainingStock}',
                item.notes ?? '-',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
      ],
    );
  }
}