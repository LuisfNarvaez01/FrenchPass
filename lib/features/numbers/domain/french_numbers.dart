/// Numbers and clock times written out in French, by rule, so practice
/// never runs out: "soixante et onze", "quatre-vingts", "deux cent un".
///
/// Uses the traditional spelling (hyphens only below one hundred, "et"
/// in 21, 31... 71), which is still what most people write.
abstract final class FrenchNumbers {
  static const _units = [
    'zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', //
    'huit', 'neuf', 'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze',
    'seize',
  ];
  static const _tens = {
    2: 'vingt',
    3: 'trente',
    4: 'quarante',
    5: 'cinquante',
    6: 'soixante',
  };

  /// 0 to 999 999.
  static String toWords(int n) {
    if (n < 0 || n > 999999) {
      throw RangeError.range(n, 0, 999999, 'n');
    }
    if (n == 0) return _units[0];
    final thousands = n ~/ 1000;
    final rest = n % 1000;
    final parts = <String>[];
    if (thousands > 0) {
      // "mille" never takes "un" or an s; what comes before it never
      // takes the plural s either ("deux cent mille", "quatre-vingt mille").
      parts.add(thousands == 1
          ? 'mille'
          : '${_below1000(thousands, last: false)} mille');
    }
    if (rest > 0) parts.add(_below1000(rest, last: true));
    return parts.join(' ');
  }

  /// [last]: nothing follows, so "cents" and "vingts" keep their s.
  static String _below1000(int n, {required bool last}) {
    final hundreds = n ~/ 100;
    final rest = n % 100;
    final parts = <String>[];
    if (hundreds > 0) {
      final plural = hundreds > 1 && rest == 0 && last;
      parts.add(hundreds == 1
          ? 'cent'
          : '${_units[hundreds]} ${plural ? 'cents' : 'cent'}');
    }
    if (rest > 0) parts.add(_below100(rest, last: last));
    return parts.join(' ');
  }

  static String _below100(int n, {required bool last}) {
    if (n <= 16) return _units[n];
    if (n < 20) return 'dix-${_units[n - 10]}';
    final ten = n ~/ 10;
    final unit = n % 10;
    if (ten <= 6) {
      final word = _tens[ten]!;
      if (unit == 0) return word;
      if (unit == 1) return '$word et un';
      return '$word-${_units[unit]}';
    }
    if (ten == 7) {
      // 70-79: soixante + 10-19.
      return unit == 1
          ? 'soixante et onze'
          : 'soixante-${_below100(10 + unit, last: last)}';
    }
    // 80-99: quatre-vingt(s) + 0-19, never with "et".
    final tail = n - 80;
    if (tail == 0) return last ? 'quatre-vingts' : 'quatre-vingt';
    return 'quatre-vingt-${_below100(tail, last: last)}';
  }

  /// "14:30" as an announcement says it: "quatorze heures trente".
  static String timeOfficial(int hour, int minute) {
    final h = hour == 0
        ? 'zéro heure'
        : hour == 1
            ? 'une heure'
            : '${_feminineOne(toWords(hour))} heures';
    if (minute == 0) return h;
    return '$h ${_feminineOne(toWords(minute))}';
  }

  /// How people say it day to day: "deux heures et demie", "midi moins
  /// le quart".
  static String timeEveryday(int hour, int minute) {
    String name(int h) {
      final h12 = h % 12;
      if (h % 24 == 12) return 'midi';
      if (h % 24 == 0) return 'minuit';
      return h12 == 1 ? 'une heure' : '${toWords(h12)} heures';
    }

    if (minute == 0) return name(hour);
    if (minute == 15) return '${name(hour)} et quart';
    if (minute == 30) {
      final base = name(hour);
      // "midi et demi" is masculine; "deux heures et demie" agrees.
      return '$base et ${base == 'midi' || base == 'minuit' ? 'demi' : 'demie'}';
    }
    if (minute == 45) return '${name(hour + 1)} moins le quart';
    if (minute > 30) {
      return '${name(hour + 1)} moins ${toWords(60 - minute)}';
    }
    return '${name(hour)} ${_feminineOne(toWords(minute))}';
  }

  /// "heure" and "minute" are feminine: "vingt et une heures".
  static String _feminineOne(String words) =>
      words == 'un' ? 'une' : words.replaceAll(RegExp(r'et un$'), 'et une');
}
