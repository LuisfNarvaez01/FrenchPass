import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// One role-play scene the AI tutor can run: a real situation with a clear
/// goal, so a conversation has an end the learner can actually reach.
class Lesson {
  final String id;
  final String emoji;
  final String titleEs;
  final String subtitleEs;
  final CefrLevel level;

  /// Who the tutor plays, in French, as it would introduce itself in-scene.
  final String roleFr;

  /// The scene, described for the tutor (Spanish, it is prompt text).
  final String sceneEs;

  /// What the learner must manage to do for the lesson to count as done.
  final String goalEs;

  /// Phrases worth having ready before starting -- shown on the lesson card
  /// and given to the tutor so its hints stay inside the lesson.
  final List<String> keyPhrasesFr;

  const Lesson({
    required this.id,
    required this.emoji,
    required this.titleEs,
    required this.subtitleEs,
    required this.level,
    required this.roleFr,
    required this.sceneEs,
    required this.goalEs,
    required this.keyPhrasesFr,
  });

  /// The open-ended lesson has no scene goal; the tutor just chats.
  bool get isFreeTalk => id == Lessons.freeTalkId;
}

abstract final class Lessons {
  static const freeTalkId = 'libre';

  static Lesson? byId(String id) {
    for (final lesson in all) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }

  static const all = <Lesson>[
    Lesson(
      id: 'presentarse',
      emoji: '👋',
      titleEs: 'Presentarte',
      subtitleEs: 'Tu nombre, de dónde eres y a qué te dedicas',
      level: CefrLevel.a1,
      roleFr: 'Camille, une voisine sympathique',
      sceneEs:
          'Una fiesta de vecinos en un patio de París. Camille se acerca al '
          'alumno para conocerlo.',
      goalEs: 'El alumno dice su nombre, de dónde es y a qué se dedica, y le '
          'pregunta a Camille al menos una cosa sobre ella.',
      keyPhrasesFr: [
        'Je m’appelle…',
        'Je viens de…',
        'Je suis étudiant / Je travaille comme…',
        'Et vous ?',
      ],
    ),
    Lesson(
      id: 'cafe',
      emoji: '☕',
      titleEs: 'Pedir en un café',
      subtitleEs: 'Pedir algo de beber y de comer, y pagar',
      level: CefrLevel.a1,
      roleFr: 'le serveur du Café de Flore',
      sceneEs: 'Una terraza de un café parisino por la mañana. El tutor es el '
          'camarero y atiende al alumno.',
      goalEs: 'El alumno pide una bebida y algo de comer, pregunta cuánto es y '
          'paga.',
      keyPhrasesFr: [
        'Je voudrais un café, s’il vous plaît.',
        'Avec un croissant.',
        'C’est combien ?',
        'L’addition, s’il vous plaît.',
      ],
    ),
    Lesson(
      id: 'direcciones',
      emoji: '🧭',
      titleEs: 'Preguntar por una dirección',
      subtitleEs: 'Encontrar el metro, una farmacia o un museo',
      level: CefrLevel.a1,
      roleFr: 'un passant pressé mais gentil',
      sceneEs:
          'Una calle de París. El alumno está perdido y para a un transeúnte.',
      goalEs:
          'El alumno pregunta cómo llegar a un sitio concreto, entiende las '
          'indicaciones (puede pedir que las repita) y da las gracias.',
      keyPhrasesFr: [
        'Excusez-moi, où est le métro ?',
        'C’est loin ?',
        'Tout droit, à gauche, à droite',
        'Vous pouvez répéter, s’il vous plaît ?',
      ],
    ),
    Lesson(
      id: 'panaderia',
      emoji: '🥖',
      titleEs: 'En la panadería',
      subtitleEs: 'Cantidades, precios y cortesía',
      level: CefrLevel.a1,
      roleFr: 'la boulangère',
      sceneEs: 'Una panadería de barrio. Hay cola y la panadera es amable.',
      goalEs: 'El alumno saluda, pide dos cosas con cantidades (una baguette, '
          'dos croissants…), pregunta el precio y se despide.',
      keyPhrasesFr: [
        'Bonjour madame !',
        'Une baguette, s’il vous plaît.',
        'Deux pains au chocolat.',
        'Ce sera tout, merci.',
      ],
    ),
    Lesson(
      id: 'hotel',
      emoji: '🏨',
      titleEs: 'Llegar al hotel',
      subtitleEs: 'Reserva, habitación y horarios',
      level: CefrLevel.a2,
      roleFr: 'le réceptionniste de l’hôtel',
      sceneEs: 'La recepción de un pequeño hotel en Lyon.',
      goalEs:
          'El alumno hace el check-in con su reserva, pregunta a qué hora es '
          'el desayuno y pide algo para la habitación (toallas, wifi…).',
      keyPhrasesFr: [
        'J’ai une réservation au nom de…',
        'Le petit-déjeuner est à quelle heure ?',
        'Quel est le code du wifi ?',
        'Il n’y a pas de serviettes.',
      ],
    ),
    Lesson(
      id: 'restaurante',
      emoji: '🍽️',
      titleEs: 'Cenar en un restaurante',
      subtitleEs: 'Pedir el menú, alergias y la cuenta',
      level: CefrLevel.a2,
      roleFr: 'la serveuse d’un bistrot',
      sceneEs: 'Un bistrot por la noche. El alumno llega sin reserva.',
      goalEs: 'El alumno pide mesa, elige entrante y plato, menciona una '
          'alergia o preferencia y pide la cuenta.',
      keyPhrasesFr: [
        'Une table pour deux, s’il vous plaît.',
        'Qu’est-ce que vous me conseillez ?',
        'Je suis allergique aux…',
        'Je vais prendre…',
      ],
    ),
    Lesson(
      id: 'compras',
      emoji: '👕',
      titleEs: 'Comprar ropa',
      subtitleEs: 'Tallas, colores y probarse algo',
      level: CefrLevel.a2,
      roleFr: 'le vendeur d’une boutique',
      sceneEs: 'Una tienda de ropa en el centro. El vendedor quiere ayudar.',
      goalEs: 'El alumno busca una prenda concreta, pide otra talla o color, '
          'pregunta si puede probársela y decide si la compra.',
      keyPhrasesFr: [
        'Je cherche un pull.',
        'Vous l’avez en taille M ?',
        'Je peux l’essayer ?',
        'C’est un peu trop grand.',
      ],
    ),
    Lesson(
      id: 'tren',
      emoji: '🚆',
      titleEs: 'Comprar un billete de tren',
      subtitleEs: 'Destino, horario e ida y vuelta',
      level: CefrLevel.a2,
      roleFr: 'l’agent au guichet de la gare',
      sceneEs: 'La ventanilla de la Gare de Lyon.',
      goalEs:
          'El alumno compra un billete con destino, día y hora, elige ida o '
          'ida y vuelta y pregunta de qué andén sale.',
      keyPhrasesFr: [
        'Un billet pour Marseille, s’il vous plaît.',
        'Un aller-retour.',
        'Le prochain train part à quelle heure ?',
        'C’est quel quai ?',
      ],
    ),
    Lesson(
      id: 'farmacia',
      emoji: '💊',
      titleEs: 'En la farmacia',
      subtitleEs: 'Explicar qué te pasa',
      level: CefrLevel.a2,
      roleFr: 'la pharmacienne',
      sceneEs: 'Una farmacia. El alumno no se encuentra bien.',
      goalEs:
          'El alumno explica dos síntomas, responde desde cuándo los tiene y '
          'entiende cómo tomar lo que le recomiendan.',
      keyPhrasesFr: [
        'J’ai mal à la tête.',
        'J’ai de la fièvre depuis hier.',
        'Je dois le prendre combien de fois ?',
        'Je n’ai pas d’ordonnance.',
      ],
    ),
    Lesson(
      id: 'aficiones',
      emoji: '🎨',
      titleEs: 'Hablar de tus aficiones',
      subtitleEs: 'Lo que te gusta hacer y por qué',
      level: CefrLevel.a2,
      roleFr: 'Léo, un ami d’un ami',
      sceneEs: 'Una charla relajada tomando algo con alguien que acabas de '
          'conocer.',
      goalEs: 'El alumno cuenta dos aficiones, dice con qué frecuencia las '
          'practica y por qué le gustan, y pregunta por las de Léo.',
      keyPhrasesFr: [
        'J’aime beaucoup…',
        'Le week-end, je…',
        'Parce que c’est…',
        'Et toi, qu’est-ce que tu aimes faire ?',
      ],
    ),
    Lesson(
      id: 'planes',
      emoji: '📅',
      titleEs: 'Quedar con un amigo',
      subtitleEs: 'Proponer, aceptar y cambiar planes',
      level: CefrLevel.b1,
      roleFr: 'Inès, une amie',
      sceneEs: 'Una llamada con una amiga para organizar el sábado.',
      goalEs: 'El alumno propone un plan, negocia hora y lugar, rechaza '
          'amablemente una alternativa y confirma.',
      keyPhrasesFr: [
        'Ça te dit d’aller… ?',
        'On se retrouve à quelle heure ?',
        'Je ne peux pas, mais on pourrait…',
        'D’accord, à samedi !',
      ],
    ),
    Lesson(
      id: 'entrevista',
      emoji: '💼',
      titleEs: 'Entrevista de trabajo',
      subtitleEs: 'Experiencia, fortalezas y preguntas',
      level: CefrLevel.b1,
      roleFr: 'Madame Laurent, responsable du recrutement',
      sceneEs: 'Una entrevista para un puesto en una empresa francesa.',
      goalEs: 'El alumno se presenta profesionalmente, describe su experiencia '
          'en pasado, da una fortaleza con un ejemplo y hace una pregunta '
          'sobre el puesto.',
      keyPhrasesFr: [
        'J’ai travaillé pendant deux ans comme…',
        'Mon point fort, c’est…',
        'Par exemple, …',
        'Quelles sont les missions du poste ?',
      ],
    ),
    Lesson(
      id: freeTalkId,
      emoji: '💬',
      titleEs: 'Conversación libre',
      subtitleEs: 'Habla de lo que quieras, en francés',
      level: CefrLevel.a2,
      roleFr: 'ton professeur de français',
      sceneEs: 'Charla abierta. El tutor propone temas según los intereses y '
          'puntos débiles del alumno.',
      goalEs: 'No hay objetivo cerrado: mantener una conversación natural.',
      keyPhrasesFr: [
        'Je ne comprends pas.',
        'Comment on dit… en français ?',
        'Vous pouvez parler plus lentement ?',
      ],
    ),
  ];
}
