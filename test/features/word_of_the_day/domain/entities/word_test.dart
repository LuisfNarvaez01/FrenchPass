import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

void main() {
  Map<String, dynamic> validRow() => {
        'id': 'a1-001',
        'french': 'bonjour',
        'ipa': '[bɔ̃.ʒuʁ]',
        'translation_es': 'Hola',
        'translation_en': 'Hello',
        'example_fr': 'Bonjour !',
        'example_es': '¡Hola!',
        'category': 'daily_life',
        'level': 'a1',
        'word_type': 'expression',
        'audio_asset': null,
      };

  group('Word.tryFromJson', () {
    test('parses a well-formed row', () {
      final word = Word.tryFromJson(validRow());

      expect(word, isNotNull);
      expect(word!.id, 'a1-001');
      expect(word.french, 'bonjour');
      expect(word.category, WordCategory.dailyLife);
      expect(word.level, CefrLevel.a1);
      expect(word.wordType, WordType.expression);
    });

    test('returns null rather than throwing on a row with no id', () {
      final row = validRow()..remove('id');
      expect(Word.tryFromJson(row), isNull);
    });

    test('returns null on an unknown category', () {
      final row = validRow()..['category'] = 'astrophysics';
      expect(Word.tryFromJson(row), isNull);
    });

    test('returns null on an unknown CEFR level', () {
      final row = validRow()..['level'] = 'z9';
      expect(Word.tryFromJson(row), isNull);
    });

    test('tolerates missing optional text fields', () {
      final row = validRow()
        ..remove('example_fr')
        ..remove('translation_en');
      final word = Word.tryFromJson(row);

      expect(word, isNotNull);
      expect(word!.exampleFr, isEmpty);
      expect(word.translationEn, isEmpty);
    });

    test('ipaBare strips the dataset brackets', () {
      final word = Word.tryFromJson(validRow())!;
      expect(word.ipaBare, 'bɔ̃.ʒuʁ');
    });
  });

  group('category keys', () {
    test('every category round-trips through its dataset key', () {
      for (final category in WordCategory.values) {
        expect(WordCategoryExtension.parse(category.key), category,
            reason: 'key "${category.key}" should parse back');
      }
    });

    test('every level round-trips through its dataset name', () {
      for (final level in CefrLevel.values) {
        expect(CefrLevelExtension.parse(level.name), level);
      }
    });
  });
}
