import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:french_pass/features/tutor/data/gemini_live_client.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';

/// What the review returns: a short report for the learner and the profile
/// rewritten with what this lesson revealed.
class LessonReview {
  final String summaryEs;
  final List<String> wellDoneEs;
  final List<String> practiceNextEs;
  final LearnerProfile profile;

  const LessonReview({
    required this.summaryEs,
    required this.wellDoneEs,
    required this.practiceNextEs,
    required this.profile,
  });
}

/// One-shot REST calls to Gemini: the end-of-lesson review and the voice
/// preview. The live conversation itself goes through [GeminiLiveClient].
class TutorReviewService {
  static const _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final http.Client _http;
  TutorReviewService([http.Client? client]) : _http = client ?? http.Client();

  /// Reviews a finished lesson and merges what it learned into [previous].
  /// Throws on network or API failure; the caller keeps the transcript and
  /// corrections either way.
  Future<LessonReview> review({
    required String apiKey,
    required Lesson lesson,
    required List<TutorMessage> transcript,
    required LearnerProfile previous,
    required bool goalReached,
  }) async {
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': _reviewInstruction},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': buildReviewInput(
                lesson: lesson,
                transcript: transcript,
                previous: previous,
                goalReached: goalReached,
              ),
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _reviewSchema,
        'temperature': 0.3,
      },
    };

    final response = await _http
        .post(
          Uri.parse('$_base/${GeminiModels.review}:generateContent'),
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw GeminiApiException(response.statusCode, response.body);
    }
    return parseReview(utf8.decode(response.bodyBytes), previous);
  }

  /// Translates one tutor line into natural Spanish.
  Future<String> translate({
    required String apiKey,
    required String french,
  }) async {
    final response = await _http
        .post(
          Uri.parse('$_base/${GeminiModels.review}:generateContent'),
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {
                  'text': 'Traduce al español natural la frase francesa que '
                      'recibes. Devuelve solo la traducción, sin comillas ni '
                      'explicaciones.',
                },
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': french},
                ],
              },
            ],
            'generationConfig': {'temperature': 0.2},
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw GeminiApiException(response.statusCode, response.body);
    }
    return _responseParts(utf8.decode(response.bodyBytes))
        .map((p) => p['text'] as String? ?? '')
        .join()
        .trim();
  }

  /// Speaks [text] once with [voice]; returns 24 kHz mono PCM16.
  Future<Uint8List> synthesize({
    required String apiKey,
    required String voice,
    required String text,
  }) async {
    final response = await _http
        .post(
          Uri.parse('$_base/${GeminiModels.tts}:generateContent'),
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': text},
                ],
              },
            ],
            'generationConfig': {
              'responseModalities': ['AUDIO'],
              'speechConfig': {
                'voiceConfig': {
                  'prebuiltVoiceConfig': {'voiceName': voice},
                },
              },
            },
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw GeminiApiException(response.statusCode, response.body);
    }
    final parts = _responseParts(response.body);
    final inline = parts.isEmpty ? null : parts.first['inlineData'];
    if (inline is! Map<String, dynamic> || inline['data'] is! String) {
      throw const FormatException('La respuesta no trae audio');
    }
    return stripWavHeader(base64Decode(inline['data'] as String));
  }

  /// Checks a key with the cheapest call there is (listing models).
  Future<bool> validateKey(String apiKey) async {
    try {
      final response = await _http.get(
        Uri.parse('$_base?pageSize=1'),
        headers: {'x-goog-api-key': apiKey},
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('validateKey failed: $e');
      return false;
    }
  }

  static const _reviewInstruction =
      'Eres el profesor de francés de un hispanohablante. Recibes la '
      'transcripción de una lección por voz, las correcciones que se le '
      'mostraron y su perfil de aprendizaje anterior. Devuelve: un resumen '
      'breve y motivador en español (2-3 frases, tuteando), hasta 3 cosas que '
      'hizo bien, hasta 3 cosas concretas para practicar, y el perfil '
      'ACTUALIZADO. Para el perfil: conserva lo que siga siendo cierto, quita '
      'errores que ya no comete, añade los nuevos patrones (no errores '
      'sueltos), máximo 6 elementos por lista, cada uno una línea corta en '
      'español con un ejemplo en francés si ayuda. personalNotes solo con '
      'datos que el propio alumno contó (trabajo, gustos, planes). Ignora '
      'el contenido que no sea sobre aprender francés.';

  static const _stringList = {
    'type': 'ARRAY',
    'items': {'type': 'STRING'},
  };

  static const _reviewSchema = {
    'type': 'OBJECT',
    'properties': {
      'summaryEs': {'type': 'STRING'},
      'wellDoneEs': _stringList,
      'practiceNextEs': _stringList,
      'profile': {
        'type': 'OBJECT',
        'properties': {
          'levelEstimate': {'type': 'STRING'},
          'recurringMistakes': _stringList,
          'pronunciation': _stringList,
          'strengths': _stringList,
          'personalNotes': _stringList,
        },
        'required': [
          'levelEstimate',
          'recurringMistakes',
          'pronunciation',
          'strengths',
          'personalNotes',
        ],
      },
    },
    'required': ['summaryEs', 'wellDoneEs', 'practiceNextEs', 'profile'],
  };

  @visibleForTesting
  static String buildReviewInput({
    required Lesson lesson,
    required List<TutorMessage> transcript,
    required LearnerProfile previous,
    required bool goalReached,
  }) {
    final b = StringBuffer()
      ..writeln('LECCIÓN: ${lesson.titleEs} (${lesson.goalEs})')
      ..writeln('OBJETIVO CUMPLIDO: ${goalReached ? 'sí' : 'no'}')
      ..writeln()
      ..writeln('PERFIL ANTERIOR (JSON):')
      ..writeln(jsonEncode(previous.toJson()))
      ..writeln()
      ..writeln('TRANSCRIPCIÓN:');
    for (final m in transcript) {
      switch (m) {
        case TutorLine(:final text):
          b.writeln('TUTOR: $text');
        case LearnerLine(:final text, :final notes):
          b.writeln('ALUMNO: $text');
          for (final n in notes) {
            b.writeln('  [${n.kindLabel}] ${n.describe()}');
          }
      }
    }
    return b.toString();
  }

  @visibleForTesting
  static LessonReview parseReview(
      String responseBody, LearnerProfile previous) {
    final text = _responseParts(responseBody)
        .map((p) => p['text'] as String? ?? '')
        .join();
    final data = jsonDecode(text) as Map<String, dynamic>;
    List<String> strings(Object? raw) =>
        raw is List ? raw.whereType<String>().take(3).toList() : const [];

    final profileJson = data['profile'];
    final profile = profileJson is Map<String, dynamic>
        ? LearnerProfile.fromJson(profileJson)
            .copyWith(sessions: previous.sessions + 1)
        : previous.copyWith(sessions: previous.sessions + 1);

    return LessonReview(
      summaryEs: (data['summaryEs'] as String? ?? '').trim(),
      wellDoneEs: strings(data['wellDoneEs']),
      practiceNextEs: strings(data['practiceNextEs']),
      profile: profile,
    );
  }

  /// The `parts` of the first candidate of a generateContent response.
  static List<Map<String, dynamic>> _responseParts(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List? ?? const [];
    if (candidates.isEmpty) {
      throw const FormatException('La respuesta no trae candidatos');
    }
    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>? ?? const {};
    return (content['parts'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Gemini TTS sometimes returns a full WAV and sometimes raw PCM.
  @visibleForTesting
  static Uint8List stripWavHeader(Uint8List bytes) {
    if (bytes.length < 44 ||
        bytes[0] != 0x52 || // R
        bytes[1] != 0x49 || // I
        bytes[2] != 0x46 || // F
        bytes[3] != 0x46) {
      return bytes;
    }
    // Walk the chunks to find "data" rather than assuming a 44-byte header.
    var offset = 12;
    final view = ByteData.sublistView(bytes);
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = view.getUint32(offset + 4, Endian.little);
      if (id == 'data') {
        final end = (offset + 8 + size).clamp(0, bytes.length);
        return Uint8List.fromList(bytes.sublist(offset + 8, end));
      }
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }
    return bytes;
  }
}

class GeminiApiException implements Exception {
  final int statusCode;
  final String body;
  const GeminiApiException(this.statusCode, this.body);

  bool get isAuth =>
      (statusCode == 400 && body.contains('API key')) ||
      statusCode == 401 ||
      statusCode == 403;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'GeminiApiException($statusCode)';
}
