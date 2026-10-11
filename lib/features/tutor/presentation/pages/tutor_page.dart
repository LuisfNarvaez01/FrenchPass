import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// The tutor tab: what the tutor knows about you, then the lessons.
class TutorPage extends StatefulWidget {
  const TutorPage({super.key});

  @override
  State<TutorPage> createState() => _TutorPageState();
}

class _TutorPageState extends State<TutorPage> {
  final _repo = getIt<TutorRepository>();

  bool? _hasKey;
  late LearnerProfile _profile;
  late Set<String> _completed;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final key = await _repo.apiKey();
    if (!mounted) return;
    setState(() {
      _hasKey = key != null;
      _profile = _repo.profile();
      _completed = _repo.completedLessonIds();
    });
  }

  Future<void> _open(Lesson lesson) async {
    await context.push('/tutor/${lesson.id}');
    // A finished lesson rewrites the profile and history.
    if (mounted) await _reload();
  }

  Future<void> _openSettings() async {
    await context.push('/settings');
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasKey == null) return const AppLoader();

    final byLevel = <CefrLevel, List<Lesson>>{};
    for (final lesson in Lessons.all.where((l) => !l.isFreeTalk)) {
      byLevel.putIfAbsent(lesson.level, () => []).add(lesson);
    }
    final freeTalk = Lessons.byId(Lessons.freeTalkId)!;

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Insets.page, Insets.xl, Insets.page, Insets.xxxl),
          children: [
            Text('Tutor', style: context.texts.headlineLarge),
            const SizedBox(height: Insets.xs),
            Text(
              'Conversa en francés por voz. Te corrige por escrito sin '
              'cortar la charla.',
              style: context.texts.bodySmall,
            ),
            const SizedBox(height: Insets.xl),
            if (_hasKey == false) ...[
              _KeyMissingCard(onSetUp: _openSettings)
                  .animate()
                  .fadeIn(duration: Motion.base),
              const SizedBox(height: Insets.xl),
            ] else if (!_profile.isEmpty) ...[
              _ProfileCard(
                profile: _profile,
                onReset: () async {
                  await _repo.resetProfile();
                  await _reload();
                },
              ).animate().fadeIn(duration: Motion.base),
              const SizedBox(height: Insets.xl),
            ],
            _LessonTile(
              lesson: freeTalk,
              done: false,
              enabled: _hasKey == true,
              onTap: () => _open(freeTalk),
            ).animate().fadeIn(delay: Motion.stagger(1)),
            for (final (i, entry) in byLevel.entries.indexed) ...[
              const SizedBox(height: Insets.xxl),
              SectionHeader(
                eyebrow: 'Nivel ${entry.key.label}',
                title: entry.key.descriptionEs,
              ),
              const SizedBox(height: Insets.md),
              for (final lesson in entry.value) ...[
                _LessonTile(
                  lesson: lesson,
                  done: _completed.contains(lesson.id),
                  enabled: _hasKey == true,
                  onTap: () => _open(lesson),
                ).animate().fadeIn(delay: Motion.stagger(2 + i)),
                const SizedBox(height: Insets.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyMissingCard extends StatelessWidget {
  final VoidCallback onSetUp;
  const _KeyMissingCard({required this.onSetUp});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_rounded, color: p.gold, size: 22),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text('Conecta tu clave de Gemini',
                    style: context.texts.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'El tutor usa la IA de Google. Pega tu clave una vez en Ajustes; '
            'se guarda cifrada solo en este teléfono.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          ElevatedButton(
            onPressed: onSetUp,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            child: const Text('Ir a Ajustes'),
          ),
        ],
      ),
    );
  }
}

/// "What I know about you": the tutor's memory, made visible so the
/// learner can see -- and wipe -- what it carries between lessons.
class _ProfileCard extends StatelessWidget {
  final LearnerProfile profile;
  final VoidCallback onReset;
  const _ProfileCard({required this.profile, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('LO QUE SÉ DE TI', style: AppTheme.eyebrow(context)),
              ),
              if (profile.levelEstimate.isNotEmpty)
                Pill(label: profile.levelEstimate, tone: p.gold, dense: true),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            '${profile.sessions} '
            '${profile.sessions == 1 ? 'lección' : 'lecciones'} juntos',
            style: context.texts.bodySmall,
          ),
          if (profile.recurringMistakes.isNotEmpty) ...[
            const SizedBox(height: Insets.lg),
            _Bullets(
              title: 'Estamos trabajando',
              icon: Icons.build_circle_outlined,
              tone: p.terracotta,
              items: profile.recurringMistakes.take(3).toList(),
            ),
          ],
          if (profile.pronunciation.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            _Bullets(
              title: 'Pronunciación',
              icon: Icons.record_voice_over_outlined,
              tone: p.warning,
              items: profile.pronunciation.take(2).toList(),
            ),
          ],
          if (profile.strengths.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            _Bullets(
              title: 'Ya dominas',
              icon: Icons.verified_outlined,
              tone: p.good,
              items: profile.strengths.take(3).toList(),
            ),
          ],
          const SizedBox(height: Insets.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _confirmReset(context),
              style: TextButton.styleFrom(foregroundColor: p.textMuted),
              child: const Text('Olvidar y empezar de cero'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar lo que el tutor sabe de ti?'),
        content: const Text(
            'Se borran tu perfil y el historial de lecciones del tutor. Tu '
            'progreso de palabras no se toca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) onReset();
  }
}

class _Bullets extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color tone;
  final List<String> items;

  const _Bullets({
    required this.title,
    required this.icon,
    required this.tone,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: tone),
            const SizedBox(width: Insets.sm),
            Text(title, style: context.texts.labelLarge?.copyWith(color: tone)),
          ],
        ),
        const SizedBox(height: Insets.xs),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(left: Insets.xl, top: 2),
            child: Text('· $item', style: context.texts.bodySmall),
          ),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.done,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AppCard(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg, vertical: Insets.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Text(lesson.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.titleEs,
                      style: context.texts.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(lesson.subtitleEs,
                      style: context.texts.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            if (done)
              Semantics(
                label: 'Completada',
                child:
                    Icon(Icons.check_circle_rounded, color: p.good, size: 20),
              )
            else
              Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
