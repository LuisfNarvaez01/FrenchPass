import 'package:equatable/equatable.dart';

enum CefrLevel { a1, a2, b1, b2, c1, c2 }

enum WordCategory {
  dailyLife,
  food,
  travel,
  business,
  emotions,
  technology,
  nature,
  culture,
  health,
  home,
  conversation,
  people,
  time,
  shopping,
  education,
  leisure,
}

enum WordType { noun, verb, adjective, adverb, phrase, expression }

extension CefrLevelExtension on CefrLevel {
  String get label => name.toUpperCase();

  String get descriptionEs => switch (this) {
        CefrLevel.a1 => 'Principiante',
        CefrLevel.a2 => 'Básico',
        CefrLevel.b1 => 'Intermedio',
        CefrLevel.b2 => 'Intermedio alto',
        CefrLevel.c1 => 'Avanzado',
        CefrLevel.c2 => 'Maestría',
      };

  /// Parses the `level` field of the seed dataset (`"a1"`, `"b2"`, …).
  static CefrLevel? parse(String raw) {
    final v = raw.trim().toLowerCase();
    for (final level in CefrLevel.values) {
      if (level.name == v) return level;
    }
    return null;
  }
}

extension WordCategoryExtension on WordCategory {
  String get labelEs => switch (this) {
        WordCategory.dailyLife => 'Vida Cotidiana',
        WordCategory.food => 'Comida',
        WordCategory.travel => 'Viajes',
        WordCategory.business => 'Negocios',
        WordCategory.emotions => 'Emociones',
        WordCategory.technology => 'Tecnología',
        WordCategory.nature => 'Naturaleza',
        WordCategory.culture => 'Cultura',
        WordCategory.health => 'Salud',
        WordCategory.home => 'Hogar',
        WordCategory.conversation => 'Conversación',
        WordCategory.people => 'Personas y familia',
        WordCategory.time => 'Tiempo y números',
        WordCategory.shopping => 'Compras y ropa',
        WordCategory.education => 'Estudios',
        WordCategory.leisure => 'Ocio y deporte',
      };

  /// Snake-case key as stored in the seed dataset.
  String get key => switch (this) {
        WordCategory.dailyLife => 'daily_life',
        WordCategory.food => 'food',
        WordCategory.travel => 'travel',
        WordCategory.business => 'business',
        WordCategory.emotions => 'emotions',
        WordCategory.technology => 'technology',
        WordCategory.nature => 'nature',
        WordCategory.culture => 'culture',
        WordCategory.health => 'health',
        WordCategory.home => 'home',
        WordCategory.conversation => 'conversation',
        WordCategory.people => 'people',
        WordCategory.time => 'time',
        WordCategory.shopping => 'shopping',
        WordCategory.education => 'education',
        WordCategory.leisure => 'leisure',
      };

  static WordCategory? parse(String raw) {
    final v = raw.trim().toLowerCase();
    for (final category in WordCategory.values) {
      if (category.key == v) return category;
    }
    return null;
  }
}

extension WordTypeExtension on WordType {
  String get labelEs => switch (this) {
        WordType.noun => 'sustantivo',
        WordType.verb => 'verbo',
        WordType.adjective => 'adjetivo',
        WordType.adverb => 'adverbio',
        WordType.phrase => 'locución',
        WordType.expression => 'expresión',
      };

  static WordType? parse(String raw) {
    final v = raw.trim().toLowerCase();
    for (final type in WordType.values) {
      if (type.name == v) return type;
    }
    return null;
  }
}

class Word extends Equatable {
  final String id;
  final String french;
  final String ipa;
  final String translationEs;
  final String translationEn;
  final String exampleFr;
  final String exampleEs;
  final WordCategory category;
  final CefrLevel level;
  final WordType wordType;
  final String? audioAssetPath;
  final DateTime addedAt;

  const Word({
    required this.id,
    required this.french,
    required this.ipa,
    required this.translationEs,
    required this.translationEn,
    required this.exampleFr,
    required this.exampleEs,
    required this.category,
    required this.level,
    required this.wordType,
    this.audioAssetPath,
    required this.addedAt,
  });

  /// Returns null for rows the dataset got wrong, so one bad entry cannot take
  /// the whole seed load down with it.
  static Word? tryFromJson(Map<String, dynamic> json, {DateTime? addedAt}) {
    final id = json['id'] as String?;
    final french = json['french'] as String?;
    final category = WordCategoryExtension.parse(
        (json['category'] as String?) ?? '');
    final level = CefrLevelExtension.parse((json['level'] as String?) ?? '');
    final type = WordTypeExtension.parse((json['word_type'] as String?) ?? '');

    if (id == null ||
        id.isEmpty ||
        french == null ||
        french.isEmpty ||
        category == null ||
        level == null ||
        type == null) {
      return null;
    }

    return Word(
      id: id,
      french: french,
      ipa: (json['ipa'] as String?) ?? '',
      translationEs: (json['translation_es'] as String?) ?? '',
      translationEn: (json['translation_en'] as String?) ?? '',
      exampleFr: (json['example_fr'] as String?) ?? '',
      exampleEs: (json['example_es'] as String?) ?? '',
      category: category,
      level: level,
      wordType: type,
      audioAssetPath: json['audio_asset'] as String?,
      addedAt: addedAt ?? DateTime.now(),
    );
  }

  /// IPA without the surrounding brackets used in the dataset.
  String get ipaBare => ipa.replaceAll(RegExp(r'^\[|\]$'), '');

  @override
  List<Object?> get props => [id, french, level, category];
}
