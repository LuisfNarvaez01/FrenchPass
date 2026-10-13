import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin typed wrapper over [SharedPreferences].
///
/// FrenchPass stores a few small JSON documents (settings, SRS cards, practice
/// history, favourites) rather than rows in a relational database: the whole
/// corpus is a bundled asset, so the only persistent state is the user's own
/// progress, and it fits comfortably in preferences.
class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  // ── Primitives ────────────────────────────────────────────────────────────
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  // ── JSON documents ────────────────────────────────────────────────────────
  Map<String, dynamic> getJsonMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      // Corrupt entry: drop it rather than crashing on every launch.
      _prefs.remove(key);
      return {};
    }
  }

  Future<void> setJsonMap(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  List<dynamic> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : [];
    } on FormatException {
      _prefs.remove(key);
      return [];
    }
  }

  Future<void> setJsonList(String key, List<dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Set<String> getStringSet(String key) =>
      _prefs.getStringList(key)?.toSet() ?? <String>{};

  Future<void> setStringSet(String key, Set<String> value) =>
      _prefs.setStringList(key, value.toList());

  /// Wipes every FrenchPass key (used by "restablecer progreso").
  Future<void> clearAll() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith(StorageKeys.prefix)) await _prefs.remove(key);
    }
  }
}

abstract final class StorageKeys {
  static const prefix = 'fp.';

  static const themeMode = '${prefix}settings.themeMode';
  static const language = '${prefix}settings.language';
  static const cefrLevel = '${prefix}settings.cefrLevel';
  static const notificationsEnabled = '${prefix}settings.notifications';
  static const notificationHour = '${prefix}settings.notificationHour';
  static const speechRate = '${prefix}settings.speechRate';

  static const srsCards = '${prefix}progress.srsCards';
  static const attempts = '${prefix}progress.attempts';
  static const favorites = '${prefix}progress.favorites';
  static const studiedDays = '${prefix}progress.studiedDays';
  static const quizRuns = '${prefix}progress.quizRuns';
  static const onboardingDone = '${prefix}onboarding.done';

  static const tutorVoice = '${prefix}tutor.voice';
  static const tutorProfile = '${prefix}tutor.profile';
  static const tutorHistory = '${prefix}tutor.history';
  static const tutorSessions = '${prefix}tutor.sessions';

  static const translations = '${prefix}translator.history';
}
