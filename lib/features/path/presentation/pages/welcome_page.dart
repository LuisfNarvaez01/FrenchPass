import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/mascot.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/features/path/domain/journey.dart';

/// The first screen of a new install: the promise, then one choice. Starting
/// from zero goes straight into the first lesson; knowing some French goes
/// to the placement test.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  Future<void> _begin(BuildContext context, {required bool fromZero}) async {
    final storage = getIt<StorageService>();
    await storage.setBool(StorageKeys.onboardingDone, true);
    if (fromZero) {
      final path = getIt<PathRepository>();
      await path.setStartStage(Stage.depart);
    }
    if (!context.mounted) return;
    final router = GoRouter.of(context);
    router.go('/home');
    final first = getIt<PathRepository>().next;
    if (fromZero && first != null) {
      router.push('/path/stop/${first.id}');
    } else if (!fromZero) {
      router.push('/practice/placement');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.page, Insets.xl, Insets.page, Insets.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(child: MascotSticker(size: 168))
                    .animate()
                    .fadeIn(duration: Motion.slow)
                    .scaleXY(
                        begin: 0.85,
                        end: 1,
                        duration: Motion.slow,
                        curve: Curves.easeOutBack),
                const SizedBox(height: Insets.xl),
                Center(
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: 'French',
                        style: context.texts.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(
                        text: 'Pass',
                        style: context.texts.headlineMedium?.copyWith(
                            color: p.gold, fontWeight: FontWeight.w800),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  'Aprende francés,\nuna palabra a la vez.',
                  textAlign: TextAlign.center,
                  style: AppTheme.french(context, size: 32),
                ).animate().fadeIn(delay: 250.ms, duration: Motion.slow),
                const SizedBox(height: Insets.md),
                Text(
                  'Cada día, una palabra y una lección corta que la usa. '
                  'En una semana tendrás tu primera conversación.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium,
                ).animate().fadeIn(delay: 400.ms, duration: Motion.slow),
                const Spacer(flex: 2),
                ElevatedButton(
                  onPressed: () => _begin(context, fromZero: true),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  child: const Text('Empiezo desde cero'),
                ),
                const SizedBox(height: Insets.md),
                OutlinedButton(
                  onPressed: () => _begin(context, fromZero: false),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  child: const Text('Ya sé algo de francés'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
