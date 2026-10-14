import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/ai/ai_backend.dart';
import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/features/premium/data/billing_service.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';
import 'package:french_pass/features/tutor/data/tutor_audio.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';

/// Premium status, and the way to subscribe or check minutes.
class PremiumTile extends StatelessWidget {
  const PremiumTile({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final billing = getIt<BillingService>();
    return ValueListenableBuilder<bool>(
      valueListenable: billing.isPremium,
      builder: (context, premium, _) => ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Insets.lg, vertical: Insets.sm),
        leading: Icon(
          premium ? Icons.verified_rounded : Icons.workspace_premium_outlined,
          size: 20,
          color: premium ? p.good : p.gold,
        ),
        title: Text('FrenchPass Premium', style: context.texts.titleMedium),
        subtitle: Text(
          premium
              ? 'Activo · ${getIt<UsageService>().tutorTimeLeft().inMinutes} '
                  'min de tutor este mes'
              : '${UsageLimits.premiumTutorPerMonth.inMinutes} minutos de '
                  'tutor al mes',
          style: context.texts.bodySmall,
        ),
        trailing:
            Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
        onTap: () => context.push('/premium'),
      ),
    );
  }
}

/// GitHub build only: this install's App Check debug token. Firebase
/// rejects AI calls from it until the token is added in the console
/// (App Check > Apps > Manage debug tokens), once per install.
class AppCheckTokenTile extends StatelessWidget {
  final String token;
  const AppCheckTokenTile({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.sm),
      leading: Icon(Icons.verified_user_outlined, size: 20, color: p.gold),
      title: Text('Token de App Check', style: context.texts.titleMedium),
      subtitle: Text(
        'Versión de desarrollo. Regístralo en Firebase para usar la IA: '
        '$token',
        style: context.texts.bodySmall,
      ),
      trailing: IconButton(
        tooltip: 'Copiar token',
        icon: Icon(Icons.copy_rounded, size: 20, color: p.textMuted),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: token));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Token copiado')),
            );
          }
        },
      ),
    );
  }
}

/// The tutor's voice, with a spoken sample of each so the choice is heard
/// rather than guessed from a name.
class VoiceTile extends StatefulWidget {
  const VoiceTile({super.key});

  @override
  State<VoiceTile> createState() => _VoiceTileState();
}

class _VoiceTileState extends State<VoiceTile> {
  final _repo = getIt<TutorRepository>();
  late String _voice = _repo.voice;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.sm),
      leading: Icon(Icons.record_voice_over_outlined, size: 20, color: p.gold),
      title: Text('Voz del tutor', style: context.texts.titleMedium),
      subtitle:
          Text(TutorVoices.labelFor(_voice), style: context.texts.bodySmall),
      trailing: Icon(Icons.expand_more_rounded, size: 20, color: p.textMuted),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => _VoiceSheet(current: _voice),
        );
        if (picked != null && mounted) {
          await _repo.setVoice(picked);
          setState(() => _voice = picked);
        }
      },
    );
  }
}

class _VoiceSheet extends StatefulWidget {
  final String current;
  const _VoiceSheet({required this.current});

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  static const _sample = 'Dis chaleureusement : Bonjour ! Je suis ton tuteur '
      'de français. On commence ?';

  final _audio = DeviceTutorAudio();
  final Map<String, Uint8List> _samples = {};
  String? _loading;
  String? _error;

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<void> _preview(String voice) async {
    await _audio.stopPlayback();
    var pcm = _samples[voice];
    if (pcm == null) {
      setState(() {
        _loading = voice;
        _error = null;
      });
      try {
        pcm = await getIt<TutorReviewService>()
            .synthesize(voice: voice, text: _sample);
        _samples[voice] = pcm;
      } on AiException catch (e) {
        if (mounted) setState(() => _error = e.messageEs);
      } finally {
        if (mounted) setState(() => _loading = null);
      }
    }
    if (pcm != null && mounted) await _audio.play(pcm);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.xl, Insets.xl, Insets.xl, Insets.xs),
              child: Text('Voz del tutor', style: context.texts.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              child: Text(
                _error ?? 'Toca ▶ para escuchar cada voz.',
                style: context.texts.bodySmall
                    ?.copyWith(color: _error != null ? p.critical : null),
              ),
            ),
            const SizedBox(height: Insets.sm),
            for (final (id, label) in TutorVoices.all)
              ListTile(
                title: Text(label, style: context.texts.bodyLarge),
                leading: IconButton(
                  tooltip: 'Escuchar $id',
                  icon: _loading == id
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.play_circle_outline_rounded, color: p.gold),
                  onPressed: _loading == null ? () => _preview(id) : null,
                ),
                trailing: id == widget.current
                    ? Icon(Icons.check_rounded, color: p.gold, size: 20)
                    : null,
                onTap: () => Navigator.pop(context, id),
              ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
