import 'package:equatable/equatable.dart';

enum PronunciationFeedback { parfait, tresBien, biensur, reessaie }

extension PronunciationFeedbackExtension on PronunciationFeedback {
  String get labelEs => switch (this) {
    PronunciationFeedback.parfait   => '¡Parfait! 🌟',
    PronunciationFeedback.tresBien  => '¡Très bien! 👏',
    PronunciationFeedback.biensur   => '¡Bien sûr! 💪',
    PronunciationFeedback.reessaie  => 'Réessaie... 🎯',
  };

  String get subtitle => switch (this) {
    PronunciationFeedback.parfait   => 'Pronunciación perfecta',
    PronunciationFeedback.tresBien  => 'Muy buena pronunciación',
    PronunciationFeedback.biensur   => 'Puedes mejorar un poco',
    PronunciationFeedback.reessaie  => 'Sigue practicando',
  };
}

class PronunciationResult extends Equatable {
  final String recognizedText;
  final double overallScore;   // 0.0 – 1.0
  final double clarityScore;
  final double accentScore;
  final double rhythmScore;
  final PronunciationFeedback feedback;

  const PronunciationResult({
    required this.recognizedText,
    required this.overallScore,
    required this.clarityScore,
    required this.accentScore,
    required this.rhythmScore,
    required this.feedback,
  });

  int get overallPercent => (overallScore * 100).round();
  int get clarityPercent => (clarityScore * 100).round();
  int get accentPercent  => (accentScore  * 100).round();
  int get rhythmPercent  => (rhythmScore  * 100).round();
  bool get isSuccess     => overallScore >= 0.7;

  @override
  List<Object?> get props => [recognizedText, overallScore];
}
