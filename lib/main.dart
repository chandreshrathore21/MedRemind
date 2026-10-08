import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'medicine_provider.dart';
import 'notification_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database for exact scheduled alarms
  tz.initializeTimeZones();

  // Initialize notification engine & Android permissions
  final notificationService = NotificationService();
  await notificationService.initNotification();

  runApp(
    ChangeNotifierProvider(
      create: (context) => MedicineProvider()..fetchMedicines(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MedRemind',
        home: HomeScreen(),
      ),
    ),
  );
}