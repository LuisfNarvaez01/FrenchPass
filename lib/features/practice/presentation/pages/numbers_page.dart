import 'dart:math';

import 'package:flutter/material.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/text/answer_check.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/numbers/domain/french_numbers.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';

enum NumbersMode { small, big, time }

extension on NumbersMode {
  String get title => switch (this) {
        NumbersMode.small => 'Del 0 al 100',
        NumbersMode.big => 'Números grandes y años',
        NumbersMode.time => 'La hora',
      };

  String get detail => switch (this) {
        NumbersMode.small => 'Donde están las trampas: 70, 80 y 90.',
        NumbersMode.big => 'Precios, años y cantidades hasta 9 999.',
        NumbersMode.time => 'Horarios de tren y citas, en formato 24 h.',
      };

  IconData get icon => switch (this) {
        NumbersMode.small => Icons.looks_one_outlined,
        NumbersMode.big => Icons.pin_outlined,
        NumbersMode.time => Icons.schedule_rounded,
      };
}

/// Digits only ("1 999" is fine); times accept 14:30, 14h30, 14 30 or
/// 14.30.
AnswerMatch compareNumberAnswer(String typed, String answer) {
  if (!answer.contains(':')) {
    return typed.replaceAll(RegExp(r'\D'), '') == answer
        ? AnswerMatch.exact
        : AnswerMatch.wrong;
  }
  final parts = typed
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s*[h:.\s]\s*'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty || parts.length > 2) return AnswerMatch.wrong;
  final want = answer.split(':').map(int.parse).toList();
  final hour = int.tryParse(parts[0]);
  final minute = parts.length == 2 ? int.tryParse(parts[1]) : 0;
  return hour == want[0] && minute == want[1]
      ? AnswerMatch.exact
      : AnswerMatch.wrong;
}

/// One thing to hear and write: what's said and the digits it stands for.
typedef _Item = ({String spoken, String answer, String written});

/// Listen to a number or a time in French and type it in digits.
class NumbersPage extends StatefulWidget {
  const NumbersPage({super.key});

  @override
  State<NumbersPage> createState() => _NumbersPageState();
}

class _NumbersPageState extends State<NumbersPage> {
  static const _length = 10;

  NumbersMode? _mode;
  List<_Item> _items = const [];
  int _index = 0;
  int _correct = 0;

  void _start(NumbersMode mode) {
    final rng = Random();
    _Item number(int n) {
      final words = FrenchNumbers.toWords(n);
      return (spoken: words, answer: '$n', written: words);
    }

    _Item time() {
      final h = rng.nextInt(24);
      final m =
          [0, 5, 10, 15, 20, 30, 40, 45, 50, rng.nextInt(60)][rng.nextInt(10)];
      final official = FrenchNumbers.timeOfficial(h, m);
      return (
        spoken: 'Il est $official',
        answer: '$h:${m.toString().padLeft(2, '0')}',
        written: 'Il est $official. Al hablar: '
            '${FrenchNumbers.timeEveryday(h, m)}.',
      );
    }

    setState(() {
      _mode = mode;
      _index = 0;
      _correct = 0;
      _items = [
        for (var i = 0; i < _length; i++)
          switch (mode) {
            // Half of them from 60 to 99, where French counting gets odd.
            NumbersMode.small =>
              number(i.isEven ? 60 + rng.nextInt(40) : rng.nextInt(101)),
            NumbersMode.big =>
              number(i < 3 ? 1900 + rng.nextInt(130) : 100 + rng.nextInt(9900)),
            NumbersMode.time => time(),
          },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    if (mode == null) return _menu(context);
    if (_index >= _items.length) {
      return PracticeScaffold(
        title: mode.title,
        child: SessionSummary(
          correct: _correct,
          total: _items.length,
          onAgain: () => _start(mode),
        ),
      );
    }
    final item = _items[_index];
    return PracticeScaffold(
      title: mode.title,
      progress: _index / _items.length,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.xl, Insets.page, Insets.xxxl),
        children: [
          Text(
            mode == NumbersMode.time
                ? 'Escribe la hora en cifras'
                : 'Escribe el número en cifras',
            textAlign: TextAlign.center,
            style: context.texts.headlineSmall,
          ),
          const SizedBox(height: Insets.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpeakButton(
                  key: ValueKey('n$_index'), text: item.spoken, size: 72),
              const SizedBox(width: Insets.lg),
              SpeakButton(
                  key: ValueKey('s$_index'),
                  text: item.spoken,
                  slow: true,
                  size: 56),
            ],
          ),
          const SizedBox(height: Insets.xl),
          TypedAnswer(
            key: ValueKey(_index),
            expected: item.answer,
            numeric: true,
            hint: mode == NumbersMode.time ? '14:30' : '71',
            detail: item.written,
            isLast: _index == _items.length - 1,
            compare: (typed) => compareNumberAnswer(typed, item.answer),
            onChecked: (match) async {
              if (!match.isRight) return;
              _correct++;
              await getIt<ProgressRepository>()
                  .recordPractice(PracticeKind.numbers);
            },
            onNext: () => setState(() => _index++),
          ),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final p = context.palette;
    return PracticeScaffold(
      title: 'Números y hora',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.md, Insets.page, Insets.xxxl),
        children: [
          Text(
            'Escuchas un número o una hora en francés y lo escribes en '
            'cifras. Al responder ves cómo se escribe en letras.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          for (final mode in NumbersMode.values) ...[
            AppCard(
              onTap: () => _start(mode),
              child: Row(
                children: [
                  Icon(mode.icon, color: p.gold, size: 28),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mode.title, style: context.texts.titleMedium),
                        Text(mode.detail, style: context.texts.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.textMuted),
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}
