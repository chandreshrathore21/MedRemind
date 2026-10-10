import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'models/medicine.dart';
import 'database/database_helper.dart';
import 'notification_service.dart';

class MedicineProvider with ChangeNotifier {
  List<Medicine> _medicines = [];
  bool _isLoading = false;

  // Getters
  List<Medicine> get medicines => _medicines;
  bool get isLoading => _isLoading;

  /// Fetches stored medicines from SQLite
  Future<void> fetchMedicines() async {
    _isLoading = true;
    notifyListeners();

    try {
      _medicines = await DatabaseHelper.instance.getAllMedicines();
    } catch (e) {
      debugPrint('Error fetching medicines: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new medicine to DB and schedules its notification
  Future<void> addMedicine(Medicine medicine) async {
    try {
      // 1. Insert into database and retrieve auto-incremented ID
      final insertedId = await DatabaseHelper.instance.insertMedicine(medicine);

      // 2. Schedule notification if a scheduled time exists
      if (medicine.scheduledTime != null) {
        await NotificationService().scheduleNotification(
  id: insertedId,
  title: medicine.name,
  body: 'Time to take your ${medicine.dosage}',
  hour: medicine.scheduledTime!.hour,
  minute: medicine.scheduledTime!.minute,
  isAlarm: medicine.isAlarm,
);
      }

      // 3. Refresh list in memory
      await fetchMedicines();
    } catch (e) {
      debugPrint('Error adding medicine: $e');
    }
  }

  /// Updates an existing medicine and reschedules its notification
  Future<void> updateMedicine(Medicine medicine) async {
    try {
      await DatabaseHelper.instance.updateMedicine(medicine);

      if (medicine.id != null) {
        // Cancel existing notification
        await NotificationService().cancelNotification(medicine.id!);

        // Reschedule if valid scheduled time exists
        if (medicine.scheduledTime != null) {
          await NotificationService().scheduleNotification(
            id: medicine.id!,
            title: 'Time for ${medicine.name}',
            body: 'Dosage: ${medicine.dosage}. Tap to mark as taken.',
            hour: medicine.scheduledTime!.hour,
            minute: medicine.scheduledTime!.minute,
            isAlarm: medicine.isAlarm,
          );
        }
      }

      await fetchMedicines();
    } catch (e) {
      debugPrint('Error updating medicine: $e');
    }
  }

  /// Deletes a medicine and cancels its scheduled alarm
  Future<void> deleteMedicine(int id) async {
    try {
      await DatabaseHelper.instance.deleteMedicine(id);
      await NotificationService().cancelNotification(id);
      await fetchMedicines();
    } catch (e) {
      debugPrint('Error deleting medicine: $e');
    }
  }

  /// Called when user takes a dose (UI button or notification action)
  Future<void> markAsTaken(int medicineId) async {
    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index != -1) {
      final current = _medicines[index];
      if (current.inventoryCount > 0) {
        final updated = current.copyWith(
          inventoryCount: current.inventoryCount - 1,
        );
        await DatabaseHelper.instance.updateMedicine(updated);
        await fetchMedicines();
      }
    }
  }

  /// Called when user taps "Skipped" on notification
  Future<void> markAsSkipped(int medicineId) async {
    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index != -1) {
      final current = _medicines[index];
      final updated = current.copyWith(
        skippedCount: current.skippedCount + 1,
      );
      await DatabaseHelper.instance.updateMedicine(updated);
      await fetchMedicines();
    }
  }

  /// Clears the warning banner on home screen
  Future<void> clearSkippedWarning(int medicineId) async {
    final index = _medicines.indexWhere((m) => m.id == medicineId);
    if (index != -1) {
      final updated = _medicines[index].copyWith(skippedCount: 0);
      await DatabaseHelper.instance.updateMedicine(updated);
      await fetchMedicines();
    }
  }
}