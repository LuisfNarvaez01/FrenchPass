import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/translator/domain/translation.dart';

/// The learner's recent translations, kept so a sentence can be gone over
/// again without paying for another call.
class TranslatorRepository {
  static const _maxHistory = 30;

  final StorageService _storage;
  TranslatorRepository(this._storage);

  /// Newest first.
  List<Translation> history() => _storage
      .getJsonList(StorageKeys.translations)
      .whereType<Map<String, dynamic>>()
      .map(Translation.fromJson)
      .where((t) => t.id.isNotEmpty && t.fr.isNotEmpty)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  /// Saves [translation] on top, replacing an earlier one of the same text.
  Future<void> save(Translation translation) {
    final key = _key(translation.sourceEs);
    final all = [
      translation,
      ...history()
          .where((t) => t.id != translation.id && _key(t.sourceEs) != key),
    ].take(_maxHistory);
    return _storage.setJsonList(
        StorageKeys.translations, [for (final t in all) t.toJson()]);
  }

  /// The saved translation of [text], if it was translated before.
  Translation? find(String text) {
    final key = _key(text);
    for (final t in history()) {
      if (_key(t.sourceEs) == key) return t;
    }
    return null;
  }

  Future<void> delete(String id) => _storage.setJsonList(
        StorageKeys.translations,
        [
          for (final t in history())
            if (t.id != id) t.toJson(),
        ],
      );

  static String _key(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
