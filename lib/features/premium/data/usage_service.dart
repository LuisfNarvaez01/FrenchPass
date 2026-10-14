import 'package:french_pass/core/services/storage_service.dart';

/// What each plan includes. Everything that runs on the phone (word of the
/// day, quiz, reviews, pronunciation) is free and unlimited; these limits
/// only cover what costs money per use: Gemini.
abstract final class UsageLimits {
  /// A one-off taste of the voice tutor, for life.
  static const freeTutor = Duration(minutes: 10);

  /// Premium voice tutor time per calendar month. At roughly US$0.01-0.02
  /// per minute this keeps the heaviest subscriber below what they pay.
  static const premiumTutorPerMonth = Duration(minutes: 150);

  /// Translator and line-study requests per day.
  static const freeAiPerDay = 5;

  /// Generous enough to never get in the way of studying; it only stops a
  /// runaway loop or someone scripting the app.
  static const premiumAiPerDay = 100;
}

/// Counts what the learner has used against [UsageLimits], on the device.
///
/// A client-side meter is enough here because App Check only lets the
/// genuine app reach Gemini: nobody can call the AI from a patched copy
/// that skips these checks.
class UsageService {
  final StorageService _storage;
  final bool Function() _isPremium;
  final DateTime Function() _now;

  UsageService(
    this._storage, {
    required bool Function() isPremium,
    DateTime Function()? clock,
  })  : _isPremium = isPremium,
        _now = clock ?? DateTime.now;

  bool get isPremium => _isPremium();

  // ── Voice tutor ───────────────────────────────────────────────────────────
  /// What's left right now: the free trial, or this month's Premium time.
  Duration tutorTimeLeft() {
    final data = _load();
    if (isPremium) {
      final used = data.month == _monthKey(_now()) ? data.monthSeconds : 0;
      return _left(UsageLimits.premiumTutorPerMonth, used);
    }
    return _left(UsageLimits.freeTutor, data.freeSeconds);
  }

  /// At least half a minute: a session that would end as soon as it opens
  /// isn't worth starting.
  bool get canStartTutor => tutorTimeLeft() >= const Duration(seconds: 30);

  /// Has the free trial been used up (as opposed to never touched)?
  bool get freeTutorUsedUp =>
      _load().freeSeconds >= UsageLimits.freeTutor.inSeconds;

  Future<void> addTutorTime(Duration spent) async {
    if (spent <= Duration.zero) return;
    final data = _load();
    final month = _monthKey(_now());
    if (isPremium) {
      final used = data.month == month ? data.monthSeconds : 0;
      await _save(
          data.copyWith(month: month, monthSeconds: used + spent.inSeconds));
    } else {
      await _save(
          data.copyWith(freeSeconds: data.freeSeconds + spent.inSeconds));
    }
  }

  // ── Translator and line studies ───────────────────────────────────────────
  int aiQueriesLeft() {
    final data = _load();
    final used = data.day == _dayKey(_now()) ? data.dayQueries : 0;
    final limit =
        isPremium ? UsageLimits.premiumAiPerDay : UsageLimits.freeAiPerDay;
    return (limit - used).clamp(0, limit);
  }

  bool get canUseAi => aiQueriesLeft() > 0;

  /// Why an AI request was refused, for the learner.
  String get aiLimitMessageEs => isPremium
      ? 'Llegaste a las ${UsageLimits.premiumAiPerDay} consultas de hoy. '
          'Mañana se renuevan.'
      : 'Usaste tus ${UsageLimits.freeAiPerDay} consultas gratis de hoy. '
          'Mañana tienes otras ${UsageLimits.freeAiPerDay}, o con Premium '
          'llegas a ${UsageLimits.premiumAiPerDay} al día.';

  Future<void> addAiQuery() async {
    final data = _load();
    final day = _dayKey(_now());
    final used = data.day == day ? data.dayQueries : 0;
    await _save(data.copyWith(day: day, dayQueries: used + 1));
  }

  // ── Storage ───────────────────────────────────────────────────────────────
  _Usage _load() => _Usage.fromJson(_storage.getJsonMap(StorageKeys.usage));

  Future<void> _save(_Usage data) =>
      _storage.setJsonMap(StorageKeys.usage, data.toJson());

  static Duration _left(Duration limit, int usedSeconds) {
    final left = limit.inSeconds - usedSeconds;
    return Duration(seconds: left < 0 ? 0 : left);
  }

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _dayKey(DateTime d) =>
      '${_monthKey(d)}-${d.day.toString().padLeft(2, '0')}';
}

class _Usage {
  /// Free-trial tutor seconds, ever.
  final int freeSeconds;

  /// Premium tutor seconds in [month] ("2026-10").
  final String month;
  final int monthSeconds;

  /// AI requests on [day] ("2026-10-14").
  final String day;
  final int dayQueries;

  const _Usage({
    this.freeSeconds = 0,
    this.month = '',
    this.monthSeconds = 0,
    this.day = '',
    this.dayQueries = 0,
  });

  factory _Usage.fromJson(Map<String, dynamic> json) {
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    return _Usage(
      freeSeconds: number('freeSeconds'),
      month: json['month'] as String? ?? '',
      monthSeconds: number('monthSeconds'),
      day: json['day'] as String? ?? '',
      dayQueries: number('dayQueries'),
    );
  }

  Map<String, dynamic> toJson() => {
        'freeSeconds': freeSeconds,
        'month': month,
        'monthSeconds': monthSeconds,
        'day': day,
        'dayQueries': dayQueries,
      };

  _Usage copyWith({
    int? freeSeconds,
    String? month,
    int? monthSeconds,
    String? day,
    int? dayQueries,
  }) =>
      _Usage(
        freeSeconds: freeSeconds ?? this.freeSeconds,
        month: month ?? this.month,
        monthSeconds: monthSeconds ?? this.monthSeconds,
        day: day ?? this.day,
        dayQueries: dayQueries ?? this.dayQueries,
      );
}
