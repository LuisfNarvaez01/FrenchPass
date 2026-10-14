/// French conjugation for the verbs in [Verbs], built from the rules of the
/// three groups plus tables for the irregular verbs -- so a hundred verbs
/// in four tenses don't have to be written out by hand.
library;

enum Tense { present, passeCompose, imparfait, futur }

extension TenseLabel on Tense {
  String get labelEs => switch (this) {
        Tense.present => 'Presente',
        Tense.passeCompose => 'Pasado compuesto',
        Tense.imparfait => 'Imperfecto',
        Tense.futur => 'Futuro',
      };

  String get labelFr => switch (this) {
        Tense.present => 'présent',
        Tense.passeCompose => 'passé composé',
        Tense.imparfait => 'imparfait',
        Tense.futur => 'futur simple',
      };

  /// When to use it, in one line.
  String get useEs => switch (this) {
        Tense.present => 'Lo que pasa ahora o siempre.',
        Tense.passeCompose =>
          'Una acción terminada: «ayer comí», «he viajado».',
        Tense.imparfait =>
          'Lo que pasaba o solía pasar, y las descripciones del pasado.',
        Tense.futur => 'Lo que pasará.',
      };
}

enum Person { je, tu, il, nous, vous, ils }

extension PersonLabel on Person {
  String get label => switch (this) {
        Person.je => 'je',
        Person.tu => 'tu',
        Person.il => 'il / elle',
        Person.nous => 'nous',
        Person.vous => 'vous',
        Person.ils => 'ils / elles',
      };

  String get subject => switch (this) {
        Person.je => 'je',
        Person.tu => 'tu',
        Person.il => 'il',
        Person.nous => 'nous',
        Person.vous => 'vous',
        Person.ils => 'ils',
      };

  String get reflexive => switch (this) {
        Person.je => 'me',
        Person.tu => 'te',
        Person.il || Person.ils => 'se',
        Person.nous => 'nous',
        Person.vous => 'vous',
      };
}

/// Forms that the rules can't produce.
class Irregular {
  /// Present, je to ils.
  final List<String> present;
  final String participle;

  /// Future and conditional stem, ending in "r".
  final String futureStem;

  /// Only être: everything else builds it from the nous form.
  final String? imparfaitStem;

  const Irregular({
    required this.present,
    required this.participle,
    required this.futureStem,
    this.imparfaitStem,
  });
}

class Verb {
  /// Without the reflexive pronoun: "lever" for "se lever".
  final String infinitive;
  final String es;
  final bool pronominal;

  /// Takes être in the passé composé (pronominal verbs always do).
  final bool etre;
  final Irregular? irregular;

  const Verb(
    this.infinitive,
    this.es, {
    this.pronominal = false,
    this.etre = false,
    this.irregular,
  });

  /// As a dictionary shows it: "se lever", "s'habiller", "aller".
  String get display => pronominal
      ? (startsWithVowelSound(infinitive) ? "s'$infinitive" : 'se $infinitive')
      : infinitive;

  bool get usesEtre => etre || pronominal;
  bool get isIrregular => irregular != null;
}

bool startsWithVowelSound(String word) =>
    word.isNotEmpty && 'aeiouyéèêëàâîïôûh'.contains(word[0].toLowerCase());

/// "je" + "aime" → "j'aime"; "me" + "appelle" → "m'appelle".
String _elide(String pronoun, String next) {
  if (startsWithVowelSound(next) &&
      (pronoun == 'je' ||
          pronoun == 'me' ||
          pronoun == 'te' ||
          pronoun == 'se')) {
    return "${pronoun[0]}'$next";
  }
  return '$pronoun $next';
}

abstract final class Conjugator {
  static const _presentEr = ['e', 'es', 'e', 'ons', 'ez', 'ent'];
  static const _presentIr = ['is', 'is', 'it', 'issons', 'issez', 'issent'];
  static const _presentRe = ['s', 's', '', 'ons', 'ez', 'ent'];
  static const _imparfait = ['ais', 'ais', 'ait', 'ions', 'iez', 'aient'];
  static const _futur = ['ai', 'as', 'a', 'ons', 'ez', 'ont'];

  /// The verb form alone, without pronouns: "lève", "ai mangé".
  static String form(Verb verb, Tense tense, Person person) {
    final i = person.index;
    switch (tense) {
      case Tense.present:
        return _present(verb)[i];
      case Tense.imparfait:
        final stem = verb.irregular?.imparfaitStem ?? _imparfaitStem(verb);
        return _joinStem(stem, _imparfait[i]);
      case Tense.futur:
        return _futureStem(verb) + _futur[i];
      case Tense.passeCompose:
        final aux = verb.usesEtre ? _etre : _avoir;
        return '${aux.present[i]} ${participleFor(verb, person)}';
    }
  }

  /// The full line a learner says: "je me lève", "j'ai mangé",
  /// "nous sommes allé(e)s".
  static String conjugate(Verb verb, Tense tense, Person person) {
    var rest = form(verb, tense, person);
    if (verb.pronominal) rest = _elide(person.reflexive, rest);
    return _elide(person.subject, rest);
  }

  /// With être the participle agrees: shown as "allé(e)", "allé(e)s".
  static String participleFor(Verb verb, Person person) {
    final p = participle(verb);
    if (!verb.usesEtre) return p;
    return switch (person) {
      Person.je || Person.tu => '$p(e)',
      Person.il => p,
      Person.nous => '$p(e)s',
      Person.vous => '$p(e)(s)',
      Person.ils => '${p}s',
    };
  }

  static String participle(Verb verb) {
    final irregular = verb.irregular;
    if (irregular != null) return irregular.participle;
    final inf = verb.infinitive;
    final stem = inf.substring(0, inf.length - 2);
    if (inf.endsWith('er')) return '$stemé';
    if (inf.endsWith('ir')) return '${stem}i';
    return '${stem}u';
  }

  // ── Present ───────────────────────────────────────────────────────────────
  static List<String> _present(Verb verb) {
    final irregular = verb.irregular;
    if (irregular != null) return irregular.present;
    final inf = verb.infinitive;
    final stem = inf.substring(0, inf.length - 2);
    if (inf.endsWith('ir')) return [for (final e in _presentIr) stem + e];
    if (inf.endsWith('re')) return [for (final e in _presentRe) stem + e];
    return [
      for (final (i, ending) in _presentEr.indexed)
        _erStem(inf, stem, mute: i != 3 && i != 4, ending: ending) + ending,
    ];
  }

  /// The -er stem with its spelling changes. [mute] endings (e, es, ent,
  /// and the future) open or double the stem vowel; "-ons" keeps the c/g
  /// soft.
  static String _erStem(String inf, String stem,
      {required bool mute, String ending = ''}) {
    if (mute) {
      if (_doubles.contains(inf)) {
        return stem + stem[stem.length - 1];
      }
      // payer, essayer, nettoyer: y → i before a silent ending.
      if (stem.endsWith('y')) {
        return '${stem.substring(0, stem.length - 1)}i';
      }
      final open =
          RegExp(r'[eé]([^aeiouyéèêëàâîïôû]|[bcdfgptv][rl])$').firstMatch(stem);
      if (open != null) {
        final at = open.start;
        return '${stem.substring(0, at)}è${stem.substring(at + 1)}';
      }
      return stem;
    }
    if (ending.startsWith('o') || ending.startsWith('a')) {
      if (stem.endsWith('c')) return '${stem.substring(0, stem.length - 1)}ç';
      if (stem.endsWith('g')) return '${stem}e';
    }
    return stem;
  }

  // ── Imparfait ─────────────────────────────────────────────────────────────
  static String _imparfaitStem(Verb verb) {
    final nous = _present(verb)[3];
    return nous.substring(0, nous.length - 3);
  }

  /// "commenç" + "ions" → "commencions"; "mange" + "ions" → "mangions".
  static String _joinStem(String stem, String ending) {
    if (ending.startsWith('i')) {
      if (stem.endsWith('ç')) {
        return '${stem.substring(0, stem.length - 1)}c$ending';
      }
      if (stem.endsWith('ge')) {
        return '${stem.substring(0, stem.length - 1)}$ending';
      }
    }
    return stem + ending;
  }

  // ── Future ────────────────────────────────────────────────────────────────
  static String _futureStem(Verb verb) {
    final irregular = verb.irregular;
    if (irregular != null) return irregular.futureStem;
    final inf = verb.infinitive;
    if (inf.endsWith('re')) return inf.substring(0, inf.length - 1);
    if (inf.endsWith('ir')) return inf;
    final stem = inf.substring(0, inf.length - 2);
    // préférer keeps its é in the future (préférerai); the e-verbs open.
    if (RegExp(r'é([^aeiouyéèêëàâîïôû]|[bcdfgptv][rl])$').hasMatch(stem)) {
      return inf;
    }
    return '${_erStem(inf, stem, mute: true)}er';
  }

  static const _doubles = {'appeler', 'rappeler', 'jeter'};

  static const _etre = Irregular(
    present: ['suis', 'es', 'est', 'sommes', 'êtes', 'sont'],
    participle: 'été',
    futureStem: 'ser',
    imparfaitStem: 'ét',
  );

  static const _avoir = Irregular(
    present: ['ai', 'as', 'a', 'avons', 'avez', 'ont'],
    participle: 'eu',
    futureStem: 'aur',
  );
}

/// The verbs the app teaches, most useful first.
abstract final class Verbs {
  static Verb? byInfinitive(String infinitive) {
    for (final v in all) {
      if (v.infinitive == infinitive || v.display == infinitive) return v;
    }
    return null;
  }

  static const List<Verb> all = [
    Verb('être', 'ser / estar', irregular: Conjugator._etre),
    Verb('avoir', 'tener / haber', irregular: Conjugator._avoir),
    Verb('aller', 'ir',
        etre: true,
        irregular: Irregular(
          present: ['vais', 'vas', 'va', 'allons', 'allez', 'vont'],
          participle: 'allé',
          futureStem: 'ir',
        )),
    Verb('faire', 'hacer',
        irregular: Irregular(
          present: ['fais', 'fais', 'fait', 'faisons', 'faites', 'font'],
          participle: 'fait',
          futureStem: 'fer',
        )),
    Verb('pouvoir', 'poder',
        irregular: Irregular(
          present: ['peux', 'peux', 'peut', 'pouvons', 'pouvez', 'peuvent'],
          participle: 'pu',
          futureStem: 'pourr',
        )),
    Verb('vouloir', 'querer',
        irregular: Irregular(
          present: ['veux', 'veux', 'veut', 'voulons', 'voulez', 'veulent'],
          participle: 'voulu',
          futureStem: 'voudr',
        )),
    Verb('devoir', 'deber / tener que',
        irregular: Irregular(
          present: ['dois', 'dois', 'doit', 'devons', 'devez', 'doivent'],
          participle: 'dû',
          futureStem: 'devr',
        )),
    Verb('savoir', 'saber',
        irregular: Irregular(
          present: ['sais', 'sais', 'sait', 'savons', 'savez', 'savent'],
          participle: 'su',
          futureStem: 'saur',
        )),
    Verb('venir', 'venir',
        etre: true,
        irregular: Irregular(
          present: ['viens', 'viens', 'vient', 'venons', 'venez', 'viennent'],
          participle: 'venu',
          futureStem: 'viendr',
        )),
    Verb('dire', 'decir',
        irregular: Irregular(
          present: ['dis', 'dis', 'dit', 'disons', 'dites', 'disent'],
          participle: 'dit',
          futureStem: 'dir',
        )),
    Verb('voir', 'ver',
        irregular: Irregular(
          present: ['vois', 'vois', 'voit', 'voyons', 'voyez', 'voient'],
          participle: 'vu',
          futureStem: 'verr',
        )),
    Verb('prendre', 'tomar',
        irregular: Irregular(
          present: [
            'prends', 'prends', 'prend', 'prenons', 'prenez', 'prennent', //
          ],
          participle: 'pris',
          futureStem: 'prendr',
        )),
    Verb('mettre', 'poner',
        irregular: Irregular(
          present: ['mets', 'mets', 'met', 'mettons', 'mettez', 'mettent'],
          participle: 'mis',
          futureStem: 'mettr',
        )),
    Verb('parler', 'hablar'),
    Verb('aimer', 'amar / gustar'),
    Verb('manger', 'comer'),
    Verb('travailler', 'trabajar'),
    Verb('habiter', 'vivir (en un lugar)'),
    Verb('regarder', 'mirar'),
    Verb('écouter', 'escuchar'),
    Verb('chercher', 'buscar'),
    Verb('trouver', 'encontrar'),
    Verb('donner', 'dar'),
    Verb('penser', 'pensar'),
    Verb('jouer', 'jugar / tocar'),
    Verb('chanter', 'cantar'),
    Verb('danser', 'bailar'),
    Verb('marcher', 'caminar'),
    Verb('aider', 'ayudar'),
    Verb('demander', 'pedir / preguntar'),
    Verb('oublier', 'olvidar'),
    Verb('étudier', 'estudiar'),
    Verb('cuisiner', 'cocinar'),
    Verb('fermer', 'cerrar'),
    Verb('porter', 'llevar'),
    Verb('montrer', 'mostrar'),
    Verb('utiliser', 'usar'),
    Verb('visiter', 'visitar'),
    Verb('inviter', 'invitar'),
    Verb('gagner', 'ganar'),
    Verb('réserver', 'reservar'),
    Verb('arriver', 'llegar', etre: true),
    Verb('entrer', 'entrar', etre: true),
    Verb('rester', 'quedarse', etre: true),
    Verb('tomber', 'caer', etre: true),
    Verb('monter', 'subir', etre: true),
    Verb('rentrer', 'volver a casa', etre: true),
    Verb('commencer', 'empezar'),
    Verb('voyager', 'viajar'),
    Verb('nager', 'nadar'),
    Verb('changer', 'cambiar'),
    Verb('acheter', 'comprar'),
    Verb('préférer', 'preferir'),
    Verb('espérer', 'esperar (desear)'),
    Verb('répéter', 'repetir'),
    Verb('appeler', 'llamar'),
    Verb('jeter', 'tirar'),
    Verb('payer', 'pagar'),
    Verb('essayer', 'intentar / probar'),
    Verb('nettoyer', 'limpiar'),
    Verb('envoyer', 'enviar',
        irregular: Irregular(
          present: [
            'envoie', 'envoies', 'envoie', 'envoyons', 'envoyez', 'envoient', //
          ],
          participle: 'envoyé',
          futureStem: 'enverr',
        )),
    Verb('lever', 'levantarse', pronominal: true),
    Verb('laver', 'lavarse', pronominal: true),
    Verb('coucher', 'acostarse', pronominal: true),
    Verb('promener', 'pasear', pronominal: true),
    Verb('reposer', 'descansar', pronominal: true),
    Verb('appeler', 'llamarse', pronominal: true),
    Verb('dépêcher', 'darse prisa', pronominal: true),
    Verb('habiller', 'vestirse', pronominal: true),
    Verb('réveiller', 'despertarse', pronominal: true),
    Verb('amuser', 'divertirse', pronominal: true),
    Verb('finir', 'terminar'),
    Verb('choisir', 'elegir'),
    Verb('réussir', 'lograr / aprobar'),
    Verb('grandir', 'crecer'),
    Verb('réfléchir', 'reflexionar'),
    Verb('remplir', 'llenar'),
    Verb('attendre', 'esperar'),
    Verb('vendre', 'vender'),
    Verb('répondre', 'responder'),
    Verb('perdre', 'perder'),
    Verb('entendre', 'oír'),
    Verb('descendre', 'bajar', etre: true),
    Verb('rendre', 'devolver'),
    Verb('connaître', 'conocer',
        irregular: Irregular(
          present: [
            'connais', 'connais', 'connaît', 'connaissons', 'connaissez', //
            'connaissent',
          ],
          participle: 'connu',
          futureStem: 'connaîtr',
        )),
    Verb('croire', 'creer',
        irregular: Irregular(
          present: ['crois', 'crois', 'croit', 'croyons', 'croyez', 'croient'],
          participle: 'cru',
          futureStem: 'croir',
        )),
    Verb('partir', 'irse',
        etre: true,
        irregular: Irregular(
          present: ['pars', 'pars', 'part', 'partons', 'partez', 'partent'],
          participle: 'parti',
          futureStem: 'partir',
        )),
    Verb('sortir', 'salir',
        etre: true,
        irregular: Irregular(
          present: ['sors', 'sors', 'sort', 'sortons', 'sortez', 'sortent'],
          participle: 'sorti',
          futureStem: 'sortir',
        )),
    Verb('dormir', 'dormir',
        irregular: Irregular(
          present: ['dors', 'dors', 'dort', 'dormons', 'dormez', 'dorment'],
          participle: 'dormi',
          futureStem: 'dormir',
        )),
    Verb('sentir', 'sentir',
        irregular: Irregular(
          present: ['sens', 'sens', 'sent', 'sentons', 'sentez', 'sentent'],
          participle: 'senti',
          futureStem: 'sentir',
        )),
    Verb('servir', 'servir',
        irregular: Irregular(
          present: ['sers', 'sers', 'sert', 'servons', 'servez', 'servent'],
          participle: 'servi',
          futureStem: 'servir',
        )),
    Verb('ouvrir', 'abrir',
        irregular: Irregular(
          present: ['ouvre', 'ouvres', 'ouvre', 'ouvrons', 'ouvrez', 'ouvrent'],
          participle: 'ouvert',
          futureStem: 'ouvrir',
        )),
    Verb('offrir', 'regalar / ofrecer',
        irregular: Irregular(
          present: ['offre', 'offres', 'offre', 'offrons', 'offrez', 'offrent'],
          participle: 'offert',
          futureStem: 'offrir',
        )),
    Verb('tenir', 'sostener',
        irregular: Irregular(
          present: ['tiens', 'tiens', 'tient', 'tenons', 'tenez', 'tiennent'],
          participle: 'tenu',
          futureStem: 'tiendr',
        )),
    Verb('lire', 'leer',
        irregular: Irregular(
          present: ['lis', 'lis', 'lit', 'lisons', 'lisez', 'lisent'],
          participle: 'lu',
          futureStem: 'lir',
        )),
    Verb('écrire', 'escribir',
        irregular: Irregular(
          present: [
            'écris', 'écris', 'écrit', 'écrivons', 'écrivez', 'écrivent', //
          ],
          participle: 'écrit',
          futureStem: 'écrir',
        )),
    Verb('boire', 'beber',
        irregular: Irregular(
          present: ['bois', 'bois', 'boit', 'buvons', 'buvez', 'boivent'],
          participle: 'bu',
          futureStem: 'boir',
        )),
    Verb('vivre', 'vivir',
        irregular: Irregular(
          present: ['vis', 'vis', 'vit', 'vivons', 'vivez', 'vivent'],
          participle: 'vécu',
          futureStem: 'vivr',
        )),
    Verb('courir', 'correr',
        irregular: Irregular(
          present: ['cours', 'cours', 'court', 'courons', 'courez', 'courent'],
          participle: 'couru',
          futureStem: 'courr',
        )),
    Verb('recevoir', 'recibir',
        irregular: Irregular(
          present: [
            'reçois', 'reçois', 'reçoit', 'recevons', 'recevez', 'reçoivent', //
          ],
          participle: 'reçu',
          futureStem: 'recevr',
        )),
    Verb('apprendre', 'aprender',
        irregular: Irregular(
          present: [
            'apprends', 'apprends', 'apprend', 'apprenons', 'apprenez', //
            'apprennent',
          ],
          participle: 'appris',
          futureStem: 'apprendr',
        )),
    Verb('comprendre', 'entender',
        irregular: Irregular(
          present: [
            'comprends', 'comprends', 'comprend', 'comprenons', 'comprenez', //
            'comprennent',
          ],
          participle: 'compris',
          futureStem: 'comprendr',
        )),
    Verb('conduire', 'conducir',
        irregular: Irregular(
          present: [
            'conduis', 'conduis', 'conduit', 'conduisons', 'conduisez', //
            'conduisent',
          ],
          participle: 'conduit',
          futureStem: 'conduir',
        )),
    Verb('mourir', 'morir',
        etre: true,
        irregular: Irregular(
          present: ['meurs', 'meurs', 'meurt', 'mourons', 'mourez', 'meurent'],
          participle: 'mort',
          futureStem: 'mourr',
        )),
    Verb('naître', 'nacer',
        etre: true,
        irregular: Irregular(
          present: ['nais', 'nais', 'naît', 'naissons', 'naissez', 'naissent'],
          participle: 'né',
          futureStem: 'naîtr',
        )),
    Verb('revenir', 'volver',
        etre: true,
        irregular: Irregular(
          present: [
            'reviens', 'reviens', 'revient', 'revenons', 'revenez', //
            'reviennent',
          ],
          participle: 'revenu',
          futureStem: 'reviendr',
        )),
    Verb('devenir', 'llegar a ser',
        etre: true,
        irregular: Irregular(
          present: [
            'deviens', 'deviens', 'devient', 'devenons', 'devenez', //
            'deviennent',
          ],
          participle: 'devenu',
          futureStem: 'deviendr',
        )),
    Verb('souvenir', 'acordarse',
        pronominal: true,
        irregular: Irregular(
          present: [
            'souviens', 'souviens', 'souvient', 'souvenons', 'souvenez', //
            'souviennent',
          ],
          participle: 'souvenu',
          futureStem: 'souviendr',
        )),
    Verb('rire', 'reír',
        irregular: Irregular(
          present: ['ris', 'ris', 'rit', 'rions', 'riez', 'rient'],
          participle: 'ri',
          futureStem: 'rir',
        )),
    Verb('suivre', 'seguir',
        irregular: Irregular(
          present: ['suis', 'suis', 'suit', 'suivons', 'suivez', 'suivent'],
          participle: 'suivi',
          futureStem: 'suivr',
        )),
  ];
}
