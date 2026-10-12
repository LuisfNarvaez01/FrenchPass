import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';

/// The tutor's persistent state: the learner profile, lesson history and
/// the voice choice in preferences, and the Gemini API key in the platform
/// keystore -- the key must never sit in plain preferences or in the APK.
class TutorRepository {
  final StorageService _storage;
  final FlutterSecureStorage _secure;

  TutorRepository(this._storage, [FlutterSecureStorage? secure])
      : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _apiKeyKey = 'fp.tutor.geminiApiKey';
  static const _maxHistory = 60;

  /// Full transcripts are a few KB each; the last handful is what a learner
  /// actually goes back to.
  static const _maxSessions = 8;

  // ── API key ───────────────────────────────────────────────────────────────
  Future<String?> apiKey() async {
    final key = (await _secure.read(key: _apiKeyKey))?.trim();
    return key == null || key.isEmpty ? null : key;
  }

  Future<void> setApiKey(String? key) async {
    final cleaned = cleanApiKey(key);
    if (cleaned == null) {
      await _secure.delete(key: _apiKeyKey);
    } else {
      await _secure.write(key: _apiKeyKey, value: cleaned);
    }
  }

  /// Strips what tends to ride along with a pasted key: whitespace, quotes
  /// and trailing punctuation (a stray "!" is exactly what kept a valid key
  /// failing before).
  static String? cleanApiKey(String? raw) {
    if (raw == null) return null;
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'''^["'`]+|["'`]+$'''), '')
        .replaceAll(RegExp(r'[\s!?,;:]+$'), '')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  // ── Voice ────────────────────────────────────────────────────────────────
  String get voice =>
      _storage.getString(StorageKeys.tutorVoice) ?? TutorVoices.defaultVoice;

  Future<void> setVoice(String voice) =>
      _storage.setString(StorageKeys.tutorVoice, voice);

  // ── Profile ──────────────────────────────────────────────────────────────
  LearnerProfile profile() =>
      LearnerProfile.fromJson(_storage.getJsonMap(StorageKeys.tutorProfile));

  Future<void> saveProfile(LearnerProfile profile) =>
      _storage.setJsonMap(StorageKeys.tutorProfile, profile.toJson());

  Future<void> resetProfile() async {
    await _storage.remove(StorageKeys.tutorProfile);
    await _storage.remove(StorageKeys.tutorHistory);
    await _storage.remove(StorageKeys.tutorSessions);
  }

  // ── History ──────────────────────────────────────────────────────────────
  List<LessonRecord> history() => _storage
      .getJsonList(StorageKeys.tutorHistory)
      .whereType<Map<String, dynamic>>()
      .map(LessonRecord.fromJson)
      .toList();

  Future<void> addRecord(LessonRecord record) {
    final all = [...history(), record];
    final kept =
        all.length > _maxHistory ? all.sublist(all.length - _maxHistory) : all;
    return _storage.setJsonList(
        StorageKeys.tutorHistory, kept.map((r) => r.toJson()).toList());
  }

  // ── Saved conversations ──────────────────────────────────────────────────
  /// Newest first.
  List<SavedSession> sessions() => _storage
      .getJsonList(StorageKeys.tutorSessions)
      .whereType<Map<String, dynamic>>()
      .map(SavedSession.fromJson)
      .where((s) => s.id.isNotEmpty && s.messages.isNotEmpty)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  SavedSession? session(String id) {
    for (final s in sessions()) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Inserts [session], or replaces the saved one with the same id (which
  /// is how studied lines get cached).
  Future<void> saveSession(SavedSession session) {
    final all = [
      session,
      ...sessions().where((s) => s.id != session.id),
    ].take(_maxSessions);
    return _storage.setJsonList(
        StorageKeys.tutorSessions, [for (final s in all) s.toJson()]);
  }

  /// Lesson ids the learner has completed at least once (goal reached).
  Set<String> completedLessonIds() => {
        for (final r in history())
          if (r.goalReached) r.lessonId,
      };
}

/// Gemini's prebuilt voices that sound best in French, labelled for the
/// picker.
abstract final class TutorVoices {
  static const defaultVoice = 'Kore';

  static const all = <(String id, String label)>[
    ('Kore', 'Kore · femenina, clara'),
    ('Aoede', 'Aoede · femenina, cálida'),
    ('Leda', 'Leda · femenina, juvenil'),
    ('Puck', 'Puck · masculina, alegre'),
    ('Charon', 'Charon · masculina, grave'),
    ('Orus', 'Orus · masculina, firme'),
  ];

  static String labelFor(String id) {
    for (final (voiceId, label) in all) {
      if (voiceId == id) return label;
    }
    return id;
  }
}
