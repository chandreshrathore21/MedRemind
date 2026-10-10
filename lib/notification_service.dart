import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Background notification response handler
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) async {
  debugPrint('Background action tapped: ${details.actionId} | Payload: ${details.payload}');
  
  final int? notificationId = details.id;
  if (notificationId == null) return;

  final plugin = FlutterLocalNotificationsPlugin();

  if (details.actionId == 'taken_action') {
    // Mark as taken (Notification is auto-cancelled by action config)
    debugPrint('Medicine $notificationId marked as TAKEN from background');
    // Optional: Add direct database helper call here if needed
  } else if (details.actionId == 'skipped_action') {
    debugPrint('Medicine $notificationId marked as SKIPPED from background');
  } else if (details.actionId == 'snooze_action') {
    // Reschedule the same notification 10 minutes from now
    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    
    // Re-trigger notification 10 minutes later
    await plugin.zonedSchedule(
      id: notificationId,
      title: 'Snoozed Reminder',
      body: 'Time to take your medicine (Snoozed)',
      payload: details.payload,
      scheduledDate: snoozeTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_remind_channel',
          'Medication Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('Medicine $notificationId snoozed for 10 minutes.');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize timezone and notification plugin engine
  Future<void> initNotification() async {
    tz.initializeTimeZones();

    // Bind local timezone with fallback safety
    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {
        // Safe default if location binding fails
      }
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

   await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Foreground action tapped: ${details.actionId}');
        
        final int? id = details.id;
        if (id == null) return;

        if (details.actionId == 'taken_action') {
          debugPrint('Taken action clicked in foreground for ID: $id');
        } else if (details.actionId == 'skipped_action') {
          debugPrint('Skipped action clicked in foreground for ID: $id');
        } else if (details.actionId == 'snooze_action') {
          debugPrint('Snooze action clicked in foreground for ID: $id');
          // Handle foreground snooze logic or call provider method
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Explicit runtime permission requests for Android 12+ / 13+
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  /// Immediate Test Notification to verify system output
  Future<void> showImmediateTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'med_remind_channel',
      'Medication Reminders',
      channelDescription: 'Standard notification reminders for medication',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin.show(
      id: 9999,
      title: 'MedRemind Test',
      body: 'Notifications are working properly!',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Schedule standard notification or persistent alarm
  /// Schedules either a standard notification or persistent sticky alarm
  Future<void> scheduleNotification({
    required int id,
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

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        isAlarm ? 'med_alarm_sticky_v3' : 'med_remind_channel',
        isAlarm ? 'Medication Alarms' : 'Medication Reminders',
        channelDescription: 'Interactive medication reminder notifications',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        ongoing: isAlarm,
        autoCancel: false,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'taken_action',
            'Taken',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            'skipped_action',
            'Skipped',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            'snooze_action',
            'Snooze (10m)',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        payload: id.toString(), // Passing medicine ID as payload string
        scheduledDate: scheduledDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('Successfully scheduled interactive notification ID: $id');
    } catch (e) {
      debugPrint('Error scheduling interactive notification: $e');
    }
  }
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
    debugPrint('Cancelled notification with ID: $id');
  }

  /// Cancels all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint('Cancelled all notifications');
  }
  }