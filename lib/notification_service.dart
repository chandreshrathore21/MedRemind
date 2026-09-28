import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'database/database_helper.dart';

/// Top-level background action handler executed in a separate isolate
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  debugPrint('Background action tapped: ${notificationResponse.actionId}');

  final int? medId = notificationResponse.payload != null
      ? int.tryParse(notificationResponse.payload!)
      : null;

  if (medId == null) return;

  final db = DatabaseHelper.instance;

  // Execute database operations directly in SQLite
  if (notificationResponse.actionId == 'action_taken') {
    final medicines = await db.getAllMedicines();
    final index = medicines.indexWhere((m) => m.id == medId);
    if (index != -1) {
      final med = medicines[index];
      if (med.inventoryCount > 0) {
        final updated = med.copyWith(inventoryCount: med.inventoryCount - 1);
        await db.updateMedicine(updated);
      }
    }
    if (notificationResponse.id != null) {
      await FlutterLocalNotificationsPlugin().cancel(id: notificationResponse.id!);
    }
  } else if (notificationResponse.actionId == 'action_skipped') {
    final medicines = await db.getAllMedicines();
    final index = medicines.indexWhere((m) => m.id == medId);
    if (index != -1) {
      final med = medicines[index];
      final updated = med.copyWith(skippedCount: med.skippedCount + 1);
      await db.updateMedicine(updated);
    }
    if (notificationResponse.id != null) {
      await FlutterLocalNotificationsPlugin().cancel(id: notificationResponse.id!);
    }
  } else if (notificationResponse.actionId == 'action_snooze') {
    if (notificationResponse.id != null) {
      await FlutterLocalNotificationsPlugin().cancel(id: notificationResponse.id!);
    }
    await NotificationService().snoozeNotification(
      id: notificationResponse.id ?? 999,
      medId: medId,
      title: 'Medication Reminder',
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    tz_data.initializeTimeZones();

    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) async {
        debugPrint('Foreground Action Tapped: ${details.actionId}');
        // Reuse top-level handler to ensure identical DB mutations in foreground
        notificationTapBackground(details);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required int medicineId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    bool isAlarm = false,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Interactive Action Buttons
      final List<AndroidNotificationAction> notificationActions = [
        const AndroidNotificationAction(
          'action_taken',
          'Taken ✓',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'action_snooze',
          'Snooze (10m) ⏰',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'action_skipped',
          'Skipped ✕',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];

      final AndroidNotificationDetails androidDetails = isAlarm
          ? AndroidNotificationDetails(
              'med_alarm_actions_v4',
              'Medication Alarms',
              channelDescription: 'Persistent alarm reminders with actions',
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              enableVibration: true,
              audioAttributesUsage: AudioAttributesUsage.alarm,
              category: AndroidNotificationCategory.alarm,
              fullScreenIntent: true,
              ongoing: true,
              autoCancel: false,
              additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT looping alarm
              actions: notificationActions,
            )
          : AndroidNotificationDetails(
              'med_remind_actions_v4',
              'Medication Reminders',
              channelDescription: 'Standard reminders with action buttons',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              actions: notificationActions,
            );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: medicineId.toString(),
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Schedules a 10-minute snooze reminder
  Future<void> snoozeNotification({
    required int id,
    required int medId,
    required String title,
  }) async {
    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'med_remind_actions_v4',
      'Medication Reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id + 500, // Offset ID to avoid collisions
      title: 'Snoozed: $title',
      body: 'Time to take your snoozed medication dose!',
      scheduledDate: snoozeTime,
      notificationDetails: const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: medId.toString(),
    );
  }
}