import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/text/answer_check.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';

/// Listen, then write it: words and short sentences at the learner's level.
class DictationPage extends StatefulWidget {
  const DictationPage({super.key});

  @override
  State<DictationPage> createState() => _DictationPageState();
}

typedef _Item = ({String fr, String es});

class _DictationPageState extends State<DictationPage> {
  static const _words = 7;
  static const _sentences = 3;

  List<_Item> _items = const [];
  int _index = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    final rng = Random();
    final levels = context.read<SettingsBloc>().state.levelFilter.levels;
    final pool = getIt<WordRepository>().pool(levels: levels)..shuffle(rng);
    final words = pool
        .where((w) => w.french.split(' ').length <= 3)
        .take(_words)
        .map((w) => (fr: _clean(w.french), es: w.translationEs));
    final sentences = pool
        .where((w) {
          final n = w.exampleFr.split(' ').length;
          return n >= 3 && n <= 6;
        })
        .take(_sentences)
        .map((w) => (fr: _clean(w.exampleFr), es: w.exampleEs));
    setState(() {
      _items = [...words, ...sentences];
      _index = 0;
      _correct = 0;
    });
  }

  /// What the learner is asked to type: no closing punctuation.
  static String _clean(String text) =>
      text.replaceAll(RegExp(r'[\s.!?…]+$'), '').trim();

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const PracticeScaffold(title: 'Dictado', child: SizedBox());
    }
    if (_index >= _items.length) {
      return PracticeScaffold(
        title: 'Dictado',
        child: SessionSummary(
          correct: _correct,
          total: _items.length,
          onAgain: _build,
        ),
      );
    }
    final item = _items[_index];
    return PracticeScaffold(
      title: 'Dictado',
      progress: _index / _items.length,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.xl, Insets.page, Insets.xxxl),
        children: [
          Text(
            _index < _words ? 'Escribe la palabra' : 'Escribe la frase',
            textAlign: TextAlign.center,
            style: context.texts.headlineSmall,
          ),
          const SizedBox(height: Insets.xs),
          Text('Puedes escucharla las veces que quieras.',
              textAlign: TextAlign.center, style: context.texts.bodySmall),
          const SizedBox(height: Insets.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpeakButton(key: ValueKey('n$_index'), text: item.fr, size: 72),
              const SizedBox(width: Insets.lg),
              SpeakButton(
                  key: ValueKey('s$_index'),
                  text: item.fr,
                  slow: true,
                  size: 56),
            ],
          ),
          const SizedBox(height: Insets.xl),
          TypedAnswer(
            key: ValueKey(_index),
            expected: item.fr,
            detail: item.es,
            isLast: _index == _items.length - 1,
            hint: 'Lo que oíste',
            onChecked: (match) async {
              if (!match.isRight) return;
              _correct++;
              await getIt<ProgressRepository>()
                  .recordPractice(PracticeKind.dictation);
            },
            onNext: () => setState(() => _index++),
          ),
        ],
      ),
    );
  }
}
