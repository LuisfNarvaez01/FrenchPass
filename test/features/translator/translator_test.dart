import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/translator/data/translator_repository.dart';
import 'package:french_pass/features/translator/domain/translation.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';

String _wrap(Map<String, dynamic> payload) => jsonEncode(payload);

Translation _t(String id, String es, DateTime date) =>
    Translation(id: id, date: date, sourceEs: es, fr: 'fr $id');

void main() {
  group('TutorReviewService.parseTranslation', () {
    final payload = {
      'fr': 'Où est la gare ?',
      'literalEs': 'Dónde está la estación',
      'words': [
        {'word': 'Où', 'ipa': 'u', 'meaningEs': 'dónde', 'noteEs': 'adverbio'},
        {'word': '', 'ipa': '', 'meaningEs': '', 'noteEs': ''},
      ],
      'alternatives': [
        {
          'register': 'Coloquial',
          'fr': "C'est où, la gare ?",
          'es': '¿Dónde queda la estación?',
          'noteEs': 'Así se pregunta en la calle.',
        },
        {'register': 'Igual', 'fr': 'Où est la gare ?', 'es': '', 'noteEs': ''},
      ],
      'notesEs': ['gare es femenino', '  ', 'b', 'c', 'd'],
    };

    test('keeps the translation and drops empty words', () {
      final t = TutorReviewService.parseTranslation(
        _wrap(payload),
        sourceEs: '¿Dónde está la estación?',
        now: DateTime(2026, 10, 13),
      );
      expect(t.fr, 'Où est la gare ?');
      expect(t.sourceEs, '¿Dónde está la estación?');
      expect(t.words.single.word, 'Où');
      expect(t.id, isNotEmpty);
    });

    test('drops an alternative identical to the main translation', () {
      final t =
          TutorReviewService.parseTranslation(_wrap(payload), sourceEs: 'x');
      expect(t.alternatives.single.register, 'Coloquial');
    });

    test('caps the notes at three and skips blank ones', () {
      final t =
          TutorReviewService.parseTranslation(_wrap(payload), sourceEs: 'x');
      expect(t.notesEs, ['gare es femenino', 'b', 'c']);
    });

    test('rejects an answer without a translation', () {
      expect(
        () => TutorReviewService.parseTranslation(_wrap({'fr': ' '}),
            sourceEs: 'x'),
        throwsFormatException,
      );
    });
  });

  test('Translation JSON round-trips', () {
    final t = Translation(
      id: '1',
      date: DateTime(2026, 10, 13, 8),
      sourceEs: 'Hola',
      fr: 'Salut',
      literalEs: 'Hola',
      words: const [WordGloss(word: 'Salut', ipa: 'saly')],
      alternatives: const [
        PhraseAlternative(register: 'Formal', fr: 'Bonjour', noteEs: 'n'),
      ],
      notesEs: const ['nota'],
    );
    final back = Translation.fromJson(
        jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(back.date, t.date);
    expect(back.words.single.ipa, 'saly');
    expect(back.alternatives.single.fr, 'Bonjour');
    expect(back.notesEs, ['nota']);
    expect(back.glossFor('salut,')?.ipa, 'saly');
  });

  group('TranslatorRepository', () {
    late TranslatorRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = TranslatorRepository(await StorageService.create());
    });

    test('lists newest first', () async {
      await repo.save(_t('a', 'uno', DateTime(2026, 1, 1)));
      await repo.save(_t('b', 'dos', DateTime(2026, 1, 2)));
      expect(repo.history().map((t) => t.id), ['b', 'a']);
    });

    test('finds and replaces the same text ignoring case and spacing',
        () async {
      await repo.save(_t('a', 'Buenos días', DateTime(2026, 1, 1)));
      expect(repo.find('  buenos   DÍAS ')?.id, 'a');
      await repo.save(_t('b', 'buenos días', DateTime(2026, 1, 2)));
      expect(repo.history().map((t) => t.id), ['b']);
    });

    test('deletes by id', () async {
      await repo.save(_t('a', 'uno', DateTime(2026, 1, 1)));
      await repo.save(_t('b', 'dos', DateTime(2026, 1, 2)));
      await repo.delete('a');
      expect(repo.history().map((t) => t.id), ['b']);
    });
  });
}
