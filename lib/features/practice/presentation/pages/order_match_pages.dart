import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Put the words of a French sentence back in order.
class OrderSentencePage extends StatefulWidget {
  const OrderSentencePage({super.key});

  @override
  State<OrderSentencePage> createState() => _OrderSentencePageState();
}

class _OrderSentencePageState extends State<OrderSentencePage> {
  static const _length = 8;

  List<Word> _items = const [];
  int _index = 0;
  int _correct = 0;

  /// The shuffled tiles, and the order the learner picked them in.
  List<String> _tiles = const [];
  final List<int> _picked = [];
  bool? _right;

  @override
  void initState() {
    super.initState();
    _build();
  }

  static List<String> tokens(String sentence) => sentence
      .replaceAll(RegExp(r'\s*[.!?…]+$'), '')
      .split(' ')
      .where((t) => t.isNotEmpty)
      .toList();

  void _build() {
    final rng = Random();
    final levels = context.read<SettingsBloc>().state.levelFilter.levels;
    final pool = getIt<WordRepository>().pool(levels: levels)..shuffle(rng);
    setState(() {
      _items = pool
          .where((w) {
            final n = tokens(w.exampleFr).length;
            return n >= 4 && n <= 8;
          })
          .take(_length)
          .toList();
      _index = 0;
      _correct = 0;
      _load();
    });
  }

  void _load() {
    if (_index >= _items.length) return;
    final words = tokens(_items[_index].exampleFr);
    final shuffled = [...words];
    // Never hand out the sentence already in order.
    final rng = Random();
    for (var tries = 0; tries < 10; tries++) {
      shuffled.shuffle(rng);
      if (shuffled.join(' ') != words.join(' ')) break;
    }
    _tiles = shuffled;
    _picked.clear();
    _right = null;
  }

  Future<void> _check() async {
    final want = tokens(_items[_index].exampleFr).join(' ').toLowerCase();
    final got = [for (final i in _picked) _tiles[i]].join(' ').toLowerCase();
    final right = want == got;
    setState(() => _right = right);
    if (right) {
      _correct++;
      await getIt<ProgressRepository>().recordPractice(PracticeKind.order);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const PracticeScaffold(
          title: 'Ordena la frase', child: SizedBox());
    }
    if (_index >= _items.length) {
      return PracticeScaffold(
        title: 'Ordena la frase',
        child: SessionSummary(
            correct: _correct, total: _items.length, onAgain: _build),
      );
    }
    final p = context.palette;
    final item = _items[_index];
    final answered = _right != null;

    Widget tile(String text, {VoidCallback? onTap, bool ghost = false}) =>
        Material(
          color: ghost ? p.surfaceAlt : p.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: Insets.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: ghost ? p.border : p.borderStrong),
              ),
              child: Text(text,
                  style: context.texts.titleMedium
                      ?.copyWith(color: ghost ? Colors.transparent : null)),
            ),
          ),
        );

    return PracticeScaffold(
      title: 'Ordena la frase',
      progress: _index / _items.length,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.lg, Insets.page, Insets.xxxl),
        children: [
          Text('«${item.exampleEs}»',
              style: context.texts.headlineSmall?.copyWith(height: 1.35)),
          const SizedBox(height: Insets.xs),
          Text('Toca las palabras en el orden correcto.',
              style: context.texts.bodySmall),
          const SizedBox(height: Insets.xl),
          // The sentence being built.
          Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: _right == null
                    ? p.border
                    : _right!
                        ? p.good
                        : p.critical,
              ),
            ),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final i in _picked)
                  tile(_tiles[i],
                      onTap: answered
                          ? null
                          : () => setState(() => _picked.remove(i))),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final (i, t) in _tiles.indexed)
                _picked.contains(i)
                    ? tile(t, ghost: true)
                    : tile(t,
                        onTap: answered
                            ? null
                            : () => setState(() => _picked.add(i))),
            ],
          ),
          const SizedBox(height: Insets.xl),
          if (!answered)
            ElevatedButton(
              onPressed: _picked.length == _tiles.length ? _check : null,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('Comprobar'),
            )
          else ...[
            FeedbackBanner(
              right: _right!,
              title: _right! ? 'Correcto' : 'El orden era otro',
              detail: item.exampleFr,
              speak: item.exampleFr,
            ).animate().fadeIn(duration: Motion.fast),
            const SizedBox(height: Insets.lg),
            ElevatedButton(
              onPressed: () => setState(() {
                _index++;
                _load();
              }),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(
                  _index == _items.length - 1 ? 'Ver resultado' : 'Siguiente'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pair each French word with its meaning, five at a time.
class MatchPairsPage extends StatefulWidget {
  const MatchPairsPage({super.key});

  @override
  State<MatchPairsPage> createState() => _MatchPairsPageState();
}

class _MatchPairsPageState extends State<MatchPairsPage> {
  static const _rounds = 3;
  static const _pairs = 5;

  int _round = 0;
  List<Word> _words = const [];
  List<Word> _right = const [];
  final Set<String> _matched = {};
  final Set<String> _missed = {};
  String? _left;
  String? _wrongFlash;
  int _firstTry = 0;

  @override
  void initState() {
    super.initState();
    _newRound(reset: true);
  }

  void _newRound({bool reset = false}) {
    final rng = Random();
    final levels = context.read<SettingsBloc>().state.levelFilter.levels;
    final pool = getIt<WordRepository>().pool(levels: levels)..shuffle(rng);
    // Distinct meanings, so no pair is ambiguous.
    final seen = <String>{};
    final words = <Word>[];
    for (final w in pool) {
      if (seen.add(w.translationEs.toLowerCase())) words.add(w);
      if (words.length == _pairs) break;
    }
    setState(() {
      if (reset) {
        _round = 0;
        _firstTry = 0;
      }
      _words = words;
      _right = [...words]..shuffle(rng);
      _matched.clear();
      _missed.clear();
      _left = null;
    });
  }

  Future<void> _pickRight(Word w) async {
    final left = _left;
    if (left == null || _matched.contains(w.id)) return;
    if (left == w.id) {
      setState(() {
        _matched.add(w.id);
        _left = null;
      });
      if (!_missed.contains(w.id)) _firstTry++;
      await getIt<ProgressRepository>().recordPractice(PracticeKind.match);
      if (_matched.length == _words.length) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        if (_round < _rounds - 1) {
          _round++;
          _newRound();
        } else {
          setState(() => _round = _rounds);
        }
      }
    } else {
      setState(() {
        _missed.add(left);
        _wrongFlash = w.id;
        _left = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _wrongFlash = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_round >= _rounds) {
      return PracticeScaffold(
        title: 'Emparejar',
        child: SessionSummary(
          correct: _firstTry,
          total: _rounds * _pairs,
          onAgain: () => _newRound(reset: true),
        ),
      );
    }
    final p = context.palette;

    Widget cell(String text,
        {required bool done,
        required bool selected,
        required bool wrong,
        required VoidCallback onTap}) {
      final color = done
          ? p.good
          : wrong
              ? p.critical
              : selected
                  ? p.gold
                  : p.border;
      return AnimatedOpacity(
        duration: Motion.fast,
        opacity: done ? 0.35 : 1,
        child: Material(
          color: selected ? p.gold.withValues(alpha: 0.10) : p.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            onTap: done ? null : onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Container(
              height: 64,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: color, width: selected ? 2 : 1),
              ),
              child: Text(text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodyLarge),
            ),
          ),
        ),
      );
    }

    return PracticeScaffold(
      title: 'Emparejar',
      progress: (_round * _pairs + _matched.length) / (_rounds * _pairs),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.lg, Insets.page, Insets.xxxl),
        children: [
          Text('Ronda ${_round + 1} de $_rounds',
              style: context.texts.bodySmall),
          const SizedBox(height: Insets.xs),
          Text('Toca una palabra y luego su significado.',
              style: context.texts.headlineSmall),
          const SizedBox(height: Insets.xl),
          for (var i = 0; i < _words.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: cell(
                    _words[i].french,
                    done: _matched.contains(_words[i].id),
                    selected: _left == _words[i].id,
                    wrong: false,
                    onTap: () => setState(() => _left = _words[i].id),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: cell(
                    _right[i].translationEs,
                    done: _matched.contains(_right[i].id),
                    selected: false,
                    wrong: _wrongFlash == _right[i].id,
                    onTap: () => _pickRight(_right[i]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}
