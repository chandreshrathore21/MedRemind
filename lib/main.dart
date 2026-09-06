import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'medicine_provider.dart';
import 'notification_service.dart';
import 'screens/add_edit_medicine_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize web database factory for sqflite 1.x.x
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Initialize notification engine
  final notificationService = NotificationService();
  await notificationService.initNotification();

  runApp(
    ChangeNotifierProvider(
      create: (_) => MedicineProvider(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HomeScreen(),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load stored medicines from SQLite on app startup
    Future.microtask(() {
      if (mounted) {
        context.read<MedicineProvider>().fetchMedicines();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final medProvider = context.watch<MedicineProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<MedicineProvider>().fetchMedicines(),
            tooltip: 'Refresh List',
          ),
        ],
      ),
      body: medProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : medProvider.medicines.isEmpty
              ? const Center(
                  child: Text(
                    'No reminders set yet.\nTap the + button to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: medProvider.medicines.length,
                  itemBuilder: (context, index) {
                    final med = medProvider.medicines[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      child: ListTile(
                        // 1. Tap anywhere on card to edit
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditMedicineScreen(
                                medicineToEdit: med,
                              ),
                            ),
                          );
                          if (mounted) {
                            context.read<MedicineProvider>().fetchMedicines();
                          }
                        },
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.medication, color: Colors.white),
                        ),
                        title: Text(
                          med.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text(
                          '${med.frequency}\nTime: ${med.scheduleTime} | Stock: ${med.inventoryCount}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 2. Edit Button
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.teal),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddEditMedicineScreen(
                                      medicineToEdit: med,
                                    ),
                                  ),
                                );
                                if (mounted) {
                                  context.read<MedicineProvider>().fetchMedicines();
                                }
                              },
                            ),
                            // 3. Delete Button
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () {
                                if (med.id != null) {
                                  _confirmDelete(context, med.id!, med.name);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditMedicineScreen()),
          );
          if (mounted) {
            context.read<MedicineProvider>().fetchMedicines();
          }
        },
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Medicine', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // Confirmation dialog for deleting a record
  void _confirmDelete(BuildContext context, int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<MedicineProvider>().deleteMedicine(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}