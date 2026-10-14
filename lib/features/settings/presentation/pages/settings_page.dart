import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:french_pass/core/ai/ai_backend.dart';
import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/settings/presentation/widgets/tutor_settings_tiles.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final bloc = context.read<SettingsBloc>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Insets.page, Insets.sm, Insets.page, Insets.xxxl),
            children: [
              Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: Insets.xs),
                  Text('Ajustes', style: context.texts.headlineLarge),
                ],
              ),
              const SizedBox(height: Insets.xl),

              // ── Tutor ─────────────────────────────────────────────────────
              _Group(
                eyebrow: 'Tutor de IA',
                children: [
                  const PremiumTile(),
                  const _Separator(),
                  const VoiceTile(),
                  if (AiBackend.debugToken case final token?) ...[
                    const _Separator(),
                    AppCheckTokenTile(token: token),
                  ],
                ],
              ),

              const SizedBox(height: Insets.lg),

              // ── Appearance ────────────────────────────────────────────────
              _Group(
                eyebrow: 'Apariencia',
                children: [
                  _SegmentedRow<ThemeMode>(
                    label: 'Tema',
                    value: settings.themeMode,
                    options: const [
                      (ThemeMode.dark, 'Oscuro'),
                      (ThemeMode.light, 'Claro'),
                      (ThemeMode.system, 'Sistema'),
                    ],
                    onChanged: (mode) => bloc.add(ChangeThemeEvent(mode)),
                  ),
                ],
              ),

              const SizedBox(height: Insets.lg),

              // ── Learning ──────────────────────────────────────────────────
              _Group(
                eyebrow: 'Aprendizaje',
                children: [
                  _ChoiceTile<LevelFilter>(
                    icon: Icons.layers_outlined,
                    title: 'Nivel',
                    subtitle: settings.levelFilter.labelEs,
                    value: settings.levelFilter,
                    options: [
                      for (final filter in LevelFilter.values)
                        (filter, filter.labelEs),
                    ],
                    onChanged: (filter) => bloc.add(ChangeLevelEvent(filter)),
                  ),
                  const _Separator(),
                  _SpeechRateTile(
                    rate: settings.speechRate,
                    onChanged: (rate) => bloc.add(ChangeSpeechRateEvent(rate)),
                  ),
                ],
              ),

              const SizedBox(height: Insets.lg),

              // ── Reminder ──────────────────────────────────────────────────
              _Group(
                eyebrow: 'Recordatorio diario',
                children: [
                  SwitchListTile(
                    value: settings.notificationsEnabled,
                    onChanged: (enabled) =>
                        bloc.add(ToggleNotificationsEvent(enabled)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg, vertical: Insets.xs),
                    title: Text('Avisarme cada día',
                        style: context.texts.titleMedium),
                    subtitle: Text(
                      settings.notificationsEnabled
                          ? 'Activo a las ${_hourLabel(settings.notificationHour)}'
                          : 'Un aviso para no perder la racha',
                      style: context.texts.bodySmall,
                    ),
                  ),
                  if (settings.notificationsEnabled) ...[
                    const _Separator(),
                    _HourTile(
                      hour: settings.notificationHour,
                      onChanged: (hour) =>
                          bloc.add(ChangeNotificationHourEvent(hour)),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: Insets.lg),

              // ── Data ──────────────────────────────────────────────────────
              const _Group(
                eyebrow: 'Datos',
                children: [
                  _CorpusTile(),
                  _Separator(),
                  _ResetTile(),
                ],
              ),

              const SizedBox(height: Insets.xl),

              Center(
                child: Column(
                  children: [
                    Text('FrenchPass', style: AppTheme.eyebrow(context)),
                    const SizedBox(height: Insets.xs),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snap) => Text(
                        snap.hasData ? 'Versión ${snap.data!.version}' : '',
                        style: context.texts.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';
}

class _Group extends StatelessWidget {
  final String eyebrow;
  final List<Widget> children;

  const _Group({required this.eyebrow, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.sm),
          child: Text(eyebrow.toUpperCase(), style: AppTheme.eyebrow(context)),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: Insets.lg,
        endIndent: Insets.lg,
        color: context.palette.border,
      );
}

/// Inline segmented control — the right form for two or three exclusive
/// options, since all of them fit on screen.
class _SegmentedRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  const _SegmentedRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.texts.titleMedium),
          const SizedBox(height: Insets.md),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                for (final option in options)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(option.$1),
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        padding:
                            const EdgeInsets.symmetric(vertical: Insets.md),
                        decoration: BoxDecoration(
                          color: option.$1 == value
                              ? p.gold.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Text(
                          option.$2,
                          textAlign: TextAlign.center,
                          style: context.texts.labelMedium?.copyWith(
                            color:
                                option.$1 == value ? p.gold : p.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a sheet when there are too many options for a segmented control.
class _ChoiceTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.sm),
      leading: Icon(icon, size: 20, color: p.gold),
      title: Text(title, style: context.texts.titleMedium),
      subtitle: Text(subtitle, style: context.texts.bodySmall),
      trailing: Icon(Icons.expand_more_rounded, size: 20, color: p.textMuted),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(Insets.xl),
                child: Text(title, style: context.texts.titleLarge),
              ),
              for (final option in options)
                ListTile(
                  title: Text(option.$2, style: context.texts.bodyLarge),
                  trailing: option.$1 == value
                      ? Icon(Icons.check_rounded, color: p.gold, size: 20)
                      : null,
                  onTap: () {
                    onChanged(option.$1);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: Insets.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// TTS speed, with a sample so the setting can be heard rather than guessed.
class _SpeechRateTile extends StatelessWidget {
  final int rate;
  final ValueChanged<int> onChanged;

  const _SpeechRateTile({required this.rate, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Insets.lg, Insets.lg, Insets.lg, Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 20, color: p.gold),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Text('Velocidad de la voz',
                    style: context.texts.titleMedium),
              ),
              Text('$rate%',
                  style: context.texts.labelMedium?.copyWith(color: p.gold)),
            ],
          ),
          Slider(
            value: rate.toDouble(),
            min: 25,
            max: 75,
            divisions: 10,
            label: '$rate%',
            onChanged: (value) => onChanged(value.round()),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final spoke = await getIt<TtsService>()
                    .speak('Bonjour, je m\'appelle FrenchPass.');
                if (!spoke && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No hay voz francesa instalada. Añádela en Ajustes de '
                        'Android › Idiomas › Texto a voz.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Probar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourTile extends StatelessWidget {
  final int hour;
  final ValueChanged<int> onChanged;

  const _HourTile({required this.hour, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.sm),
      leading: Icon(Icons.schedule_rounded, size: 20, color: p.gold),
      title: Text('Hora del aviso', style: context.texts.titleMedium),
      subtitle: Text('${hour.toString().padLeft(2, '0')}:00',
          style: context.texts.bodySmall),
      trailing: Icon(Icons.edit_outlined, size: 18, color: p.textMuted),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: 0),
          helpText: 'Hora del recordatorio',
        );
        if (picked != null) onChanged(picked.hour);
      },
    );
  }
}

class _CorpusTile extends StatelessWidget {
  const _CorpusTile();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final words = getIt<WordRepository>().all;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.sm),
      leading: Icon(Icons.menu_book_outlined, size: 20, color: p.gold),
      title: Text('Catálogo', style: context.texts.titleMedium),
      subtitle: Text(
        '${words.length} palabras · funciona sin conexión',
        style: context.texts.bodySmall,
      ),
    );
  }
}

class _ResetTile extends StatelessWidget {
  const _ResetTile();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.sm),
      leading: Icon(Icons.delete_outline_rounded, size: 20, color: p.critical),
      title: Text('Borrar mis datos',
          style: context.texts.titleMedium?.copyWith(color: p.critical)),
      subtitle: Text('Progreso, conversaciones, traducciones y ajustes',
          style: context.texts.bodySmall),
      onTap: () async {
        final bloc = context.read<SettingsBloc>();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('¿Borrar todos tus datos?'),
            content: const Text(
              'Se borra todo lo que la app guarda en este teléfono: tu racha, '
              'los repasos, el historial de prácticas, las palabras '
              'guardadas, tus conversaciones con el tutor, lo que el tutor '
              'sabe de ti, tus traducciones y los ajustes. No se puede '
              'deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Borrar',
                    style: TextStyle(color: context.palette.critical)),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        await getIt<ProgressRepository>().resetAll();
        // Settings live under the same key prefix, so reload them too.
        bloc.add(const LoadSettingsEvent());

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos borrados.')),
          );
        }
      },
    );
  }
}
