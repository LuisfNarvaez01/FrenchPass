import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily "palabra del día" reminder.
///
/// Scheduling is inexact on purpose: an exact alarm would require the
/// SCHEDULE_EXACT_ALARM permission, and a vocabulary nudge does not need to
/// land on the second.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _dailyId = 1001;
  static const _channelId = 'frenchpass_daily';

  bool _initialised = false;
  bool _available = false;

  bool get isAvailable => _available;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(await _localTimezone()));

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _available = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
      _available = false;
    }
  }

  /// `timezone` needs an IANA name; the plugin does not expose one, so fall
  /// back to UTC+offset reasoning via the device offset.
  Future<String> _localTimezone() async {
    final offset = DateTime.now().timeZoneOffset;
    // A handful of common zones keep DST correct for most users; everyone else
    // gets a fixed-offset zone, which is accurate enough for a daily reminder.
    const byOffset = {
      -8: 'America/Los_Angeles',
      -7: 'America/Denver',
      -6: 'America/Mexico_City',
      -5: 'America/Bogota',
      -4: 'America/Santiago',
      -3: 'America/Argentina/Buenos_Aires',
      0: 'Etc/UTC',
      1: 'Europe/Paris',
      2: 'Europe/Kyiv',
    };
    return byOffset[offset.inHours] ?? 'Etc/UTC';
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_available) return false;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// (Re)schedules the daily reminder at [hour]:00 local time.
  Future<bool> scheduleDaily({required int hour}) async {
    await init();
    if (!_available) return false;

    final granted = await requestPermission();
    if (!granted) return false;

    try {
      await cancelDaily();
      await _plugin.zonedSchedule(
        _dailyId,
        'Ta palabra del día te espera 🇫🇷',
        'Un minuto hoy, una palabra más en tu francés.',
        _nextInstanceOf(hour),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Palabra del día',
            channelDescription:
                'Recordatorio diario para practicar tu palabra del día.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e) {
      debugPrint('NotificationService.scheduleDaily failed: $e');
      return false;
    }
  }

  Future<void> cancelDaily() async {
    await init();
    if (!_available) return;
    try {
      await _plugin.cancel(_dailyId);
    } catch (e) {
      debugPrint('NotificationService.cancelDaily failed: $e');
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
