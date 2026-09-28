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

  // Initialize web database factory for sqflite web support
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        context.read<MedicineProvider>().fetchMedicines();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refreshes UI whenever user returns to the app after background notification actions
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<MedicineProvider>().fetchMedicines();
    }
  }

  // REQUIRED: Implements missing build method
  @override
  Widget build(BuildContext context) {
    final medProvider = context.watch<MedicineProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medication Reminder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                    final bool isLowStock = med.inventoryCount <= 3;
                    final bool isOutOfStock = med.inventoryCount == 0;

                    return Dismissible(
                      key: Key(med.id.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: const Icon(Icons.delete,
                            color: Colors.white, size: 28),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Medication'),
                                content: Text(
                                    'Are you sure you want to delete "${med.name}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (direction) {
                        if (med.id != null) {
                          context
                              .read<MedicineProvider>()
                              .deleteMedicine(med.id!);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${med.name} deleted')),
                          );
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AddEditMedicineScreen(
                                        medicineToEdit: med,
                                      ),
                                    ),
                                  );
                                  if (mounted) {
                                    context
                                        .read<MedicineProvider>()
                                        .fetchMedicines();
                                  }
                                },
                                leading: CircleAvatar(
                                  backgroundColor:
                                      isLowStock ? Colors.orange : Colors.teal,
                                  child: const Icon(Icons.medication,
                                      color: Colors.white),
                                ),
                                title: Text(
                                  med.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                        '${med.frequency} | Time: ${med.scheduleTime}'),
                                    const SizedBox(height: 4),
                                    Text(
                                      isOutOfStock
                                          ? 'OUT OF STOCK'
                                          : 'Stock remaining: ${med.inventoryCount}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isLowStock
                                            ? Colors.red
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.check_circle_outline,
                                        color: isOutOfStock
                                            ? Colors.grey
                                            : Colors.green,
                                        size: 28,
                                      ),
                                      tooltip: 'Take Dose',
                                      onPressed: isOutOfStock || med.id == null
                                          ? null
                                          : () {
                                              context
                                                  .read<MedicineProvider>()
                                                  .markAsTaken(med.id!);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Took dose of ${med.name}. Remaining: ${med.inventoryCount - 1}'),
                                                  duration: const Duration(
                                                      seconds: 2),
                                                ),
                                              );
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.teal),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddEditMedicineScreen(
                                              medicineToEdit: med,
                                            ),
                                          ),
                                        );
                                        if (mounted) {
                                          context
                                              .read<MedicineProvider>()
                                              .fetchMedicines();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Warning Banner for Skipped Doses
                              if (med.skippedCount > 0) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.amber.shade700),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.amber.shade900),
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
                                        onPressed: () {
                                          if (med.id != null) {
                                            context
                                                .read<MedicineProvider>()
                                                .clearSkippedWarning(med.id!);
                                          }
                                        },
                                        child: const Text(
                                          'Dismiss',
                                          style: TextStyle(
                                              color: Colors.teal,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AddEditMedicineScreen()),
          );
          if (mounted) {
            context.read<MedicineProvider>().fetchMedicines();
          }
        },
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Add Medicine', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}