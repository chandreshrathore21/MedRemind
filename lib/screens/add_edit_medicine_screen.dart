import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../medicine_provider.dart';
import '../notification_service.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final Medicine? medicineToEdit;

  const AddEditMedicineScreen({super.key, this.medicineToEdit});

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _countController;

  String _selectedFrequency = 'Daily';
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isAlarmMode = false;
  bool _isSaving = false;

  final List<String> _frequencies = ['Daily', 'Twice Daily', 'Weekly', 'As Needed'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicineToEdit?.name ?? '');
    _countController = TextEditingController(
      text: widget.medicineToEdit?.inventoryCount.toString() ?? '10',
    );

    if (widget.medicineToEdit != null) {
      _selectedFrequency = widget.medicineToEdit!.frequency;
      _isAlarmMode = widget.medicineToEdit!.isAlarm;

      try {
        final timeStr = widget.medicineToEdit!.scheduleTime;
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]) ?? TimeOfDay.now().hour;
          final minute = int.tryParse(parts[1].split(' ')[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? TimeOfDay.now().minute;
          _selectedTime = TimeOfDay(hour: hour, minute: minute);
        }
      } catch (e) {
        debugPrint('Error parsing schedule time: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
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
      final inventory = int.tryParse(_countController.text.trim()) ?? 0;
      final formattedTime =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      final now = DateTime.now();
      final scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final newMedicine = Medicine(
        id: widget.medicineToEdit?.id,
        name: name,
        frequency: frequency,
        inventoryCount: inventory,
        scheduleTime: formattedTime,
        scheduledTime: scheduledDateTime,
        skippedCount: widget.medicineToEdit?.skippedCount ?? 0,
        isAlarm: _isAlarmMode,
      );

      final provider = context.read<MedicineProvider>();

      if (widget.medicineToEdit == null) {
        await provider.addMedicine(newMedicine);
      } else {
        await provider.updateMedicine(newMedicine);
      }

      try {
        final savedMed = provider.medicines.firstWhere(
          (m) => m.name == name,
          orElse: () => newMedicine,
        );

        final notificationId = savedMed.id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

        var notificationScheduleTime = scheduledDateTime;
        if (notificationScheduleTime.isBefore(now)) {
          notificationScheduleTime = notificationScheduleTime.add(const Duration(days: 1));
        }

        await NotificationService().scheduleNotification(
          id: notificationId,
          title: 'Time for $name',
          body: 'Take your scheduled dose of $name ($frequency)',
          hour: notificationScheduleTime.hour,
          minute: notificationScheduleTime.minute,
          isAlarm: _isAlarmMode,
        );
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
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
                controller: _countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Inventory / Stock Count',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter pill count';
                  if (int.tryParse(val.trim()) == null) return 'Enter a valid integer number';
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