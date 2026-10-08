import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Background notification response handler
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) {
  debugPrint('Background action tapped: ${details.actionId}');
  if (details.actionId == 'dismiss_alarm' && details.id != null) {
    FlutterLocalNotificationsPlugin().cancel(id: details.id!);
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
        debugPrint('Tapped: ${details.payload}');
        if (details.actionId == 'dismiss_alarm' && details.id != null) {
          _notificationsPlugin.cancel(id: details.id!);
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
    required DateTime scheduledTime,
    bool isAlarm = false,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      
      // Convert incoming DateTime to TZDateTime
      var scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

      // Roll over to next day if target time passed today
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      debugPrint('=== SCHEDULING REMINDER ===');
      debugPrint('Mode: ${isAlarm ? "LOUD ALARM" : "STANDARD NOTIFICATION"}');
      debugPrint('Current Time: $now');
      debugPrint('Target Time:  $scheduledDate');

      final AndroidNotificationDetails androidDetails = isAlarm
          ? AndroidNotificationDetails(
              'med_alarm_sticky_v3',
              'Medication Alarms',
              channelDescription: 'Persistent alarm reminders for medication',
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              enableVibration: true,
              audioAttributesUsage: AudioAttributesUsage.alarm,
              category: AndroidNotificationCategory.alarm,
              fullScreenIntent: true,
              ongoing: true,
              autoCancel: false,
              additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
              actions: <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  'dismiss_alarm',
                  'Dismiss Alarm',
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
              ],
            )
          : const AndroidNotificationDetails(
              'med_remind_channel',
              'Medication Reminders',
              channelDescription: 'Standard notification reminders for medication',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
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
        scheduledDate: scheduledDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('Successfully registered alarm/notification with system Alarm Manager!');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}