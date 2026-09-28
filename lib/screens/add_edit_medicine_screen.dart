import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../medicine_provider.dart';
import '../notification_service.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final Medicine? medicineToEdit;

  const AddEditMedicineScreen({Key? key, this.medicineToEdit}) : super(key: key);

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController countController;

  String _selectedFrequency = 'Daily';
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  // Toggle state for persistent alarm mode
  bool _isAlarmMode = false;
  bool _isSaving = false;

  final List<String> _frequencies = ['Daily', 'Twice Daily', 'Weekly', 'As Needed'];

  @override
void initState() {
  super.initState();
  _nameController = TextEditingController(text: widget.medicineToEdit?.name ?? '');
  countController = TextEditingController(
    text: widget.medicineToEdit?.inventoryCount.toString() ?? '10',
  );

  if (widget.medicineToEdit != null) {
    _selectedFrequency = widget.medicineToEdit!.frequency;
    _isAlarmMode = widget.medicineToEdit!.isAlarm; // Preserves persistent alarm setting
    
    final parts = widget.medicineToEdit!.scheduleTime.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? TimeOfDay.now().hour;
      final minute = int.tryParse(parts[1].split(' ')[0]) ?? TimeOfDay.now().minute;
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    }
  }
}

  @override
  void dispose() {
    _nameController.dispose();
    countController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final frequency = _selectedFrequency;
      final inventory = int.tryParse(countController.text.trim()) ?? 0;
      final formattedTime =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      final newMedicine = Medicine(
        id: widget.medicineToEdit?.id,
        name: name,
        frequency: frequency,
        inventoryCount: inventory,
        scheduleTime: formattedTime,
        skippedCount: widget.medicineToEdit?.skippedCount ?? 0,
        isAlarm: _isAlarmMode, 
      );

      final provider = context.read<MedicineProvider>();

      if (widget.medicineToEdit == null) {
        await provider.addMedicine(newMedicine);
      } else {
        await provider.updateMedicine(newMedicine);
      }

      // Schedule notification or persistent FLAG_INSISTENT alarm
      try {
        final savedMed = provider.medicines.firstWhere(
          (m) => m.name == name,
          orElse: () => newMedicine,
        );

        if (savedMed.id != null) {
          await NotificationService().scheduleNotification(
            id: savedMed.id!,
            medicineId: savedMed.id!,
            title: 'Time for $name',
            body: 'Take your scheduled dose of $name ($frequency)',
            hour: _selectedTime.hour,
            minute: _selectedTime.minute,
            isAlarm: _isAlarmMode, // Passes true for persistent FLAG_INSISTENT looping sound
          );
        }
      } catch (notifErr) {
        debugPrint('Notification warning: $notifErr');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.medicineToEdit == null
                  ? '$name added successfully!'
                  : '$name updated successfully!',
            ),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save medication: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicineToEdit == null ? 'Add Medicine' : 'Edit Medicine'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Medicine Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: _frequencies.map((freq) {
                  return DropdownMenuItem(value: freq, child: Text(freq));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFrequency = val);
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Inventory / Stock Count',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter pill count';
                  if (int.tryParse(val) == null) return 'Enter a valid integer number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.access_time, color: Colors.teal),
                title: const Text('Schedule Time'),
                subtitle: Text(_selectedTime.format(context)),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _pickTime,
              ),
              const SizedBox(height: 16),

              // ===============================================================
              // ALARM MODE TOGGLE SWITCH
              // ===============================================================
              Card(
                elevation: 0,
                color: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: SwitchListTile(
                  secondary: Icon(
                    _isAlarmMode ? Icons.alarm_on : Icons.notifications_active,
                    color: _isAlarmMode ? Colors.red : Colors.teal,
                  ),
                  title: const Text(
                    'Persistent Alarm Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _isAlarmMode
                        ? 'Rings persistently until action taken (FLAG_INSISTENT)'
                        : 'Standard chime notification',
                  ),
                  value: _isAlarmMode,
                  activeColor: Colors.red,
                  onChanged: (val) => setState(() => _isAlarmMode = val),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Medication',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}