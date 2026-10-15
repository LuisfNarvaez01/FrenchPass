import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/ai/ai_backend.dart';
import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/premium/data/billing_service.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';
import 'package:french_pass/features/tutor/presentation/pages/session_review_page.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// The tutor tab: what the tutor knows about you, then the lessons.
class TutorPage extends StatefulWidget {
  const TutorPage({super.key});

  @override
  State<TutorPage> createState() => _TutorPageState();
}

class _TutorPageState extends State<TutorPage> {
  final _repo = getIt<TutorRepository>();

  final _usage = getIt<UsageService>();
  final _billing = getIt<BillingService>();
  final bool _aiReady = AiBackend.isReady;

  @override
  void dispose() {
    _billing.isPremium.removeListener(_reload);
    super.dispose();
  }

  late LearnerProfile _profile;
  late Set<String> _completed;
  List<SavedSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _billing.isPremium.addListener(_reload);
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _profile = _repo.profile();
      _completed = _repo.completedLessonIds();
      _sessions = _repo.sessions();
    });
  }

  Future<void> _open(Lesson lesson) async {
    await context.push('/tutor/${lesson.id}');
    // A finished lesson rewrites the profile and history.
    _reload();
  }

  Future<void> _review(SavedSession session) async {
    await context.push('/review/${session.id}');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
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
            if (_aiReady) ...[
              _PlanCard(
                premium: _usage.isPremium,
                timeLeft: _usage.tutorTimeLeft(),
                onPremium: () async {
                  await context.push('/premium');
                  _reload();
                },
              ).animate().fadeIn(duration: Motion.base),
              const SizedBox(height: Insets.xl),
            ],
            if (!_aiReady) ...[
              InfoNotice(
                icon: Icons.cloud_off_rounded,
                iconColor: context.palette.warning,
                message: const AiException(issue: AiIssue.setup).messageEs,
              ).animate().fadeIn(duration: Motion.base),
              const SizedBox(height: Insets.xl),
            ] else if (!_profile.isEmpty) ...[
              _ProfileCard(
                profile: _profile,
                onReset: () async {
                  await _repo.resetProfile();
                  _reload();
                },
              ).animate().fadeIn(duration: Motion.base),
              const SizedBox(height: Insets.xl),
            ],
            if (_sessions.isNotEmpty) ...[
              _LastSessions(sessions: _sessions, onOpen: _review)
                  .animate()
                  .fadeIn(duration: Motion.base)
                  .moveY(begin: 8, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: Insets.xl),
            ],
            _TranslatorTile(onTap: () => context.push('/translator'))
                .animate()
                .fadeIn(delay: Motion.stagger(1)),
            const SizedBox(height: Insets.sm),
            _LessonTile(
              lesson: freeTalk,
              done: false,
              enabled: _aiReady,
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
                  enabled: _aiReady,
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

/// Which plan the learner is on and how much tutor time is left, with the
/// way to Premium when the free trial is short or spent.
class _PlanCard extends StatelessWidget {
  final bool premium;
  final Duration timeLeft;
  final VoidCallback onPremium;

  const _PlanCard({
    required this.premium,
    required this.timeLeft,
    required this.onPremium,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final minutes = timeLeft.inMinutes;
    final spent = timeLeft < const Duration(seconds: 30);
    final (title, detail) = premium
        ? (
            'Premium',
            spent
                ? 'Usaste tus minutos de este mes. El día 1 se renuevan.'
                : 'Te quedan $minutes min con el tutor este mes.',
          )
        : spent
            ? (
                'Tu prueba gratis terminó',
                'Con Premium hablas con el tutor '
                    '${UsageLimits.premiumTutorPerMonth.inMinutes} minutos al '
                    'mes.',
              )
            : (
                'Prueba gratis',
                minutes == 1
                    ? 'Te queda 1 minuto para hablar con el tutor.'
                    : 'Te quedan $minutes minutos para hablar con el tutor.',
              );

    return AppCard(
      accent: !premium && spent,
      onTap: premium ? null : onPremium,
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.md),
      child: Row(
        children: [
          Icon(
            premium ? Icons.verified_rounded : Icons.timer_outlined,
            color: premium ? p.good : p.gold,
            size: 22,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleMedium),
                const SizedBox(height: 2),
                Text(detail, style: context.texts.bodySmall),
              ],
            ),
          ),
          if (!premium) ...[
            const SizedBox(width: Insets.sm),
            Text('Ver Premium',
                style: context.texts.labelLarge?.copyWith(color: p.gold)),
          ],
        ],
      ),
    );
  }
}

/// The translator lives here because it teaches the same way the tutor
/// review does; it works with the key alone, no lesson needed.
class _TranslatorTile extends StatelessWidget {
  final VoidCallback onTap;
  const _TranslatorTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.md),
      child: Row(
        children: [
          TopicBadge(icon: Icons.translate_rounded, tone: p.gold),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Traductor',
                    style: context.texts.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  'Escribe en español y te explico el francés palabra por '
                  'palabra.',
                  style: context.texts.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 20),
        ],
      ),
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
            TopicBadge(
              icon: lesson.icon,
              tone: lesson.isFreeTalk ? p.terracotta : p.gold,
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

/// The most recent conversation, front and centre, so going over it is one
/// tap away; older ones sit underneath in a quieter list.
class _LastSessions extends StatelessWidget {
  final List<SavedSession> sessions;
  final ValueChanged<SavedSession> onOpen;

  const _LastSessions({required this.sessions, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final last = sessions.first;
    final lesson = Lessons.byId(last.lessonId);
    final older = sessions.skip(1).take(3).toList();

    return AppCard(
      accent: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.lg, Insets.lg, Insets.lg, Insets.md),
            child: Row(
              children: [
                TopicBadge(
                  icon: lesson?.icon ?? Icons.forum_outlined,
                  tone: p.gold,
                  size: 48,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tu última conversación',
                          style: context.texts.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${lesson?.titleEs ?? 'Conversación'} · '
                        '${sessionDateEs(last.date)} · '
                        '${last.spokenLines} frases',
                        style: context.texts.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
            child: ElevatedButton.icon(
              onPressed: () => onOpen(last),
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              label: const Text('Repasar palabra por palabra'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
          ),
          if (older.isNotEmpty) ...[
            Divider(color: p.border, height: 1),
            for (final s in older)
              InkWell(
                onTap: () => onOpen(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg, vertical: Insets.md),
                  child: Row(
                    children: [
                      Icon(
                          Lessons.byId(s.lessonId)?.icon ??
                              Icons.forum_outlined,
                          size: 18,
                          color: p.textMuted),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Text(
                          Lessons.byId(s.lessonId)?.titleEs ?? 'Conversación',
                          style: context.texts.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(sessionDateEs(s.date),
                          style: context.texts.bodySmall),
                      const SizedBox(width: Insets.xs),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: p.textMuted),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
