import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/features/tutor/data/tutor_audio.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';

/// The Gemini API key: pasted once, checked against the API, then stored
/// encrypted on the device.
class ApiKeyTile extends StatefulWidget {
  const ApiKeyTile({super.key});

  @override
  State<ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<ApiKeyTile> {
  final _repo = getIt<TutorRepository>();
  bool? _hasKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await _repo.apiKey();
    if (mounted) setState(() => _hasKey = key != null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final has = _hasKey ?? false;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.sm),
      leading: Icon(Icons.key_rounded, size: 20, color: p.gold),
      title: Text('Clave de Gemini', style: context.texts.titleMedium),
      subtitle: Text(
        _hasKey == null
            ? '…'
            : has
                ? 'Conectada · guardada cifrada en este teléfono'
                : 'Sin configurar · necesaria para el tutor',
        style: context.texts.bodySmall,
      ),
      trailing: Icon(
        has ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
        size: 20,
        color: has ? p.good : p.textMuted,
      ),
      onTap: () async {
        final changed = await showDialog<bool>(
          context: context,
          builder: (_) => _ApiKeyDialog(hasKey: has),
        );
        if (changed == true) await _load();
      },
    );
  }
}

class _ApiKeyDialog extends StatefulWidget {
  final bool hasKey;
  const _ApiKeyDialog({required this.hasKey});

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = TutorRepository.cleanApiKey(_controller.text);
    if (key == null) {
      setState(() => _error = 'Pega tu clave primero.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await getIt<TutorReviewService>().validateKey(key);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _checking = false;
        _error = 'Google no acepta esta clave. Cópiala de nuevo desde '
            'Google AI Studio, o revisa tu conexión.';
      });
      return;
    }
    await getIt<TutorRepository>().setApiKey(key);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    await getIt<TutorRepository>().setApiKey(null);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null) _controller.text = text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clave de Gemini'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Créala gratis en aistudio.google.com › Get API key. Se guarda '
            'cifrada solo en este teléfono.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          TextField(
            controller: _controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_checking,
            decoration: InputDecoration(
              hintText:
                  widget.hasKey ? 'Pega una clave nueva' : 'Pega tu clave',
              errorText: _error,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: 'Pegar',
                icon: const Icon(Icons.content_paste_rounded, size: 20),
                onPressed: _checking ? null : _paste,
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        if (widget.hasKey)
          TextButton(
            onPressed: _checking ? null : _remove,
            child: const Text('Quitar'),
          ),
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _checking ? null : _save,
          child: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
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
    final key = await getIt<TutorRepository>().apiKey();
    if (!mounted) return;
    if (key == null) {
      setState(() => _error = 'Añade tu clave de Gemini para oír las voces.');
      return;
    }
    await _audio.stopPlayback();
    var pcm = _samples[voice];
    if (pcm == null) {
      setState(() {
        _loading = voice;
        _error = null;
      });
      try {
        pcm = await getIt<TutorReviewService>()
            .synthesize(apiKey: key, voice: voice, text: _sample);
        _samples[voice] = pcm;
      } catch (_) {
        if (mounted) {
          setState(
              () => _error = 'No pude cargar la muestra. Prueba otra vez.');
        }
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
