import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/core/validators/validators.dart';

void main() {
  group('isValidEmail', () {
    test('valid email returns true', () {
      expect(Validators.isValidEmail('user@example.com'), true);
    });

    test('valid email with subdomain returns true', () {
      expect(Validators.isValidEmail('user@sub.example.com'), true);
    });

    test('valid email with plus sign returns true', () {
      expect(Validators.isValidEmail('user+tag@example.com'), true);
    });

    test('missing @ symbol returns false', () {
      expect(Validators.isValidEmail('userexample.com'), false);
    });

    test('missing domain returns false', () {
      expect(Validators.isValidEmail('user@.com'), false);
    });

    test('empty string returns false', () {
      expect(Validators.isValidEmail(''), false);
    });

    test('no TLD returns false', () {
      expect(Validators.isValidEmail('user@example'), false);
    });
  });

  group('isValidPassword', () {
    test('short password without complexity returns false', () {
      expect(Validators.isValidPassword('abcdef'), false);
    });

    test('long password returns true', () {
      expect(Validators.isValidPassword('aBcDeFgHiJkLmN123!'), true);
    });

    test('5 character password returns false', () {
      expect(Validators.isValidPassword('abcde'), false);
    });

    test('empty password returns false', () {
      expect(Validators.isValidPassword(''), false);
    });
  });

  group('passwordsMatch', () {
    test('identical passwords return true', () {
      expect(Validators.passwordsMatch('password123', 'password123'), true);
    });

    test('different passwords return false', () {
      expect(Validators.passwordsMatch('password123', 'password456'), false);
    });

    test('case sensitive comparison', () {
      expect(Validators.passwordsMatch('Password', 'password'), false);
    });
  });

  group('isValidNickname', () {
    test('2 character nickname returns true', () {
      expect(Validators.isValidNickname('Jo'), true);
    });

    test('20 character nickname returns true', () {
      expect(Validators.isValidNickname('A' * 20), true);
    });

    test('1 character nickname returns false', () {
      expect(Validators.isValidNickname('J'), false);
    });

    test('21 character nickname returns false', () {
      expect(Validators.isValidNickname('A' * 21), false);
    });

    test('whitespace-only after trim returns false', () {
      expect(Validators.isValidNickname('   '), false);
    });

    test('nickname with leading spaces is trimmed then valid', () {
      expect(Validators.isValidNickname('  Jo  '), true);
    });
  });

  group('isValidAge', () {
    test('age 13 returns true', () {
      expect(Validators.isValidAge(13), true);
    });

    test('age 80 returns true', () {
      expect(Validators.isValidAge(80), true);
    });

    test('age 30 returns true', () => expect(Validators.isValidAge(30), true));

    test('age 12 returns false', () {
      expect(Validators.isValidAge(12), false);
    });

    test('age 81 returns false', () {
      expect(Validators.isValidAge(81), false);
    });

    test('age 0 returns false', () => expect(Validators.isValidAge(0), false));
  });

  group('isValidHeight', () {
    test('height 100 returns true', () {
      expect(Validators.isValidHeight(100.0), true);
    });

    test('height 250 returns true', () {
      expect(Validators.isValidHeight(250.0), true);
    });

    test('height 175 returns true', () {
      expect(Validators.isValidHeight(175.0), true);
    });

    test('height 99 returns false', () {
      expect(Validators.isValidHeight(99.0), false);
    });

    test('height 251 returns false', () {
      expect(Validators.isValidHeight(251.0), false);
    });
  });

  group('isValidWeight', () {
    test('weight 20 returns true', () {
      expect(Validators.isValidWeight(20.0), true);
    });

    test('weight 300 returns true', () {
      expect(Validators.isValidWeight(300.0), true);
    });

    test('weight 70 returns true', () {
      expect(Validators.isValidWeight(70.0), true);
    });

    test('weight 19 returns false', () {
      expect(Validators.isValidWeight(19.0), false);
    });

    test('weight 301 returns false', () {
      expect(Validators.isValidWeight(301.0), false);
    });
  });

  group('isValidBudget', () {
    test('budget 20 returns true', () {
      expect(Validators.isValidBudget(20.0), true);
    });

    test('budget 100 returns true', () {
      expect(Validators.isValidBudget(100.0), true);
    });

    test('budget 19 returns false', () {
      expect(Validators.isValidBudget(19.0), false);
    });

    test('budget 0 returns false', () {
      expect(Validators.isValidBudget(0.0), false);
    });
  });

  group('isValidWaterAmount', () {
    test('1 ml returns true', () {
      expect(Validators.isValidWaterAmount(1), true);
    });

    test('5000 ml returns true', () {
      expect(Validators.isValidWaterAmount(5000), true);
    });

    test('250 ml returns true', () {
      expect(Validators.isValidWaterAmount(250), true);
    });

    test('0 ml returns false', () {
      expect(Validators.isValidWaterAmount(0), false);
    });

    test('5001 ml returns false', () {
      expect(Validators.isValidWaterAmount(5001), false);
    });
  });

  group('isValidQuantity', () {
    test('positive quantity returns true', () {
      expect(Validators.isValidQuantity(1.0), true);
    });

    test('zero quantity returns false', () {
      expect(Validators.isValidQuantity(0.0), false);
    });

    test('negative quantity returns false', () {
      expect(Validators.isValidQuantity(-1.0), false);
    });
  });

  group('isPositiveNumber', () {
    test('positive number returns true', () {
      expect(Validators.isPositiveNumber(1.0), true);
    });

    test('zero returns false', () {
      expect(Validators.isPositiveNumber(0.0), false);
    });

    test('negative returns false', () {
      expect(Validators.isPositiveNumber(-0.1), false);
    });
  });
}
