import 'package:flutter/material.dart';

import 'package:french_pass/core/theme/app_theme.dart';

/// Listen · Practise · Save. "Practicar" is the primary action and gets the
/// filled button and the extra width; the other two are equal-weight secondary
/// actions whose state (speaking / saved) is visible on the control itself.
class ActionButtonsRow extends StatelessWidget {
  final VoidCallback onListen;
  final VoidCallback onPractice;
  final VoidCallback onSave;
  final bool isSpeaking;
  final bool isSaved;

  const ActionButtonsRow({
    super.key,
    required this.onListen,
    required this.onPractice,
    required this.onSave,
    this.isSpeaking = false,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _IconAction(
            icon: isSpeaking
                ? Icons.graphic_eq_rounded
                : Icons.volume_up_rounded,
            label: isSpeaking ? 'Suena…' : 'Escuchar',
            onTap: onListen,
            active: isSpeaking,
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 64,
            child: ElevatedButton.icon(
              onPressed: onPractice,
              icon: const Icon(Icons.mic_rounded, size: 20),
              label: const Text('Practicar'),
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: _IconAction(
            icon: isSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: isSaved ? 'Guardada' : 'Guardar',
            onTap: onSave,
            active: isSaved,
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = active ? p.gold : p.textSecondary;

    return SizedBox(
      height: 64,
      child: Material(
        color: active ? p.gold.withValues(alpha: 0.10) : p.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                  color: active ? p.gold.withValues(alpha: 0.45) : p.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: tone),
                const SizedBox(height: Insets.xs),
                Text(
                  label,
                  style: context.texts.labelSmall
                      ?.copyWith(color: tone, letterSpacing: 0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
