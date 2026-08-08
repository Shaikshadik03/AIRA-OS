import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Handle notification tap
        },
      );

      // Create Notification Channels explicitly on Android
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
            'aira_reminders',
            'AIRA Reminders',
            description: 'AIRA OS Assistant Reminders & Notifications',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ));

          await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
            'aira_daily',
            'AIRA Daily Updates',
            description: 'AIRA Daily News & Agenda Notifications',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ));

          // Request permissions via AndroidFlutterLocalNotificationsPlugin
          await androidImpl.requestNotificationsPermission();
          await androidImpl.requestExactAlarmsPermission();
        }

        // Also request via permission_handler for Android 13+
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
      }

      _initialized = true;

      // Automatically schedule 7 AM Morning Briefing and 10 PM Night Check-in
      await scheduleDaily7AmAnd10PmNotifications();
    } catch (_) {}
  }

  NotificationDetails _notificationDetails({String channelId = 'aira_reminders', String channelName = 'AIRA Reminders'}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'AIRA OS Assistant Reminders & Notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
    );
  }

  /// Request permissions on-demand
  Future<bool> requestPermissions() async {
    await initialize();
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// Show instant notification immediately
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    await _notificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(),
      payload: payload,
    );
  }

  /// Schedule notification at specific DateTime
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await initialize();

    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.aira.os/device_control');
        await channel.invokeMethod('scheduleNativeOneTimeAlarm', {
          'id': id,
          'title': title,
          'body': body,
          'timestampMs': scheduledDate.millisecondsSinceEpoch,
        });
      } catch (_) {}
    }

    final tzScheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (_) {
      // Fall back to inexact if exact alarm permission is missing on device
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Schedule daily recurring notification (e.g. 7 AM daily news / agenda)
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await initialize();

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

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _notificationDetails(channelId: 'aira_daily', channelName: 'AIRA Daily Updates'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (_) {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _notificationDetails(channelId: 'aira_daily', channelName: 'AIRA Daily Updates'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    }
  }

  /// Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await initialize();
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Automatically schedule 7:00 AM Morning Briefing and 10:00 PM Night Check-in notifications
  /// Uses native Android AlarmManager (survives Doze mode + phone restarts)
  Future<void> scheduleDaily7AmAnd10PmNotifications() async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel('com.aira.os/device_control');
      await channel.invokeMethod('scheduleDailyBriefings');
    } catch (e) {
      // Fallback to flutter_local_notifications if native call fails
      await scheduleDailyNotification(
        id: 700,
        title: '☀️ AIRA Morning Briefing (7:00 AM)',
        body: 'Good morning! Tap to view your daily schedule, tasks, and agenda briefing.',
        hour: 7,
        minute: 0,
        payload: 'morning_briefing',
      );
      await scheduleDailyNotification(
        id: 2200,
        title: '🌙 AIRA Evening Check-in (10:00 PM)',
        body: 'Good evening! Time to review your completed tasks & prepare for tomorrow.',
        hour: 22,
        minute: 0,
        payload: 'evening_checkin',
      );
    }
  }
}
