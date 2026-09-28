import 'package:flutter/foundation.dart';
import 'models/medicine.dart';
import 'database/database_helper.dart'; // Adjust path if your helper is in a folder (e.g., database/database_helper.dart)

class MedicineProvider with ChangeNotifier {
  List<Medicine> _medicines = [];
  bool _isLoading = false;

  // Getters
  List<Medicine> get medicines => _medicines;
  bool get isLoading => _isLoading; // <-- Fixes 'isLoading' getter error

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

  Future<void> addMedicine(Medicine medicine) async {
    await DatabaseHelper.instance.insertMedicine(medicine);
    await fetchMedicines();
  }

  Future<void> updateMedicine(Medicine medicine) async {
    await DatabaseHelper.instance.updateMedicine(medicine);
    await fetchMedicines();
  }

  Future<void> deleteMedicine(int id) async {
    await DatabaseHelper.instance.deleteMedicine(id);
    await fetchMedicines();
  }
}