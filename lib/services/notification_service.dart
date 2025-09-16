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

  // ---------------- INIT ----------------
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

    // Android kanal
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);

    _initialized = true;
  }

  // -------------- PERMISSIONS --------------
  static Future<void> requestPermission() async {
    await init();

    if (Platform.isAndroid) {
      // Android 13+ bildirim izni
      await Permission.notification.request();

      // (Varsa) Exact Alarms iznini istemeyi dene (Samsung için kritik)
      try {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestExactAlarmsPermission();
      } catch (_) {
        // Bazı ROM'larda/yeni sürümlerde bu API olmayabilir; sorun değil.
      }
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // -------------- SHOW NOW (DEBUG) --------------
  static Future<void> showNow({
    required String title,
    required String body,
  }) async {
    await init();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 1000000,
      title,
      body,
      details,
    );
  }

  // -------------- PENDING --------------
  static Future<List<PendingNotificationRequest>> pending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }

  // -------------- CANCEL SERIES --------------
  static Future<void> cancelReminderSeries(int baseId) async {
    await init();
    for (var d = 1; d <= 7; d++) {
      await _plugin.cancel(baseId * 10 + d);          // weekly ids
      await _plugin.cancel(baseId * 10 + d + 1000000); // olası one-shot yedek
    }
  }

  // -------------- SCHEDULE WEEKLY (with one-shot first fire) --------------
  static Future<void> scheduleWeeklyReminders({
    required int baseId,
    required String name,
    required int hour,
    required int minute,
    required Set<int> weekdays, // 1=Mon ... 7=Sun (Dart weekday standardı)
    String notes = '',
  }) async {
    await init();

    // Güncelleme durumlarında çakışma olmasın
    await cancelReminderSeries(baseId);

    final payload = jsonEncode({
      'name': name,
      'notes': notes,
      'hour': hour,
      'minute': minute,
      'weekdays': weekdays.toList(),
    });

    final notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
    );

    for (final wd in weekdays) {
      final id = baseId * 10 + wd;                // weekly tekrar eden id
      final when = _nextInstanceOf(hour, minute, wd);

      // ---- One-shot yedek (ilk ateşleme yakınsa) ----
      final now = tz.TZDateTime.now(tz.local);
      if (when.isAfter(now) && when.difference(now) <= const Duration(minutes: 3)) {
        final oneshotId = id + 1000000; // çakışma olmasın diye farklı id
        try {
          await _plugin.zonedSchedule(
            oneshotId,
            'Time to take $name',
            notes.isNotEmpty ? notes : 'Tap to mark as taken',
            when,
            notifDetails,
            androidAllowWhileIdle: true,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
            // DİKKAT: Tek seferlik => matchDateTimeComponents YOK
            payload: payload,
          );
        } catch (_) {
          // one-shot fallback kurulamazsa haftalık olan yine de kurulacak
        }
      }

      // ---- Weekly planlayıcı (tekrar eden) ----
      Future<void> _schedule({required bool exact}) {
        return _plugin.zonedSchedule(
          id,
          'Time to take $name',
          notes.isNotEmpty ? notes : 'Tap to mark as taken',
          when,
          notifDetails,
          androidAllowWhileIdle: true,
          androidScheduleMode:
          exact ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: payload,
        );
      }

      try {
        // Önce exact dene (en güvenilir)
        await _schedule(exact: true);
      } on PlatformException catch (e) {
        // Exact izni yoksa inexact'a düş
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
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // aynı gün saat geçmişse bir gün ekle
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    // hedef hafta gününe gelene kadar gün ekle
    while (scheduled.weekday != wd) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
