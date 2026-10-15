import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/path/domain/journey.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';

/// The journey's content (bundled) and where the learner is on it (saved
/// on the device).
class PathRepository {
  final StorageService _storage;
  PathRepository(this._storage);

  /// New stops a free learner can open per day. Going back over a stop
  /// already done never counts.
  static const freeStopsPerDay = 3;

  List<PathStop> _stops = const [];
  List<PathStop> get stops => _stops;

  Future<void> load({AssetBundle? bundle}) async {
    final raw =
        await (bundle ?? rootBundle).loadString('assets/data/journey.json');
    _stops = parse(raw);
  }

  static List<PathStop> parse(String raw) => [
        for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          PathStop.fromJson(j),
      ];

  @visibleForTesting
  set stopsForTesting(List<PathStop> stops) => _stops = stops;

  PathStop? byId(String id) {
    for (final s in _stops) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<PathStop> stopsIn(Stage stage) => [
        for (final s in _stops)
          if (s.stage == stage) s
      ];

  /// Stages that have lessons in this version of the app.
  Set<Stage> get builtStages => {for (final s in _stops) s.stage};

  // ── Where the learner starts ──────────────────────────────────────────────
  /// Where the journey starts: zero, or wherever the placement test put
  /// them. Stages before it count as passed.
  Stage get startStage =>
      Stage.parse(_storage.getString(StorageKeys.pathStart)) ?? Stage.depart;

  Future<void> setStartStage(Stage stage) =>
      _storage.setString(StorageKeys.pathStart, stage.name);

  /// The stage the learner is in now: the first with a stop left to do,
  /// from where they started.
  Stage get currentStage => next?.stage ?? _firstUnbuiltFrom(startStage);

  Stage _firstUnbuiltFrom(Stage from) {
    for (final s in Stage.values.skip(from.index)) {
      if (!builtStages.contains(s) || stopsIn(s).any((x) => !isDone(x))) {
        return s;
      }
    }
    return Stage.values.last;
  }

  // ── Progress ──────────────────────────────────────────────────────────────
  Set<String> get _done => _storage.getStringSet(StorageKeys.pathDone);

  bool isDone(PathStop stop) => _done.contains(stop.id);

  /// The next stop to do, in order, from the start stage. Null when every
  /// built stop from there is done (the rest of the journey is still to
  /// come in a later version).
  PathStop? get next {
    final done = _done;
    for (final s in _stops) {
      if (s.stage.index < startStage.index) continue;
      if (!done.contains(s.id)) return s;
    }
    return null;
  }

  /// A stop can be opened once it is done (to go over it) or when it is
  /// the next one.
  bool isOpen(PathStop stop) => isDone(stop) || stop.id == next?.id;

  /// How many new stops were finished today.
  int newToday({DateTime? now}) {
    final log = _storage.getJsonMap(StorageKeys.pathLog);
    return (log[ProgressRepository.dayKey(now ?? DateTime.now())] as num?)
            ?.toInt() ??
        0;
  }

  /// Whether a new stop may start now: always on Premium, else up to
  /// [freeStopsPerDay] a day.
  bool canStartNew({required bool premium, DateTime? now}) =>
      premium || newToday(now: now) < freeStopsPerDay;

  /// Marks [stop] done; the first time, it counts for today's allowance.
  Future<void> complete(PathStop stop, {DateTime? now}) async {
    final done = _done;
    if (!done.add(stop.id)) return;
    await _storage.setStringSet(StorageKeys.pathDone, done);
    final key = ProgressRepository.dayKey(now ?? DateTime.now());
    final log = _storage.getJsonMap(StorageKeys.pathLog);
    log[key] = ((log[key] as num?)?.toInt() ?? 0) + 1;
    // Only today matters; older days are dropped.
    log.removeWhere((k, _) => k != key);
    await _storage.setJsonMap(StorageKeys.pathLog, log);
  }

  /// Share of a stage done, 0 to 1.
  double progressIn(Stage stage) {
    final all = stopsIn(stage);
    if (all.isEmpty) return stage.index < startStage.index ? 1 : 0;
    if (stage.index < startStage.index) return 1;
    return all.where(isDone).length / all.length;
  }

  // ── Mistakes (a Premium review) ───────────────────────────────────────────
  /// French items the learner got wrong in lessons, most recent last.
  List<String> get mistakes => [
        for (final m in _storage.getJsonList(StorageKeys.pathMistakes))
          if (m is String) m,
      ];

  Future<void> addMistake(String fr) async {
    final list = mistakes
      ..remove(fr)
      ..add(fr);
    final kept = list.length > 60 ? list.sublist(list.length - 60) : list;
    await _storage.setJsonList(StorageKeys.pathMistakes, kept);
  }

  Future<void> clearMistake(String fr) async {
    final list = mistakes..remove(fr);
    await _storage.setJsonList(StorageKeys.pathMistakes, list);
  }

  /// Every item taught on the journey, to look mistakes up by their French.
  PathItem? itemFor(String fr) {
    for (final s in _stops) {
      for (final i in s.items) {
        if (i.fr == fr) return i;
      }
    }
    return null;
  }
}
