import 'package:french_pass/core/services/notification_service.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';

/// What the daily reminder says, built from where the learner stands:
/// reviews due by the time it fires, then a streak at risk, then the
/// word of the day.
class ReminderService {
  final StorageService _storage;
  final NotificationService _notifications;
  final ProgressRepository _progress;

  ReminderService(this._storage, this._notifications, this._progress);

  /// Reschedules the reminder with fresh text, without ever asking for
  /// permission. Does nothing if the learner turned reminders off.
  Future<void> refresh({DateTime? now}) async {
    final enabled = _storage.getBool(StorageKeys.notificationsEnabled) ?? false;
    if (!enabled) return;
    final hour = _storage.getInt(StorageKeys.notificationHour) ?? 9;
    final at = nextFiring(hour, now ?? DateTime.now());
    final message = messageFor(
      due: _dueBy(at),
      streak: _progress.currentStreak(now: now),
      studiedToday: _progress.studiedToday,
    );
    await _notifications.scheduleDaily(
      hour: hour,
      title: message.title,
      body: message.body,
      ask: false,
    );
  }

  int _dueBy(DateTime at) {
    final day = DateTime(at.year, at.month, at.day);
    return _progress.loadCards().values.where((c) {
      final d = c.nextReviewDate;
      return !DateTime(d.year, d.month, d.day).isAfter(day);
    }).length;
  }

  static DateTime nextFiring(int hour, DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour);
    return today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, hour);
  }

  static ({String title, String body}) messageFor({
    required int due,
    required int streak,
    required bool studiedToday,
  }) {
    if (due > 0) {
      return (
        title: due == 1
            ? 'Tienes 1 palabra para repasar'
            : 'Tienes $due palabras para repasar',
        body: due <= 10
            ? 'Son un par de minutos, y justo ahora es cuando más se fijan.'
            : 'Empieza por diez: el resto puede esperar a mañana.',
      );
    }
    if (streak >= 2 && !studiedToday) {
      return (
        title: 'Llevas $streak días seguidos',
        body: 'Un ejercicio y la racha sigue viva.',
      );
    }
    return (
      title: NotificationService.defaultTitle,
      body: NotificationService.defaultBody,
    );
  }
}
