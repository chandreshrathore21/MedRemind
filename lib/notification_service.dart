import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Background action tapped: ${notificationResponse.actionId}');
  if (notificationResponse.actionId == 'dismiss_alarm' && notificationResponse.id != null) {
    FlutterLocalNotificationsPlugin().cancel(id: notificationResponse.id!);
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
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Tapped: ${details.payload}');
        if (details.actionId == 'dismiss_alarm' && details.id != null) {
          _notificationsPlugin.cancel(id: details.id!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  /// Immediate Test Notification to verify system channel output
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

  /// Schedules either a standard notification or persistent sticky alarm based on user preference
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

      debugPrint('=== SCHEDULING REMINDER ===');
      debugPrint('Mode: ${isAlarm ? "LOUD ALARM" : "STANDARD NOTIFICATION"}');
      debugPrint('Current Time: $now');
      debugPrint('Target Time:  $scheduledDate');

      final AndroidNotificationDetails androidDetails = isAlarm
          ? AndroidNotificationDetails(
              'med_alarm_sticky_v3', // Updated channel ID for sticky behavior
              'Medication Alarms',
              channelDescription: 'Persistent alarm reminders for medication',
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              enableVibration: true,
              audioAttributesUsage: AudioAttributesUsage.alarm,
              category: AndroidNotificationCategory.alarm,
              fullScreenIntent: true,
              ongoing: true,        // Prevents user from swiping the notification away
              autoCancel: false,     // Keeps notification alive even if tapped
              additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: Continuous looping audio
              actions: <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  'dismiss_alarm',
                  'Dismiss Alarm',
                  showsUserInterface: true,
                  cancelNotification: true, // ONLY way to stop audio and remove banner
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

      debugPrint('Successfully registered sticky alarm with system Alarm Manager!');
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