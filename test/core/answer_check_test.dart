import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/text/answer_check.dart';

void main() {
  test('exact match ignores case, spacing and closing punctuation', () {
    expect(AnswerCheck.check('  Je Mange. ', 'je mange'), AnswerMatch.exact);
    expect(AnswerCheck.check('j’ai mangé', "j'ai mangé"), AnswerMatch.exact);
    expect(AnswerCheck.check("j' ai mangé", "j'ai mangé"), AnswerMatch.exact);
  });

  test('missing accents are close, not wrong', () {
    expect(AnswerCheck.check('ecole', 'école'), AnswerMatch.accents);
    expect(AnswerCheck.check('je prefere', 'je préfère'), AnswerMatch.accents);
    expect(AnswerMatch.accents.isRight, isTrue);
  });

  test('optional agreement accepts every form', () {
    const expected = 'nous sommes allé(e)s';
    for (final typed in [
      'nous sommes allés',
      'nous sommes allées',
      'nous sommes allé(e)s',
    ]) {
      expect(AnswerCheck.check(typed, expected), AnswerMatch.exact,
          reason: typed);
    }
    expect(AnswerCheck.check('je suis allée', 'je suis allé(e)'),
        AnswerMatch.exact);
  });

  test('a different word is wrong', () {
    expect(AnswerCheck.check('je mangeais', 'je mange'), AnswerMatch.wrong);
    expect(AnswerCheck.check('', 'je mange'), AnswerMatch.wrong);
  });
}
