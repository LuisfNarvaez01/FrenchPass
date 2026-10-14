import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';

List<dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as List<dynamic>;

void main() {
  final content = LearningContent()
    ..loadFrom(
      falseFriends: _read(LearningContent.falseFriendsAsset),
      grammar: _read(LearningContent.grammarAsset),
      readings: _read(LearningContent.readingsAsset),
    );

  void checkItem(ChoiceItem item, String where) {
    expect(item.options.length, greaterThanOrEqualTo(2), reason: where);
    expect(item.answer, inInclusiveRange(0, item.options.length - 1),
        reason: where);
    expect(item.options.toSet().length, item.options.length,
        reason: '$where has a repeated option');
  }

  test('false friends load and none repeats', () {
    expect(content.falseFriends.length, greaterThanOrEqualTo(40));
    final words = content.falseFriends.map((f) => f.fr).toList();
    expect(words.toSet().length, words.length);
    for (final f in content.falseFriends) {
      expect([f.trap, f.means, f.say, f.exampleFr, f.exampleEs],
          everyElement(isNotEmpty));
    }
  });

  test('every grammar exercise has a valid answer', () {
    expect(content.grammar.length, greaterThanOrEqualTo(12));
    final ids = content.grammar.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final topic in content.grammar) {
      expect(topic.exercises.length, 5, reason: topic.id);
      expect(topic.explanation, isNotEmpty, reason: topic.id);
      for (final (i, e) in topic.exercises.indexed) {
        checkItem(e, '${topic.id} #$i');
        // Every prompt has a gap, except "how do you say...?" items.
        if (!e.prompt.startsWith('«')) {
          expect(e.prompt, contains('___'),
              reason: '${topic.id} #$i needs a gap');
        }
      }
    }
  });

  test('every reading has translated sentences and valid questions', () {
    expect(content.readings.length, greaterThanOrEqualTo(12));
    for (final r in content.readings) {
      expect(r.sentences.length, greaterThanOrEqualTo(5), reason: r.id);
      expect(r.questions.length, 3, reason: r.id);
      for (final (i, q) in r.questions.indexed) {
        checkItem(q, '${r.id} #$i');
      }
    }
  });
}
