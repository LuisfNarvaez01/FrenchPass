import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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

  static const defaultTitle = 'Tu palabra del día te espera';
  static const defaultBody = 'Un minuto hoy, una palabra más en tu francés.';

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(await _localTimezone()));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _available = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
      _available = false;
    }
  }

  /// The device's IANA zone ("Europe/Madrid"), so the reminder follows its
  /// daylight-saving changes. Guessing from the UTC offset got this wrong:
  /// Madrid in summer is +2, which the guess mapped to Kyiv (+3).
  Future<String> _localTimezone() async {
    try {
      final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.getLocation(zone); // Throws if the database doesn't know it.
      return zone;
    } catch (e) {
      debugPrint('NotificationService: unknown device zone ($e), using UTC');
      return 'Etc/UTC';
    }
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_available) return false;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// (Re)schedules the daily reminder at [hour]:00 local time, saying
  /// [body] (see ReminderService for what it says). With [ask] false it
  /// never shows the permission prompt: used for the silent refresh on
  /// every app open.
  Future<bool> scheduleDaily({
    required int hour,
    String title = defaultTitle,
    String body = defaultBody,
    bool ask = true,
  }) async {
    await init();
    if (!_available) return false;

    final granted = ask
        ? await requestPermission()
        : await Permission.notification.isGranted;
    if (!granted) return false;

    try {
      await cancelDaily();
      await _plugin.zonedSchedule(
        id: _dailyId,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOf(hour),
        notificationDetails: const NotificationDetails(
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
      await _plugin.cancel(id: _dailyId);
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
