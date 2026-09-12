import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/medicine.dart';

class MedicineProvider extends ChangeNotifier {
  List<Medicine> _medicines = [];
  bool _isLoading = false;

  List<Medicine> get medicines => _medicines;
  bool get isLoading => _isLoading;

  // FETCH ALL MEDICINES FROM SQLITE
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

  // ADD NEW MEDICINE
  Future<void> addMedicine(Medicine medicine) async {
    await DatabaseHelper.instance.insertMedicine(medicine);
    await fetchMedicines(); // Automatically refreshes list & notifies UI
  }

  // UPDATE EXISTING MEDICINE
  Future<void> updateMedicine(Medicine medicine) async {
    await DatabaseHelper.instance.updateMedicine(medicine);
    await fetchMedicines(); // Automatically refreshes list & notifies UI
  }

  // DECREMENT STOCK / TAKE DOSE
  Future<void> decrementStock(int id) async {
    await DatabaseHelper.instance.decrementStock(id);
    await fetchMedicines(); // Automatically refreshes list & notifies UI
  }

  // DELETE MEDICINE
  Future<void> deleteMedicine(int id) async {
    await DatabaseHelper.instance.deleteMedicine(id);
    await fetchMedicines(); // Automatically refreshes list & notifies UI
  }

  Future<void> takeDose(Medicine medicine) async {
  if (medicine.inventoryCount > 0) {
    final updatedMed = medicine.copyWith(
      inventoryCount: medicine.inventoryCount - 1,
    );
    await DatabaseHelper.instance.updateMedicine(updatedMed);
    await fetchMedicines(); // Refresh UI state
  }
}
}