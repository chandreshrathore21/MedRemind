class DoseLogReportItem {
  final DateTime scheduledTime;
  final DateTime? takenTime;
  final String medicationName;
  final String dosage;
  final String status; // 'Taken', 'Missed', 'Skipped'
  final int remainingStock;
  final String? notes;

  DoseLogReportItem({
    required this.scheduledTime,
    this.takenTime,
    required this.medicationName,
    required this.dosage,
    required this.status,
    required this.remainingStock,
    this.notes,
  });
}