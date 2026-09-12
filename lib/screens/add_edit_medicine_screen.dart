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

  final _nameController = TextEditingController();
  final _countController = TextEditingController();

  final List<String> _frequencyOptions = [
    'Once a day',
    'Twice a day',
    'Three times a day',
    'Every 8 hours',
    'Weekly',
    'As needed (PRN)',
  ];

  String _selectedFrequency = 'Once a day';
  List<TimeOfDay> _selectedTimes = [const TimeOfDay(hour: 8, minute: 0)];
  
  // Toggle preference: Standard Notification vs Loud Alarm
  bool _isAlarm = false;

  bool get isEditing => widget.medicineToEdit != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final med = widget.medicineToEdit!;
      _nameController.text = med.name;
      _countController.text = med.inventoryCount.toString();
      _selectedFrequency = _frequencyOptions.contains(med.frequency)
          ? med.frequency
          : _frequencyOptions.first;

      // Reconstruct reminder times from saved schedule string
      _selectedTimes = _parseScheduleTimes(med.scheduleTime);
    }
  }

  // Parse strings like "8:00 AM, 8:00 PM" back into List<TimeOfDay>
  List<TimeOfDay> _parseScheduleTimes(String scheduleStr) {
    if (scheduleStr == 'As Needed' || scheduleStr.isEmpty) {
      return [];
    }

    List<TimeOfDay> times = [];
    final timeParts = scheduleStr.split(',');

    for (var rawPart in timeParts) {
      final part = rawPart.trim();
      try {
        final isPm = part.toUpperCase().contains('PM');
        final isAm = part.toUpperCase().contains('AM');
        final cleanTime = part.replaceAll(RegExp(r'[^\d:]'), '');
        final digits = cleanTime.split(':');

        if (digits.length == 2) {
          int hour = int.parse(digits[0]);
          int minute = int.parse(digits[1]);

          if (isPm && hour < 12) hour += 12;
          if (isAm && hour == 12) hour = 0;

          times.add(TimeOfDay(hour: hour, minute: minute));
        }
      } catch (_) {
        times.add(const TimeOfDay(hour: 8, minute: 0));
      }
    }

    return times.isEmpty ? [const TimeOfDay(hour: 8, minute: 0)] : times;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _updateTimePickerCount(String frequency) {
    setState(() {
      _selectedFrequency = frequency;
      switch (frequency) {
        case 'Twice a day':
          _selectedTimes = [
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 20, minute: 0),
          ];
          break;
        case 'Three times a day':
        case 'Every 8 hours':
          _selectedTimes = [
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 14, minute: 0),
            const TimeOfDay(hour: 20, minute: 0),
          ];
          break;
        case 'As needed (PRN)':
          _selectedTimes = [];
          break;
        case 'Once a day':
        case 'Weekly':
        default:
          _selectedTimes = [const TimeOfDay(hour: 8, minute: 0)];
          break;
      }
    });
  }

  Future<void> _pickTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index],
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  void _saveMedicine() async {
    if (_formKey.currentState!.validate()) {
      final String formattedTimes = _selectedTimes.isEmpty
          ? 'As Needed'
          : _selectedTimes.map((t) => t.format(context)).join(', ');

      final medicineName = _nameController.text.trim();
      final medicine = Medicine(
        id: isEditing ? widget.medicineToEdit!.id : null,
        name: medicineName,
        frequency: _selectedFrequency,
        inventoryCount: int.parse(_countController.text.trim()),
        scheduleTime: formattedTimes,
      );

      final medProvider = context.read<MedicineProvider>();

      if (isEditing) {
        await medProvider.updateMedicine(medicine);
      } else {
        await medProvider.addMedicine(medicine);
      }

      // Schedule reminders (Notification or Alarm based on user choice)
      try {
        final savedMed = medProvider.medicines.firstWhere(
          (m) => m.name == medicineName,
        );

        if (savedMed.id != null && _selectedTimes.isNotEmpty) {
          final notificationService = NotificationService();

          for (int i = 0; i < _selectedTimes.length; i++) {
            final time = _selectedTimes[i];
            final notificationId = (savedMed.id! * 100) + i;

            await notificationService.scheduleNotification(
              id: notificationId,
              title: 'Medication Reminder',
              body: 'Time to take $medicineName!',
              hour: time.hour,
              minute: time.minute,
              isAlarm: _isAlarm, // Dynamic switch parameter
            );
          }
        }
      } catch (e) {
        debugPrint('Notification scheduling error: $e');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medication' : 'Add Medication'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Medicine Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Medicine Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter medicine name' : null,
              ),
              const SizedBox(height: 16),

              // Frequency Dropdown
              DropdownButtonFormField<String>(
                value: _selectedFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency / Schedule',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: _frequencyOptions.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    _updateTimePickerCount(newValue);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Reminder Type Toggle (Notification vs Loud Alarm)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Sound as Loud Alarm',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _isAlarm
                        ? 'Rings continuously on Alarm volume stream'
                        : 'Displays standard banner notification',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isAlarm ? Colors.deepOrange : Colors.grey.shade700,
                    ),
                  ),
                  secondary: Icon(
                    _isAlarm ? Icons.alarm_on : Icons.notifications,
                    color: _isAlarm ? Colors.deepOrange : Colors.teal,
                  ),
                  value: _isAlarm,
                  activeColor: Colors.deepOrange,
                  onChanged: (bool value) {
                    setState(() {
                      _isAlarm = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Reminder Time Pickers
              if (_selectedTimes.isNotEmpty) ...[
                const Text(
                  'Reminder Times',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(_selectedTimes.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      tileColor: Colors.teal.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: const Icon(Icons.access_time, color: Colors.teal),
                      title: Text(
                        'Dose ${index + 1} Time: ${_selectedTimes[index].format(context)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: const Icon(Icons.edit, color: Colors.grey),
                      onTap: () => _pickTime(index),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],

              // Inventory Count
              TextFormField(
                controller: _countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Pill Count / Inventory',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter inventory count';
                  if (int.tryParse(val) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton.icon(
                onPressed: _saveMedicine,
                icon: const Icon(Icons.save),
                label: Text(isEditing ? 'Update Medication' : 'Save Medication'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}