import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/auth/domain/auth_validation.dart';

void main() {
  group('email', () {
    test('accepts ordinary addresses', () {
      for (final good in [
        'a@b.co',
        'customer@foodmenu.test',
        'first.last+tag@sub.example.com',
      ]) {
        expect(AuthValidation.email(good), isNull, reason: good);
      }
    });

    test('rejects what is clearly not an address', () {
      for (final bad in ['', '   ', 'nope', 'a@b', 'a@@b.co', 'a b@c.co']) {
        expect(AuthValidation.email(bad), isNotNull, reason: '"$bad"');
      }
    });

    test('trims before judging', () {
      expect(AuthValidation.email('  a@b.co  '), isNull);
    });
  });

  group('newPassword', () {
    test('requires the server minimum', () {
      expect(AuthValidation.newPassword('short'), contains('8'));
      expect(AuthValidation.newPassword('12345678'), isNull);
    });

    test('rejects a password equal to the email, as the server does', () {
      expect(
        AuthValidation.newPassword('a@example.com', email: 'a@example.com'),
        isNotNull,
      );
      expect(
        AuthValidation.newPassword('A@EXAMPLE.COM', email: 'a@example.com'),
        isNotNull,
      );
    });

    test('an email-shaped password for a different address is fine', () {
      expect(
        AuthValidation.newPassword('other@example.com', email: 'a@example.com'),
        isNull,
      );
    });
  });

  group('existingPassword', () {
    test('accepts anything non-empty, so an older password still signs in', () {
      expect(AuthValidation.existingPassword('abc'), isNull);
      expect(AuthValidation.existingPassword(''), isNotNull);
    });
  });

  group('optionalPhone', () {
    test('empty is allowed', () {
      expect(AuthValidation.optionalPhone(''), isNull);
      expect(AuthValidation.optionalPhone('   '), isNull);
    });

    test('counts digits, not characters', () {
      expect(AuthValidation.optionalPhone('+1 (302) 555-0148'), isNull);
      expect(AuthValidation.optionalPhone('(1) 2-3'), isNotNull);
    });
  });

  group('name', () {
    test('is required and names the field it wants', () {
      expect(AuthValidation.name('', field: 'first name'), contains('first name'));
      expect(AuthValidation.name('  ', field: 'last name'), isNotNull);
      expect(AuthValidation.name('Ada', field: 'first name'), isNull);
    });
  });
}
