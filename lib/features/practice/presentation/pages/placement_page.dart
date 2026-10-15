import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/mascot.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/features/practice/domain/placement.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// An adaptive test, A1 to C1, that measures the learner's CEFR level and
/// places them on the journey.
class PlacementPage extends StatefulWidget {
  const PlacementPage({super.key});

  @override
  State<PlacementPage> createState() => _PlacementPageState();
}

class _PlacementPageState extends State<PlacementPage> {
  Placement? _placement;

  /// The level being tested and its questions.
  CefrLevel _level = Placement.levels.first;
  List<PlacementQuestion> _block = const [];
  int _index = 0;
  final Map<CefrLevel, List<bool>> _answers = {};
  PlacementResult? _result;
  bool _applied = false;

  Future<void> _start() async {
    final raw = await rootBundle.loadString('assets/data/placement.json');
    final placement = Placement(Placement.parse(raw));
    if (!mounted) return;
    setState(() {
      _placement = placement;
      _level = Placement.levels.first;
      _block = placement.blockFor(_level);
      _index = 0;
      _answers.clear();
      _result = null;
      _applied = false;
    });
  }

  /// After the last question of a level: climb, or finish.
  void _next() {
    if (_index < _block.length - 1) {
      setState(() => _index++);
      return;
    }
    final block = _answers[_level] ?? const [];
    final up = Placement.after(_level);
    if (Placement.passed(block) && up != null) {
      setState(() {
        _level = up;
        _block = _placement!.blockFor(up);
        _index = 0;
      });
    } else {
      setState(() => _result = Placement.score(_answers));
    }
  }

  Future<void> _apply(PlacementResult result) async {
    context
        .read<SettingsBloc>()
        .add(ChangeLevelEvent(Placement.filterFor(result.level)));
    final storage = getIt<StorageService>();
    await storage.setString(
        StorageKeys.placementLevel, (result.level ?? CefrLevel.a1).name);
    if (getIt.isRegistered<PathRepository>()) {
      await getIt<PathRepository>().setStartStage(result.stage);
    }
    await getIt<ProgressRepository>()
        .recordPractice(PracticeKind.placement, count: 5);
    // The tutor starts from this level too.
    final tutor = getIt<TutorRepository>();
    final profile = tutor.profile();
    await tutor.saveProfile(profile.copyWith(
        levelEstimate: '${result.levelLabel} (prueba de nivel)'));
    if (mounted) setState(() => _applied = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_result case final result?) return _resultView(context, result);
    if (_placement == null || _block.isEmpty) return _intro(context);
    final q = _block[_index];
    final levelsDone = Placement.levels.indexOf(_level);
    return PracticeScaffold(
      title: 'Prueba de nivel · ${_level.label}',
      progress: (levelsDone * Placement.perLevel + _index) /
          (Placement.levels.length * Placement.perLevel),
      child: ChoiceQuestion(
        key: ValueKey('${_level.name}-$_index'),
        item: q.item,
        header: _QuestionHeader(question: q),
        isLast: false,
        // Feedback after each answer would teach the test as it goes.
        quiet: true,
        onAnswered: (right) => (_answers[_level] ??= []).add(right),
        onNext: _next,
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
              'Una prueba en serio, del A1 al C1: gramática, vocabulario, '
              'lectura y audio. Cada nivel tiene cinco preguntas y hay que '
              'acertar cuatro para pasar al siguiente. Si dudas, elige la que '
              'te parezca: adivinar no te sube de nivel.',
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

  Widget _resultView(BuildContext context, PlacementResult result) {
    final p = context.palette;
    return PracticeScaffold(
      title: 'Prueba de nivel',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.xl, Insets.page, Insets.xxxl),
        children: [
          const Center(child: MascotCelebration(size: 110)),
          const SizedBox(height: Insets.lg),
          Text('Nivel ${result.levelLabel}',
              textAlign: TextAlign.center,
              style: context.texts.displaySmall?.copyWith(color: p.gold)),
          Text(
              result.level?.descriptionEs ??
                  'Estás empezando: el mejor momento.',
              textAlign: TextAlign.center,
              style: context.texts.titleMedium),
          const SizedBox(height: Insets.sm),
          Text('${result.right} de ${result.total} respuestas correctas.',
              textAlign: TextAlign.center, style: context.texts.bodySmall),
          const SizedBox(height: Insets.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TU VIAJE EMPIEZA EN', style: AppTheme.eyebrow(context)),
                const SizedBox(height: Insets.xs),
                Text(result.stage.nameFr,
                    style: AppTheme.french(context, size: 24)),
                Text(result.stage.nameEs, style: context.texts.titleMedium),
                const SizedBox(height: Insets.xs),
                Text(result.stage.canDoEs, style: context.texts.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          if (_applied) ...[
            InfoNotice(
              icon: Icons.check_circle_rounded,
              iconColor: p.good,
              message: 'Listo: tu viaje y la app ya están en tu nivel.',
            ),
            const SizedBox(height: Insets.md),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('Ir a mi viaje'),
            ),
          ] else
            ElevatedButton(
              onPressed: () => _apply(result),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('Empezar desde aquí'),
            ),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: _start,
            child: const Text('Repetir la prueba'),
          ),
        ],
      ),
    );
  }
}

/// A reading passage or a sound to play, above the question.
class _QuestionHeader extends StatelessWidget {
  final PlacementQuestion question;
  const _QuestionHeader({required this.question});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = switch (question.kind) {
      PlacementKind.grammar => 'GRAMÁTICA',
      PlacementKind.vocab => 'VOCABULARIO',
      PlacementKind.reading => 'LECTURA',
      PlacementKind.listening => 'AUDIO',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.eyebrow(context)),
        if (question.passage case final passage?) ...[
          const SizedBox(height: Insets.sm),
          AppCard(
            child: Text(passage,
                style: context.texts.bodyLarge
                    ?.copyWith(color: p.textPrimary, height: 1.5)),
          ),
        ],
        if (question.listen case final listen?) ...[
          const SizedBox(height: Insets.md),
          Row(
            children: [
              SpeakButton(text: listen, size: 56),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text('Escucha la frase (puedes repetirla)',
                    style: context.texts.bodySmall),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
