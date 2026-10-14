import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/mascot.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/practice/domain/placement.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Fifteen questions that place the learner at A1, A2, B1 or B2 and set
/// the whole app to that level.
class PlacementPage extends StatefulWidget {
  const PlacementPage({super.key});

  @override
  State<PlacementPage> createState() => _PlacementPageState();
}

class _PlacementPageState extends State<PlacementPage> {
  List<PlacementQuestion>? _questions;
  final List<(CefrLevel, bool)> _answers = [];
  int _index = 0;
  bool _applied = false;

  void _start() {
    setState(() {
      _questions =
          Placement.build(getIt<WordRepository>(), getIt<LearningContent>());
      _answers.clear();
      _index = 0;
      _applied = false;
    });
  }

  Future<void> _apply(CefrLevel level) async {
    context
        .read<SettingsBloc>()
        .add(ChangeLevelEvent(Placement.filterFor(level)));
    await getIt<StorageService>()
        .setString(StorageKeys.placementLevel, level.name);
    await getIt<ProgressRepository>()
        .recordPractice(PracticeKind.placement, count: 5);
    // The tutor starts from this level too, unless it already knows better.
    final tutor = getIt<TutorRepository>();
    final profile = tutor.profile();
    if (profile.levelEstimate.isEmpty) {
      await tutor.saveProfile(
          profile.copyWith(levelEstimate: '${level.label} (prueba de nivel)'));
    }
    if (mounted) setState(() => _applied = true);
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    if (questions == null) return _intro(context);
    if (_index >= questions.length) return _result(context);
    final q = questions[_index];
    return PracticeScaffold(
      title: 'Prueba de nivel',
      progress: _index / questions.length,
      child: ChoiceQuestion(
        key: ValueKey(_index),
        item: q.item,
        isLast: _index == questions.length - 1,
        onAnswered: (right) => _answers.add((q.level, right)),
        onNext: () => setState(() => _index++),
      ),
    );
  }

  Widget _intro(BuildContext context) => PracticeScaffold(
        title: 'Prueba de nivel',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Insets.page, Insets.xl, Insets.page, Insets.xxxl),
          children: [
            const Center(
                child: MascotSticker(size: 120, pose: MascotPose.thinking)),
            const SizedBox(height: Insets.xl),
            Text('¿Qué nivel tienes?',
                textAlign: TextAlign.center,
                style: context.texts.headlineMedium),
            const SizedBox(height: Insets.sm),
            Text(
              'Quince preguntas, unos tres minutos. Empiezan fáciles y se '
              'complican; si una no la sabes, elige la que te parezca y '
              'sigue. Al final la app se ajusta a tu nivel.',
              textAlign: TextAlign.center,
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: Insets.xxl),
            ElevatedButton(
              onPressed: _start,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('Empezar'),
            ),
          ],
        ),
      );

  Widget _result(BuildContext context) {
    final p = context.palette;
    final level = Placement.score(_answers);
    final filter = Placement.filterFor(level);
    final right = _answers.where((a) => a.$2).length;
    return PracticeScaffold(
      title: 'Prueba de nivel',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.xl, Insets.page, Insets.xxxl),
        children: [
          const Center(child: MascotCelebration(size: 110)),
          const SizedBox(height: Insets.lg),
          Text('Tu nivel: ${level.label}',
              textAlign: TextAlign.center,
              style: context.texts.displaySmall?.copyWith(color: p.gold)),
          Text(level.descriptionEs,
              textAlign: TextAlign.center, style: context.texts.titleMedium),
          const SizedBox(height: Insets.sm),
          Text('$right de ${_answers.length} respuestas correctas.',
              textAlign: TextAlign.center, style: context.texts.bodySmall),
          const SizedBox(height: Insets.xl),
          AppCard(
            child: Text(
              'La palabra del día, el quiz, el dictado y los demás ejercicios '
              'van a usar palabras de nivel ${filter.labelEs}. Puedes '
              'cambiarlo cuando quieras en Ajustes.',
              style: context.texts.bodySmall,
            ),
          ),
          const SizedBox(height: Insets.xl),
          if (_applied)
            InfoNotice(
              icon: Icons.check_circle_rounded,
              iconColor: p.good,
              message: 'Listo, la app ya está en tu nivel.',
            )
          else
            ElevatedButton(
              onPressed: () => _apply(level),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('Usar este nivel'),
            ),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }
}
