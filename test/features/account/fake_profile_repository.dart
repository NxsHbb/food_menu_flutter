import 'package:food_menu/src/features/account/data/profile_repository.dart';
import 'package:food_menu/src/features/auth/domain/auth_user.dart';

import '../auth/fake_auth_repository.dart';

/// A [ProfileRepository] that answers from memory.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({AuthUser? user, this.delay = Duration.zero})
      : user = user ?? sessionFor().user;

  /// The customer as the server holds them; [update] rewrites this.
  AuthUser user;

  final Duration delay;

  /// Thrown by [update] when set.
  Object? updateError;

  /// Thrown by [me] when set.
  Object? loadError;

  /// Every call, with the body `update` was given.
  final List<Map<String, Object?>> calls = [];

  @override
  Future<AuthUser> me() async {
    calls.add({'call': 'me'});
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (loadError != null) throw loadError!;
    return user;
  }

  @override
  Future<AuthUser> update({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    calls.add({
      'call': 'update',
      // Recorded exactly as passed, so a test can assert that an untouched
      // field was omitted rather than sent as an empty string.
      if (firstName != null) 'first_name': firstName.trim(),
      if (lastName != null) 'last_name': lastName.trim(),
      if (phone != null) 'phone': phone.trim(),
    });
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (updateError != null) throw updateError!;

    user = AuthUser(
      id: user.id,
      email: user.email,
      username: user.username,
      firstName: firstName?.trim() ?? user.firstName,
      lastName: lastName?.trim() ?? user.lastName,
      displayName:
          [firstName ?? user.firstName, lastName ?? user.lastName]
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .join(' '),
      phone: phone?.trim() ?? user.phone,
      avatarUrl: user.avatarUrl,
    );
    return user;
  }
}
