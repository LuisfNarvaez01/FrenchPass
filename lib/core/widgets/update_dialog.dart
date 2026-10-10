import 'package:flutter/material.dart';

import 'package:french_pass/core/services/update_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';

/// Prompts to install a newer build found on GitHub Releases.
///
/// Shown once per [UpdateInfo] the app discovers; "Más tarde" simply closes
/// it (the same version won't be re-offered until the app restarts and finds
/// a release newer still).
Future<void> showUpdateDialog(
  BuildContext context,
  UpdateService service,
  UpdateInfo info,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _UpdateDialog(service: service, info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateService service;
  final UpdateInfo info;
  const _UpdateDialog({required this.service, required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

enum _Phase { prompt, downloading, needsPermission, failed }

class _UpdateDialogState extends State<_UpdateDialog> {
  _Phase _phase = _Phase.prompt;

  Future<void> _update() async {
    setState(() => _phase = _Phase.downloading);
    final outcome = await widget.service.downloadAndInstall(widget.info);
    if (!mounted) return;
    setState(() {
      _phase = switch (outcome) {
        InstallOutcome.started => _Phase.prompt, // dialog closes below
        InstallOutcome.permissionRequired => _Phase.needsPermission,
        InstallOutcome.downloadFailed || InstallOutcome.error => _Phase.failed,
      };
    });
    if (outcome == InstallOutcome.started && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _retryAfterPermission() async {
    setState(() => _phase = _Phase.downloading);
    final outcome = await widget.service.retryInstall();
    if (!mounted) return;
    if (outcome == InstallOutcome.started) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _phase = outcome == InstallOutcome.permissionRequired
          ? _Phase.needsPermission
          : _Phase.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AlertDialog(
      icon: Icon(Icons.new_releases_rounded, color: p.gold, size: 28),
      title: Text('Versión ${widget.info.version} disponible',
          style: context.texts.titleLarge),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.info.notes.isNotEmpty) ...[
              Text(widget.info.notes, style: context.texts.bodyMedium),
              const SizedBox(height: Insets.lg),
            ],
            switch (_phase) {
              _Phase.prompt => Text(
                  'Se descargará e instalará automáticamente. Android te '
                  'pedirá confirmar la instalación al final.',
                  style: context.texts.bodySmall,
                ),
              _Phase.downloading => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<double?>(
                      valueListenable: widget.service.downloadProgress,
                      builder: (context, progress, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.sm),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: p.surfaceAlt,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(p.gold),
                            ),
                          ),
                          const SizedBox(height: Insets.sm),
                          Text(
                            progress == null
                                ? 'Preparando…'
                                : 'Descargando… ${(progress * 100).round()}%',
                            style: context.texts.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              _Phase.needsPermission => Text(
                  'Android necesita tu permiso para instalar apps desde '
                  'FrenchPass. Se abrió la pantalla de ajustes — activa el '
                  'permiso y vuelve aquí para continuar.',
                  style: context.texts.bodySmall?.copyWith(color: p.warning),
                ),
              _Phase.failed => Text(
                  'No se pudo completar la actualización. Verifica tu '
                  'conexión e inténtalo de nuevo.',
                  style: context.texts.bodySmall?.copyWith(color: p.critical),
                ),
            },
          ],
        ),
      ),
      actions: [
        if (_phase != _Phase.downloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Más tarde'),
          ),
        if (_phase == _Phase.prompt)
          ElevatedButton(
            onPressed: _update,
            child: const Text('Actualizar'),
          ),
        if (_phase == _Phase.needsPermission)
          ElevatedButton(
            onPressed: _retryAfterPermission,
            child: const Text('Ya lo activé, continuar'),
          ),
        if (_phase == _Phase.failed)
          ElevatedButton(
            onPressed: _update,
            child: const Text('Reintentar'),
          ),
      ],
    );
  }
}
