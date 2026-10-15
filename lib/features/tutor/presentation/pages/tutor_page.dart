import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/ai/ai_backend.dart';
import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/pass_card.dart';
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

  /// The learner's level, from the placement test or the tutor's own
  /// estimate; null until either exists.
  CefrLevel? get _level {
    final placed =
        getIt<StorageService>().getString(StorageKeys.placementLevel);
    final guess = (placed ?? _profile.levelEstimate).trim().toLowerCase();
    for (final level in CefrLevel.values) {
      if (guess.startsWith(level.name)) return level;
    }
    return null;
  }

  /// The guided situation to do next: the first one not done yet at the
  /// learner's level or above.
  Lesson? _nextLesson(CefrLevel? level) {
    final guided = Lessons.all.where((l) => !l.isFreeTalk);
    for (final l in guided) {
      if (_completed.contains(l.id)) continue;
      if (level == null || l.level.index >= level.index) return l;
    }
    for (final l in guided) {
      if (!_completed.contains(l.id)) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final byLevel = <CefrLevel, List<Lesson>>{};
    for (final lesson in Lessons.all.where((l) => !l.isFreeTalk)) {
      byLevel.putIfAbsent(lesson.level, () => []).add(lesson);
    }
    final freeTalk = Lessons.byId(Lessons.freeTalkId)!;
    final level = _level;
    // Open conversation suits someone past the basics; a beginner gets the
    // guided situations first.
    final freeFirst = level != null && level.index >= CefrLevel.b1.index;
    final next = _nextLesson(level);
    final last = _sessions.isEmpty ? null : _sessions.first;
    final lastLesson = last == null ? null : Lessons.byId(last.lessonId);

    final freeTalkGroup = [
      const _Eyebrow('Conversación libre'),
      RowGroup(indent: 64, children: [
        ListRow(
          leading:
              TopicBadge(icon: freeTalk.icon, tone: p.textSecondary, size: 36),
          title: freeTalk.titleEs,
          detail: freeFirst
              ? 'De lo que quieras, a tu ritmo'
              : 'Cuando te sientas cómodo: de lo que quieras',
          enabled: _aiReady,
          onTap: () => _open(freeTalk),
        ),
      ]),
      const SizedBox(height: Insets.xl),
    ];

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Insets.xxxl),
          children: [
            PageHeader(
              title: 'Tutor',
              subtitle:
                  _aiReady ? _planLine() : 'Conversación por voz en francés',
              trailing: _aiReady && !_usage.isPremium
                  ? TextButton(
                      onPressed: () async {
                        await context.push('/premium');
                        _reload();
                      },
                      child: const Text('Premium'),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.page, Insets.lg, Insets.page, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_aiReady) ...[
                    InfoNotice(
                      icon: Icons.cloud_off_rounded,
                      iconColor: p.warning,
                      message:
                          const AiException(issue: AiIssue.setup).messageEs,
                    ),
                    const SizedBox(height: Insets.xl),
                  ],

                  // ── Pick up where you left off ─────────────────────────
                  if (_aiReady && (last != null || next != null)) ...[
                    const _Eyebrow('Continúa'),
                    _ContinuePass(
                      last: last,
                      lastLesson: lastLesson,
                      next: next,
                      onReview: last == null ? null : () => _review(last),
                      onStart: next == null ? null : () => _open(next),
                    )
                        .animate()
                        .fadeIn(duration: Motion.base)
                        .moveY(begin: 10, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: Insets.xl),
                  ],

                  if (freeFirst) ...freeTalkGroup,

                  // ── Guided situations, by level ────────────────────────
                  for (final (i, entry) in byLevel.entries.indexed) ...[
                    _Eyebrow('Situaciones · ${entry.key.label}',
                        detail: entry.key.descriptionEs),
                    RowGroup(
                      indent: 64,
                      children: [
                        for (final lesson in entry.value)
                          ListRow(
                            leading: TopicBadge(
                                icon: lesson.icon,
                                tone: p.textSecondary,
                                size: 36),
                            title: lesson.titleEs,
                            detail: '${_minutes(lesson)} min · '
                                '${lesson.subtitleEs}',
                            enabled: _aiReady,
                            onTap: () => _open(lesson),
                            trailing: _completed.contains(lesson.id)
                                ? Semantics(
                                    label: 'Completada',
                                    child: Icon(Icons.check_circle_rounded,
                                        color: p.good, size: 20),
                                  )
                                : null,
                          ),
                      ],
                    ).animate().fadeIn(
                        delay: Motion.stagger(i + 1), duration: Motion.base),
                    const SizedBox(height: Insets.xl),
                  ],

                  if (!freeFirst) ...freeTalkGroup,

                  if (_aiReady && !_profile.isEmpty) ...[
                    _ProfileCard(
                      profile: _profile,
                      onReset: () async {
                        await _repo.resetProfile();
                        _reload();
                      },
                    ),
                    const SizedBox(height: Insets.xl),
                  ],

                  // ── Tools and history ──────────────────────────────────
                  const _Eyebrow('Herramientas'),
                  RowGroup(
                    indent: 64,
                    children: [
                      ListRow(
                        leading: TopicBadge(
                            icon: Icons.translate_rounded,
                            tone: p.textSecondary,
                            size: 36),
                        title: 'Traductor',
                        detail: 'Del español al francés, palabra por palabra',
                        onTap: () => context.push('/translator'),
                      ),
                      for (final s in _sessions.skip(1).take(3))
                        ListRow(
                          leading: TopicBadge(
                              icon: Lessons.byId(s.lessonId)?.icon ??
                                  Icons.forum_outlined,
                              tone: p.textSecondary,
                              size: 36),
                          title: Lessons.byId(s.lessonId)?.titleEs ??
                              'Conversación',
                          detail: 'Repasar · ${sessionDateEs(s.date)}',
                          onTap: () => _review(s),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A guided lesson's rough length, which grows with the level.
  static int _minutes(Lesson lesson) => switch (lesson.level) {
        CefrLevel.a1 => 4,
        CefrLevel.a2 => 5,
        _ => 6,
      };

  String _planLine() {
    final minutes = _usage.tutorTimeLeft().inMinutes;
    if (_usage.isPremium) {
      return minutes < 1
          ? 'Premium · sin minutos hasta el día 1'
          : 'Premium · $minutes min este mes';
    }
    return minutes < 1
        ? 'Tu prueba gratis terminó'
        : 'Prueba gratis · te quedan $minutes min';
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;
  final String? detail;
  const _Eyebrow(this.text, {this.detail});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.sm),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: text.toUpperCase()),
            if (detail != null)
              TextSpan(
                text: '  ·  $detail',
                style: context.texts.labelMedium,
              ),
          ]),
          style: AppTheme.eyebrow(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

/// What to do next with the tutor, as a pass: the last conversation to go
/// over, and the next situation to try.
class _ContinuePass extends StatelessWidget {
  final SavedSession? last;
  final Lesson? lastLesson;
  final Lesson? next;
  final VoidCallback? onReview;
  final VoidCallback? onStart;

  const _ContinuePass({
    required this.last,
    required this.lastLesson,
    required this.next,
    required this.onReview,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = last;
    final upcoming = next;
    return PassCard(
      accent: true,
      main: Row(
        children: [
          TopicBadge(
            icon: (session != null ? lastLesson?.icon : upcoming?.icon) ??
                Icons.forum_outlined,
            tone: p.gold,
            size: 48,
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session != null
                      ? 'TU ÚLTIMA CONVERSACIÓN'
                      : 'TU PRIMERA CONVERSACIÓN',
                  style: AppTheme.eyebrow(context),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  session != null
                      ? (lastLesson?.titleEs ?? 'Conversación')
                      : (upcoming?.titleEs ?? 'Conversación'),
                  style: context.texts.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  session != null
                      ? '${sessionDateEs(session.date)} · '
                          '${session.spokenLines} '
                          '${session.spokenLines == 1 ? 'frase tuya' : 'frases tuyas'}'
                      : (upcoming?.subtitleEs ?? ''),
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      stub: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session != null && upcoming != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Siguiente situación: '),
                  TextSpan(
                    text: upcoming.titleEs,
                    style: TextStyle(
                        color: p.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ]),
                style: context.texts.bodySmall,
              ),
            ),
          Row(
            children: [
              if (onReview != null) ...[
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton(
                      onPressed: onReview,
                      child: const Text('Repasar'),
                    ),
                  ),
                ),
                if (onStart != null) const SizedBox(width: Insets.md),
              ],
              if (onStart != null)
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: ElevatedButton(
                      onPressed: onStart,
                      child: Text(session != null ? 'Siguiente' : 'Empezar'),
                    ),
                  ),
                ),
            ],
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
                Pill(
                    label: profile.levelEstimate,
                    tone: p.textSecondary,
                    dense: true),
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
