import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../database/database_helper.dart';
import 'add_edit_medicine_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Medicine> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  // Directly fetches from SQLite and updates state
  Future<void> _refreshList() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllMedicines();
    setState(() {
      _medicines = data;
      _isLoading = false;
    });
  }

  Future<void> _navigateToAddScreen([Medicine? medicine]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditMedicineScreen(medicineToEdit: medicine),
      ),
    );
    // Unconditionally refresh when coming back
    _refreshList();
  }

  // Manually mark a dose as taken from the UI card
  Future<void> _markAsTaken(Medicine med) async {
    if (med.inventoryCount > 0 && med.id != null) {
      final updatedMed = med.copyWith(
        inventoryCount: med.inventoryCount - 1,
      );
      await DatabaseHelper.instance.updateMedicine(updatedMed);
      _refreshList();
    }
  }

  // Dismisses the skipped warning banner and resets skippedCount
  Future<void> _dismissSkippedWarning(Medicine med) async {
    if (med.id != null) {
      final updatedMed = med.copyWith(skippedCount: 0);
      await DatabaseHelper.instance.updateMedicine(updatedMed);
      _refreshList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminder'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshList,
            tooltip: 'Force Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medicines.isEmpty
              ? const Center(
                  child: Text(
                    'No reminders set yet.\nTap the + button to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _medicines.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final med = _medicines[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.teal.shade50,
                                  child: const Icon(
                                    Icons.medication,
                                    color: Colors.teal,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${med.frequency} | Time: ${med.scheduleTime}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Stock Remaining: ${med.inventoryCount}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: med.inventoryCount <= 5
                                              ? Colors.red
                                              : Colors.teal.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.green,
                                      ),
                                      tooltip: 'Mark as Taken',
                                      onPressed: () => _markAsTaken(med),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.grey,
                                      ),
                                      tooltip: 'Edit',
                                      onPressed: () =>
                                          _navigateToAddScreen(med),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Warning Banner for Skipped Doses
                            if (med.skippedCount > 0) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.amber.shade900,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Warning: ${med.skippedCount} dose(s) marked as skipped!',
                                        style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _dismissSkippedWarning(med),
                                      child: const Text(
                                        'Dismiss',
                                        style: TextStyle(
                                          color: Colors.teal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddScreen(),
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }
}