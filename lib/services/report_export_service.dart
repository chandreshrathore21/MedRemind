import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/dose_log_report_item.dart';

class ReportExportService {
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFmt = DateFormat('hh:mm a');

  Map<String, dynamic> _computeSummary(List<DoseLogReportItem> logs) {
    if (logs.isEmpty) {
      return {'total': 0, 'taken': 0, 'missed': 0, 'adherenceRate': '0.0%'};
    }
    final total = logs.length;
    final taken = logs.where((l) => l.status.toLowerCase() == 'taken').length;
    final missed = logs.where((l) => l.status.toLowerCase() == 'missed').length;
    final rate = ((taken / total) * 100).toStringAsFixed(1);

    return {
      'total': total,
      'taken': taken,
      'missed': missed,
      'adherenceRate': '$rate%',
    };
  }

  Future<void> exportToExcel({
    required List<DoseLogReportItem> logs,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = Excel.createExcel();
    const String sheetName = 'Adherence Report';
    excel.rename('Sheet1', sheetName);
    final Sheet sheet = excel[sheetName];

    final summary = _computeSummary(logs);

    // Styling
    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // Title & Summary Block
    sheet.appendRow([TextCellValue('MEDREMIND - CLINICAL ADHERENCE REPORT')]);
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;

    sheet.appendRow([
      TextCellValue('Period:'),
      TextCellValue('${_dateFmt.format(startDate)} to ${_dateFmt.format(endDate)}'),
      TextCellValue('Adherence Rate:'),
      TextCellValue(summary['adherenceRate']),
    ]);
    sheet.appendRow([TextCellValue('')]); // Spacer

    // Table Headers
    final headers = [
      'Date',
      'Scheduled Time',
      'Medication',
      'Dosage',
      'Status',
      'Actual Taken Time',
      'Remaining Stock',
      'Notes',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final int headerRowIndex = sheet.maxRows - 1;
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRowIndex)).cellStyle = headerStyle;
    }

    // Add Data Rows
    for (final item in logs) {
      sheet.appendRow([
        TextCellValue(_dateFmt.format(item.scheduledTime)),
        TextCellValue(_timeFmt.format(item.scheduledTime)),
        TextCellValue(item.medicationName),
        TextCellValue(item.dosage),
        TextCellValue(item.status),
        TextCellValue(item.takenTime != null ? _timeFmt.format(item.takenTime!) : '-'),
        IntCellValue(item.remainingStock),
        TextCellValue(item.notes ?? ''),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/MedRemind_Report.xlsx')
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);

    await Share.shareXFiles([XFile(file.path)], subject: 'MedRemind Adherence Report');
  }
}