import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Reads the bundled vocabulary corpus and answers the queries the app needs.
///
/// The corpus is a read-only asset, so it is parsed once and kept in memory;
/// everything below is a view over that single list.
class WordRepository {
  static const _assetPath = 'assets/data/words_seed.json';

  List<Word> _words = const [];
  bool _loaded = false;

  List<Word> get all => _words;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rows = (decoded['words'] as List?) ?? const [];

    final parsed = <Word>[];
    var skipped = 0;
    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        skipped++;
        continue;
      }
      final word = Word.tryFromJson(row);
      if (word == null) {
        skipped++;
        continue;
      }
      parsed.add(word);
    }
    if (skipped > 0) {
      debugPrint('WordRepository: skipped $skipped malformed rows');
    }

    _words = parsed;
    _loaded = true;
  }

  Word? byId(String id) {
    for (final word in _words) {
      if (word.id == id) return word;
    }
    return null;
  }

  List<Word> byCategory(WordCategory category) =>
      _words.where((w) => w.category == category).toList();

  List<Word> byLevel(CefrLevel level) =>
      _words.where((w) => w.level == level).toList();

  int countForCategory(WordCategory category) =>
      _words.where((w) => w.category == category).length;

  /// Free-text search over the French word and both translations.
  List<Word> search(String query) {
    final q = _fold(query);
    if (q.isEmpty) return _words;
    return _words
        .where((w) =>
            _fold(w.french).contains(q) ||
            _fold(w.translationEs).contains(q) ||
            _fold(w.translationEn).contains(q))
        .toList();
  }

  /// The word for [date], stable for that calendar day.
  ///
  /// The day number rotates through one fixed permutation of the pool, which
  /// makes *any* run of `pool.length` consecutive days cover the pool exactly
  /// once — not just the runs that happen to start on a cycle boundary. The
  /// permutation is seeded only by the pool size, so the order repeats from one
  /// pass to the next; with a pass lasting months that predictability is worth
  /// more than a reshuffle that would let a word recur across the seam.
  ///
  /// Being a pure function of the date, it also gives the same answer anywhere
  /// — including a home-screen widget with no shared state.
  Word? wordOfTheDay(DateTime date, {Set<CefrLevel>? levels}) {
    final pool = (levels == null || levels.isEmpty)
        ? _words
        : _words.where((w) => levels.contains(w.level)).toList();
    if (pool.isEmpty) return null;

    final order = List<int>.generate(pool.length, (i) => i)
      ..shuffle(Random(_shuffleSeed + pool.length));
    return pool[order[_dayNumber(date) % pool.length]];
  }

  /// Bumping this reshuffles the daily order for everyone; it is fixed so the
  /// sequence stays stable across releases.
  static const _shuffleSeed = 7919;

  /// [count] wrong-answer candidates for [target], preferring same-category
  /// words so the quiz stays discriminating rather than trivially easy.
  List<Word> distractorsFor(
    Word target, {
    int count = 3,
    int? seed,
  }) {
    final random = Random(seed ?? target.id.hashCode);
    final sameCategory = _words
        .where((w) => w.id != target.id && w.category == target.category)
        .toList()
      ..shuffle(random);
    final others = _words
        .where((w) => w.id != target.id && w.category != target.category)
        .toList()
      ..shuffle(random);

    final picked = <Word>[];
    for (final candidate in [...sameCategory, ...others]) {
      if (picked.length == count) break;
      // Avoid two options that read as the same answer.
      if (picked.any((w) => w.translationEs == candidate.translationEs)) {
        continue;
      }
      if (candidate.translationEs == target.translationEs) continue;
      picked.add(candidate);
    }
    return picked;
  }

  /// Pool for a practice or quiz session, newest-first by level difficulty.
  List<Word> pool({Set<CefrLevel>? levels, WordCategory? category}) {
    return _words.where((w) {
      if (levels != null && levels.isNotEmpty && !levels.contains(w.level)) {
        return false;
      }
      if (category != null && w.category != category) return false;
      return true;
    }).toList();
  }

  static int _dayNumber(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .difference(DateTime(2026, 1, 1))
          .inDays
          .abs();

  /// Lowercase + strip accents, so "cafe" matches "café".
  static String _fold(String input) {
    const from = 'àâäéèêëîïôöùûüÿçñ';
    const to = 'aaaeeeeiioouuuycn';
    var out = input.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }
}
