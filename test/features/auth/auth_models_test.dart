import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/auth/domain/auth_tokens.dart';
import 'package:food_menu/src/features/auth/domain/auth_user.dart';

void main() {
  group('AuthTokens', () {
    final now = DateTime(2026, 11, 5, 12);

    test('resolves the server lifetimes against the clock', () {
      final tokens = AuthTokens.fromJson(
        const {
          'access_token': 'fmpa_8_a_access',
          'refresh_token': 'fmpa_8_a_refresh',
          'expires_in': 3600,
          'refresh_expires_in': 2592000,
        },
        now: now,
      );

      expect(tokens.accessExpiresAt, now.add(const Duration(hours: 1)));
      expect(tokens.refreshExpiresAt, now.add(const Duration(days: 30)));
      expect(tokens.isUsable, isTrue);
    });

    test('a response missing its tokens is not usable', () {
      final tokens = AuthTokens.fromJson(const {}, now: now);
      expect(tokens.isUsable, isFalse);
    });

    test('accessExpired allows leeway so a token cannot die mid-flight', () {
      final tokens = AuthTokens.fromJson(
        const {
          'access_token': 'a',
          'refresh_token': 'r',
          'expires_in': 20,
          'refresh_expires_in': 100,
        },
        now: now,
      );

      // 20s of life left, but a 30s leeway, so it counts as expired already.
      expect(tokens.accessExpired(now: now), isTrue);
      expect(tokens.accessExpired(now: now, leeway: Duration.zero), isFalse);
    });

    test('refreshExpired tracks its own, longer clock', () {
      final tokens = AuthTokens.fromJson(
        const {
          'access_token': 'a',
          'refresh_token': 'r',
          'expires_in': 10,
          'refresh_expires_in': 100,
        },
        now: now,
      );

      expect(tokens.refreshExpired(now: now), isFalse);
      expect(
        tokens.refreshExpired(now: now.add(const Duration(seconds: 101))),
        isTrue,
      );
    });
  });

  group('AuthUser', () {
    test('parses the server payload', () {
      final user = AuthUser.fromJson(const {
        'id': 8,
        'email': 'customer@foodmenu.test',
        'username': 'test.customer',
        'first_name': 'Test',
        'last_name': 'Customer',
        'display_name': 'Test Customer',
        'phone': '+8801700000000',
        'avatar_url': 'https://example.com/a.png',
      });

      expect(user.id, 8);
      expect(user.greetingName, 'Test Customer');
      expect(user.initials, 'TC');
    });

    test('a nameless account still greets and still has an initial', () {
      final user = AuthUser.fromJson(const {
        'id': 9,
        'email': 'nobody@example.com',
        'display_name': '',
      });

      expect(user.greetingName, 'nobody@example.com');
      expect(user.initials, 'N');
    });

    test('falls back to display_name when only it is set', () {
      final user = AuthUser.fromJson(const {
        'id': 9,
        'email': 'a@b.co',
        'display_name': 'Rick the Legend',
      });

      expect(user.greetingName, 'Rick the Legend');
      expect(user.initials, 'R');
    });

    test('a first name alone gives one initial', () {
      final user = AuthUser.fromJson(const {
        'id': 9,
        'email': 'a@b.co',
        'first_name': 'Ada',
      });

      expect(user.greetingName, 'Ada');
      expect(user.initials, 'A');
    });

    test('tolerates a completely empty object rather than throwing', () {
      final user = AuthUser.fromJson(const {});
      expect(user.id, 0);
      expect(user.initials, '?');
    });
  });
}
