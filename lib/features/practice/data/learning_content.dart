import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// A multiple-choice item: grammar exercises, reading questions, the
/// placement test.
class ChoiceItem {
  final String prompt;
  final List<String> options;
  final int answer;

  /// Why the answer is right, shown after answering.
  final String why;

  const ChoiceItem({
    required this.prompt,
    required this.options,
    required this.answer,
    this.why = '',
  });

  factory ChoiceItem.fromJson(Map<String, dynamic> json) => ChoiceItem(
        prompt: (json['prompt'] ?? json['q']) as String,
        options: [for (final o in json['options'] as List) o as String],
        answer: json['answer'] as int,
        why: json['why'] as String? ?? '',
      );

  String get correct => options[answer];
}

/// A French phrase with its Spanish meaning.
typedef Bilingual = ({String fr, String es});

Bilingual _bilingual(Object? raw) {
  final m = raw as Map<String, dynamic>;
  return (fr: m['fr'] as String, es: m['es'] as String);
}

CefrLevel _level(Object? raw) =>
    CefrLevelExtension.parse(raw as String? ?? '') ?? CefrLevel.a1;

/// A French word that looks Spanish and means something else.
class FalseFriend {
  final String fr;

  /// The Spanish word it looks like (what a learner guesses).
  final String trap;

  /// What it actually means.
  final String means;

  /// How to say what the learner guessed.
  final String say;
  final String exampleFr;
  final String exampleEs;
  final CefrLevel level;

  const FalseFriend({
    required this.fr,
    required this.trap,
    required this.means,
    required this.say,
    required this.exampleFr,
    required this.exampleEs,
    required this.level,
  });

  factory FalseFriend.fromJson(Map<String, dynamic> json) => FalseFriend(
        fr: json['fr'] as String,
        trap: json['trap'] as String,
        means: json['means'] as String,
        say: json['say'] as String,
        exampleFr: json['example_fr'] as String,
        exampleEs: json['example_es'] as String,
        level: _level(json['level']),
      );
}

class GrammarTopic {
  final String id;
  final String title;
  final CefrLevel level;
  final String summary;
  final List<String> explanation;
  final List<Bilingual> examples;
  final List<ChoiceItem> exercises;

  const GrammarTopic({
    required this.id,
    required this.title,
    required this.level,
    required this.summary,
    required this.explanation,
    required this.examples,
    required this.exercises,
  });

  factory GrammarTopic.fromJson(Map<String, dynamic> json) => GrammarTopic(
        id: json['id'] as String,
        title: json['title'] as String,
        level: _level(json['level']),
        summary: json['summary'] as String,
        explanation: [for (final p in json['explanation'] as List) p as String],
        examples: [for (final e in json['examples'] as List) _bilingual(e)],
        exercises: [
          for (final e in json['exercises'] as List)
            ChoiceItem.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class Reading {
  final String id;
  final String title;
  final CefrLevel level;
  final List<Bilingual> sentences;
  final List<ChoiceItem> questions;

  const Reading({
    required this.id,
    required this.title,
    required this.level,
    required this.sentences,
    required this.questions,
  });

  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
        id: json['id'] as String,
        title: json['title'] as String,
        level: _level(json['level']),
        sentences: [for (final s in json['sentences'] as List) _bilingual(s)],
        questions: [
          for (final q in json['questions'] as List)
            ChoiceItem.fromJson(q as Map<String, dynamic>),
        ],
      );

  String get text => sentences.map((s) => s.fr).join(' ');
}

/// The bundled study material beyond the word list: false friends, grammar
/// and graded readings. Small enough to load once at startup.
class LearningContent {
  List<FalseFriend> falseFriends = const [];
  List<GrammarTopic> grammar = const [];
  List<Reading> readings = const [];

  static const falseFriendsAsset = 'assets/data/false_friends.json';
  static const grammarAsset = 'assets/data/grammar.json';
  static const readingsAsset = 'assets/data/readings.json';

  Future<void> load([AssetBundle? bundle]) async {
    final assets = bundle ?? rootBundle;
    Future<List<dynamic>> read(String path) async =>
        jsonDecode(await assets.loadString(path)) as List<dynamic>;
    loadFrom(
      falseFriends: await read(falseFriendsAsset),
      grammar: await read(grammarAsset),
      readings: await read(readingsAsset),
    );
  }

  void loadFrom({
    required List<dynamic> falseFriends,
    required List<dynamic> grammar,
    required List<dynamic> readings,
  }) {
    this.falseFriends = [
      for (final f in falseFriends)
        FalseFriend.fromJson(f as Map<String, dynamic>),
    ];
    this.grammar = [
      for (final g in grammar) GrammarTopic.fromJson(g as Map<String, dynamic>),
    ];
    this.readings = [
      for (final r in readings) Reading.fromJson(r as Map<String, dynamic>),
    ];
  }

  GrammarTopic? topic(String id) {
    for (final t in grammar) {
      if (t.id == id) return t;
    }
    return null;
  }

  Reading? reading(String id) {
    for (final r in readings) {
      if (r.id == id) return r;
    }
    return null;
  }
}
