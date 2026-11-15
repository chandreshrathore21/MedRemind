import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/dose_log_report_item.dart';
import '../services/pdf_report_service.dart';

class PdfPreviewScreen extends StatelessWidget {
  final List<DoseLogReportItem> logs;
  final DateTime startDate;
  final DateTime endDate;

  const PdfPreviewScreen({
    super.key,
    required this.logs,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Report Preview'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) async {
          final service = PdfReportService();
          return await service.generatePdfBytes(
            logs: logs,
            startDate: startDate,
            endDate: endDate,
          );
        },
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'MedRemind_Consultation_Report.pdf',
      ),
    );
  }
}