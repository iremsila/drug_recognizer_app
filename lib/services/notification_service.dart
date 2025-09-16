import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart'; // PlatformException
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'meds',
    'Medication Reminders',
    description: 'Reminders for taking medicines',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (_initialized) return;

    // Timezone
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const init = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(init);

    // Android channel
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);

    _initialized = true;
  }

  static Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> showNow({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      990000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'debug',
          'Debug',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<List<PendingNotificationRequest>> pending() async {
    return _plugin.pendingNotificationRequests();
  }

  static Future<void> cancelReminderSeries(int baseId) async {
    for (var d = 1; d <= 7; d++) {
      await _plugin.cancel(baseId * 10 + d);
    }
  }

  static Future<void> scheduleWeeklyReminders({
    required int baseId,
    required String name,
    required int hour,
    required int minute,
    required Set<int> weekdays, // 1=Mon ... 7=Sun
    String notes = '',
  }) async {
    for (final wd in weekdays) {
      final id = baseId * 10 + wd;
      final when = _nextInstanceOf(hour, minute, wd);

      Future<void> _schedule({required bool exact}) {
        return _plugin.zonedSchedule(
          id,
          'Time to take $name',
          notes.isNotEmpty ? notes : 'Tap to mark as taken',
          when,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidAllowWhileIdle: true,
          // ⬇️ exact dene; izin yoksa inexact'a düşeceğiz
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle    // <-- doğru
              : AndroidScheduleMode.inexactAllowWhileIdle, // <-- doğru
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: jsonEncode({
            'name': name,
            'notes': notes,
            'hour': hour,
            'minute': minute,
            'weekdays': weekdays.toList(),
          }),
        );
      }

      try {
        await _schedule(exact: true); // önce exact dene
      } on PlatformException catch (e) {
        // Exact izni yoksa sessizce inexact'a düş
        if (Platform.isAndroid && e.code == 'exact_alarms_not_permitted') {
          await _schedule(exact: false);
        } else {
          rethrow;
        }
      }
    }
  }

  // wd: 1..7 (Mon..Sun)
  static tz.TZDateTime _nextInstanceOf(int hour, int minute, int wd) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != wd || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
