import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/otc_medicine.dart';
import '../database/database_helper.dart';
import '../medicine_provider.dart';
import 'add_edit_medicine_screen.dart';

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<MedicineProvider>().fetchMedicines();
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'Not set';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

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
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. OTC / First Aid Stock Card
                  const OtcInventoryBox(),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Scheduled Alarms & Reminders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),

                  // 2. Scheduled Medicines Section
                  if (medProvider.medicines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No reminders set yet.\nTap the + button to add one!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: const Icon(Icons.delete, color: Colors.white, size: 28),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Medication'),
                                    content: Text('Are you sure you want to delete "${med.name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          onDismissed: (direction) {
                            if (med.id != null) {
                              context.read<MedicineProvider>().deleteMedicine(med.id!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${med.name} deleted')),
                              );
                            }
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                          builder: (context) => AddEditMedicineScreen(
                                            medicineToEdit: med,
                                          ),
                                        ),
                                      );
                                      if (mounted) {
                                        context.read<MedicineProvider>().fetchMedicines();
                                      }
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: isLowStock ? Colors.orange : Colors.teal,
                                      child: const Icon(Icons.medication, color: Colors.white),
                                    ),
                                    title: Text(
                                      med.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text('${med.frequency} | Time: ${_formatTime(med.scheduledTime)}'),
                                        const SizedBox(height: 4),
                                        Text(
                                          isOutOfStock
                                              ? 'OUT OF STOCK'
                                              : 'Stock remaining: ${med.inventoryCount}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isLowStock ? Colors.red : Colors.grey[700],
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
                                            color: isOutOfStock ? Colors.grey : Colors.green,
                                            size: 28,
                                          ),
                                          tooltip: 'Take Dose',
                                          onPressed: isOutOfStock || med.id == null
                                              ? null
                                              : () {
                                                  context
                                                      .read<MedicineProvider>()
                                                      .markAsTaken(med.id!);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Took dose of ${med.name}. Remaining: ${med.inventoryCount - 1}'),
                                                      duration: const Duration(seconds: 2),
                                                    ),
                                                  );
                                                },
                                        ),
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
                                      ],
                                    ),
                                  ),
                                  if (med.skippedCount > 0) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.shade700),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
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
                                                  color: Colors.teal, fontWeight: FontWeight.bold),
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
                ],
              ),
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
}

// -------------------------------------------------------------
// OTC INVENTORY BOX WIDGET
// -------------------------------------------------------------
class OtcInventoryBox extends StatefulWidget {
  const OtcInventoryBox({super.key});

  @override
  State<OtcInventoryBox> createState() => _OtcInventoryBoxState();
}

class _OtcInventoryBoxState extends State<OtcInventoryBox> {
  List<OtcMedicine> _otcList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOtcItems();
  }

  Future<void> _loadOtcItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await DatabaseHelper.instance.getAllOtcMedicines();
      if (mounted) {
        setState(() {
          _otcList = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _useOneDose(OtcMedicine med) async {
    if (med.quantity > 0) {
      final updated = OtcMedicine(
        id: med.id,
        name: med.name,
        quantity: med.quantity - 1,
        category: med.category,
        expiryDate: med.expiryDate,
      );
      await DatabaseHelper.instance.updateOtcMedicine(updated);
      if (mounted) {
        _loadOtcItems();
      }
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '10');
    String selectedCategory = 'Painkiller';
    DateTime? selectedExpiry;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add General Medicine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name (e.g. Paracetamol)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Painkiller', 'Fever', 'Cough & Cold', 'First Aid', 'General']
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity / Count',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Expiry Date'),
                  subtitle: Text(
                    selectedExpiry == null
                        ? 'Not set'
                        : '${selectedExpiry!.year}-${selectedExpiry!.month.toString().padLeft(2, '0')}-${selectedExpiry!.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedExpiry = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final newMed = OtcMedicine(
                    name: nameController.text.trim(),
                    quantity: int.tryParse(qtyController.text) ?? 10,
                    category: selectedCategory,
                    expiryDate: selectedExpiry != null
                        ? '${selectedExpiry!.year}-${selectedExpiry!.month.toString().padLeft(2, '0')}-${selectedExpiry!.day.toString().padLeft(2, '0')}'
                        : null,
                  );
                  await DatabaseHelper.instance.insertOtcMedicine(newMed);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (mounted) {
                    _loadOtcItems();
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Save Stock', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.medical_services_outlined, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(
                      'First Aid & Daily Stock Box',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_box, color: Colors.teal, size: 28),
                  tooltip: 'Add OTC Medicine',
                  onPressed: _showAddDialog,
                ),
              ],
            ),
            const Divider(),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _otcList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No OTC stock added yet. Tap + to add painkillers, cough syrup, etc.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _otcList.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _otcList[index];
                          final bool isLow = item.quantity <= 3;
                          final bool isExpired = item.expiryDate != null &&
                              DateTime.tryParse(item.expiryDate!) != null &&
                              DateTime.parse(item.expiryDate!).isBefore(DateTime.now());

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${item.name} (${item.category})',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Qty: ${item.quantity} | Exp: ${item.expiryDate ?? "N/A"}',
                              style: TextStyle(
                                color: isExpired
                                    ? Colors.red
                                    : (isLow ? Colors.orange : Colors.grey[700]),
                                fontWeight: (isLow || isExpired) ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.teal),
                                  tooltip: 'Use 1 Dose',
                                  onPressed: item.quantity == 0 ? null : () => _useOneDose(item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () async {
                                    if (item.id != null) {
                                      await DatabaseHelper.instance.deleteOtcMedicine(item.id!);
                                      if (mounted) {
                                        _loadOtcItems();
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}