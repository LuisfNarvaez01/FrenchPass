import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/conjugation/domain/conjugator.dart';

Verb _v(String display) => Verbs.all.firstWhere((v) => v.display == display);

String _c(String verb, Tense tense, Person person) =>
    Conjugator.conjugate(_v(verb), tense, person);

List<String> _all(String verb, Tense tense) =>
    [for (final p in Person.values) _c(verb, tense, p)];

void main() {
  group('present', () {
    test('regular -er, with elision', () {
      expect(_all('aimer', Tense.present), [
        "j'aime", 'tu aimes', 'il aime', 'nous aimons', 'vous aimez',
        'ils aiment', //
      ]);
    });

    test('-cer and -ger keep the soft sound before -ons', () {
      expect(_c('commencer', Tense.present, Person.nous), 'nous commençons');
      expect(_c('manger', Tense.present, Person.nous), 'nous mangeons');
    });

    test('e and é open to è before a silent ending', () {
      expect(_all('acheter', Tense.present), [
        "j'achète", 'tu achètes', 'il achète', 'nous achetons',
        'vous achetez', 'ils achètent', //
      ]);
      expect(_c('préférer', Tense.present, Person.je), 'je préfère');
      expect(_c('préférer', Tense.present, Person.nous), 'nous préférons');
    });

    test('appeler and jeter double their consonant', () {
      expect(_c('appeler', Tense.present, Person.je), "j'appelle");
      expect(_c('jeter', Tense.present, Person.ils), 'ils jettent');
      expect(_c('appeler', Tense.present, Person.vous), 'vous appelez');
    });

    test('-yer verbs turn y into i', () {
      expect(_c('payer', Tense.present, Person.je), 'je paie');
      expect(_c('nettoyer', Tense.present, Person.nous), 'nous nettoyons');
    });

    test('second group and -re verbs', () {
      expect(_all('finir', Tense.present), [
        'je finis', 'tu finis', 'il finit', 'nous finissons',
        'vous finissez', 'ils finissent', //
      ]);
      expect(_c('attendre', Tense.present, Person.il), 'il attend');
    });

    test('pronominal verbs carry their pronoun', () {
      expect(_all('se lever', Tense.present), [
        'je me lève', 'tu te lèves', 'il se lève', 'nous nous levons',
        'vous vous levez', 'ils se lèvent', //
      ]);
      expect(_c("s'appeler", Tense.present, Person.je), "je m'appelle");
      expect(_c("s'habiller", Tense.present, Person.il), "il s'habille");
    });

    test('irregular verbs come from their table', () {
      expect(_all('aller', Tense.present), [
        'je vais', 'tu vas', 'il va', 'nous allons', 'vous allez',
        'ils vont', //
      ]);
      expect(_c('avoir', Tense.present, Person.je), "j'ai");
    });
  });

  group('passé composé', () {
    test('with avoir', () {
      expect(_c('manger', Tense.passeCompose, Person.je), "j'ai mangé");
      expect(_c('finir', Tense.passeCompose, Person.nous), 'nous avons fini');
      expect(_c('vendre', Tense.passeCompose, Person.ils), 'ils ont vendu');
      expect(_c('faire', Tense.passeCompose, Person.il), 'il a fait');
    });

    test('with être, showing the agreement', () {
      expect(_c('aller', Tense.passeCompose, Person.je), 'je suis allé(e)');
      expect(_c('aller', Tense.passeCompose, Person.ils), 'ils sont allés');
      expect(_c('se lever', Tense.passeCompose, Person.il), "il s'est levé");
      expect(
          _c('se lever', Tense.passeCompose, Person.je), 'je me suis levé(e)');
    });
  });

  group('imparfait', () {
    test('built from the nous form', () {
      expect(_all('parler', Tense.imparfait), [
        'je parlais', 'tu parlais', 'il parlait', 'nous parlions',
        'vous parliez', 'ils parlaient', //
      ]);
      expect(_c('finir', Tense.imparfait, Person.je), 'je finissais');
      expect(_c('faire', Tense.imparfait, Person.il), 'il faisait');
    });

    test('c and g only change before a and o', () {
      expect(_c('commencer', Tense.imparfait, Person.je), 'je commençais');
      expect(_c('commencer', Tense.imparfait, Person.nous), 'nous commencions');
      expect(_c('manger', Tense.imparfait, Person.je), 'je mangeais');
      expect(_c('manger', Tense.imparfait, Person.vous), 'vous mangiez');
    });

    test('être is the exception', () {
      expect(_c('être', Tense.imparfait, Person.je), "j'étais");
    });
  });

  group('futur', () {
    test('regular verbs build on the infinitive', () {
      expect(_all('parler', Tense.futur), [
        'je parlerai', 'tu parleras', 'il parlera', 'nous parlerons',
        'vous parlerez', 'ils parleront', //
      ]);
      expect(_c('vendre', Tense.futur, Person.je), 'je vendrai');
      expect(_c('finir', Tense.futur, Person.nous), 'nous finirons');
    });

    test('spelling changes and irregular stems', () {
      expect(_c('acheter', Tense.futur, Person.je), "j'achèterai");
      expect(_c('appeler', Tense.futur, Person.je), "j'appellerai");
      expect(_c('payer', Tense.futur, Person.je), 'je paierai');
      expect(_c('préférer', Tense.futur, Person.je), 'je préférerai');
      expect(_c('aller', Tense.futur, Person.je), "j'irai");
      expect(_c('envoyer', Tense.futur, Person.il), 'il enverra');
    });
  });

  test('every verb conjugates in every tense', () {
    for (final verb in Verbs.all) {
      for (final tense in Tense.values) {
        for (final person in Person.values) {
          expect(Conjugator.conjugate(verb, tense, person), isNotEmpty);
        }
      }
    }
  });

  test('verb names are unique', () {
    final names = Verbs.all.map((v) => v.display).toList();
    expect(names.toSet().length, names.length);
  });
}
