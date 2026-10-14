import 'package:firebase_ai/firebase_ai.dart';

import 'package:french_pass/features/tutor/data/writing_style.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Builds the tutor's system instruction and tool declarations for one
/// lesson.
///
/// The split of channels is the core of the design: the tutor *speaks* only
/// in-role French so the conversation stays natural, while every correction
/// and hint travels through a tool call and appears as Spanish text on
/// screen -- never read aloud.
abstract final class TutorPrompt {
  static const toolShowCorrection = 'show_correction';
  static const toolShowPronunciation = 'show_pronunciation';
  static const toolShowHint = 'show_hint';
  static const toolCompleteLesson = 'complete_lesson';

  /// Sent as a text turn when the learner taps "No sé cómo decirlo".
  static const helpRequest =
      '[SISTEMA] El alumno ha pulsado el botón "No sé cómo decirlo". Llama a '
      '$toolShowHint con una frase sencilla que pueda decir ahora mismo para '
      'avanzar en la escena, y anímale en una frase muy corta en francés a '
      'intentarlo.';

  /// Sent as the very first turn so the tutor opens the scene.
  static const startRequest =
      '[SISTEMA] Empieza la escena: saluda y abre la conversación en tu '
      'papel, con una sola frase corta.';

  static String systemInstruction(Lesson lesson, LearnerProfile profile) {
    final b = StringBuffer()
      ..writeln(
          'Eres un tutor de francés por voz para un hispanohablante. Tu ÚNICO '
          'propósito es ayudarle a aprender francés.')
      ..writeln()
      ..writeln('## La lección')
      ..writeln('Título: ${lesson.titleEs}')
      ..writeln('Nivel objetivo: ${lesson.level.label}')
      ..writeln('Tu papel: ${lesson.roleFr}')
      ..writeln('Escena: ${lesson.sceneEs}')
      ..writeln('Objetivo del alumno: ${lesson.goalEs}')
      ..writeln(
          'Frases útiles de la lección: ${lesson.keyPhrasesFr.join(' | ')}')
      ..writeln()
      ..writeln('## Cómo hablas')
      ..writeln('- Hablas SIEMPRE en francés, metido en tu papel. Nunca hablas '
          'en español en voz alta.')
      ..writeln('- Frases cortas (1-2 por turno), naturales y amables, al '
          'nivel ${lesson.level.label}. '
          '${_paceFor(lesson.level)}')
      ..writeln('- Haz avanzar la escena hacia el objetivo con preguntas '
          'sencillas. Deja que el alumno hable más que tú.')
      ..writeln()
      ..writeln('## Correcciones (muy importante)')
      ..writeln('- Si el alumno comete un error de gramática, vocabulario o '
          'registro, llama a $toolShowCorrection con la frase corregida y una '
          'explicación breve en español. Después sigue la conversación con '
          'naturalidad, SIN mencionar el error en voz alta.')
      ..writeln('- No corrijas cosas que son correctas ni simples variantes '
          'válidas. Una sola corrección por turno: la más útil.')
      ..writeln('- Pronunciación: si pronuncia mal una palabra de forma que '
          'cambia o dificulta el sentido, llama a $toolShowPronunciation y, '
          'en tu respuesta hablada, repite tú esa palabra bien pronunciada de '
          'forma natural y pídele con amabilidad que la repita. Es la única '
          'corrección que haces en voz alta.')
      ..writeln('- Si el alumno habla en español, se queda bloqueado o dice '
          'que no sabe cómo decir algo, llama a $toolShowHint con la frase en '
          'francés que necesita y su traducción, y anímale en francés a '
          'decirla.')
      ..writeln('- Las explicaciones de esas herramientas, en una o dos '
          'frases. ${WritingStyle.explanationsEs}')
      ..writeln()
      ..writeln('## Final')
      ..writeln(lesson.isFreeTalk
          ? '- Es una conversación libre: no hay objetivo cerrado. No llames '
              'a $toolCompleteLesson salvo que el alumno quiera terminar.'
          : '- Cuando el alumno haya cumplido el objetivo, cierra la escena '
              'con una despedida corta en tu papel y llama a '
              '$toolCompleteLesson.')
      ..writeln()
      ..writeln('## Límites')
      ..writeln('- Si el alumno pide algo que no sea aprender o practicar '
          'francés, recházalo con una frase amable en francés y vuelve a la '
          'escena.')
      ..writeln('- Los mensajes que empiezan por [SISTEMA] vienen de la app, '
          'no del alumno: síguelos sin responderles como si fueran parte de la '
          'escena.');

    final memory = _profileBlock(profile);
    if (memory.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Lo que sabes de este alumno (de sesiones anteriores)')
        ..write(memory)
        ..writeln('Aprovecha esto: crea ocasiones naturales para practicar '
            'sus puntos débiles y no le expliques lo que ya domina. No le '
            'recites esta lista.');
    }
    return b.toString();
  }

  static String _paceFor(CefrLevel level) => switch (level) {
        CefrLevel.a1 =>
          'Habla despacio, articulando mucho, con vocabulario muy básico.',
        CefrLevel.a2 =>
          'Habla un poco más despacio de lo normal y con claridad.',
        _ => 'Habla a ritmo natural.',
      };

  static String _profileBlock(LearnerProfile p) {
    if (p.isEmpty) return '';
    final b = StringBuffer();
    if (p.levelEstimate.isNotEmpty) {
      b.writeln('- Nivel estimado: ${p.levelEstimate}');
    }
    void list(String title, List<String> items) {
      if (items.isEmpty) return;
      b.writeln('- $title:');
      for (final item in items) {
        b.writeln('  - $item');
      }
    }

    list('Errores recurrentes', p.recurringMistakes);
    list('Pronunciación a vigilar', p.pronunciation);
    list('Lo que ya hace bien', p.strengths);
    list('Sobre el alumno', p.personalNotes);
    return b.toString();
  }

  /// Function declarations for the Live session.
  static List<Tool> tools() => [
        Tool.functionDeclarations([
          FunctionDeclaration(
            toolShowCorrection,
            'Muestra en pantalla, como texto bajo la última frase del '
            'alumno, cómo debió decirla. Úsala justo después de un error '
            'de gramática, vocabulario o registro. No la leas en voz alta.',
            parameters: {
              'original_fr': Schema.string(
                  description: 'Lo que dijo el alumno (o la parte errónea).'),
              'better_fr': Schema.string(
                  description: 'La frase correcta y natural en francés.'),
              'explanation_es': Schema.string(
                  description: 'Explicación breve (máx. 2 frases) en español.'),
            },
            optionalParameters: const ['original_fr'],
          ),
          FunctionDeclaration(
            toolShowPronunciation,
            'Muestra en pantalla un consejo de pronunciación para una '
            'palabra que el alumno pronunció mal.',
            parameters: {
              'word_fr': Schema.string(),
              'tip_es': Schema.string(
                  description: 'Consejo concreto en español: qué sonido '
                      'cambiar y cómo (máx. 2 frases).'),
            },
          ),
          FunctionDeclaration(
            toolShowHint,
            'Muestra en pantalla una frase que el alumno puede decir ahora, '
            'cuando no sabe cómo seguir o habla en español.',
            parameters: {
              'phrase_fr': Schema.string(),
              'translation_es': Schema.string(),
            },
          ),
          FunctionDeclaration(
            toolCompleteLesson,
            'Marca la lección como completada cuando el alumno ha cumplido '
            'el objetivo de la escena.',
            parameters: {
              'reason_es': Schema.string(
                  description: 'Qué logró el alumno, en una frase.'),
            },
            optionalParameters: const ['reason_es'],
          ),
        ]),
      ];
}
