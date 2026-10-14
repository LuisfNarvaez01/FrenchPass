import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';

/// The tutor's persistent state, all in preferences: the learner profile,
/// lesson history, saved conversations and the voice choice. There is no
/// API key here: Gemini is reached through Firebase (see `AiBackend`).
class TutorRepository {
  final StorageService _storage;

  TutorRepository(this._storage);

  static const _maxHistory = 60;

  /// Full transcripts are a few KB each; the last handful is what a learner
  /// actually goes back to.
  static const _maxSessions = 8;

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
