import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/domain/auth_user.dart';

/// Talks to `fmp/v1/app/me`.
///
/// Only the `user` half of the response is read here. The same endpoint also
/// carries the address book, which task 3.8 adds — it is left unparsed rather
/// than modelled speculatively.
class ProfileRepository {
  const ProfileRepository(this._client);

  final ApiClient _client;

  String get _url => _client.foodMenuApi('app/me');

  /// The signed-in customer, fresh from the server.
  Future<AuthUser> me() async {
    final raw = await _client.get<Map<String, dynamic>>(_url);
    return _user(raw);
  }

  /// Updates the profile and returns the customer as the server now has them.
  ///
  /// **Partial by design.** Only the fields passed here are sent, because the
  /// endpoint treats an absent key as "leave alone" and a present one as
  /// "replace" — sending the whole object would mean this form could wipe the
  /// address book it does not even show.
  Future<AuthUser> update({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final raw = await _client.put<Map<String, dynamic>>(
      _url,
      body: {
        if (firstName != null) 'first_name': firstName.trim(),
        if (lastName != null) 'last_name': lastName.trim(),
        if (phone != null) 'phone': phone.trim(),
      },
    );
    return _user(raw);
  }

  AuthUser _user(Map<String, dynamic> raw) {
    final user = raw['user'];
    if (user is Map) return AuthUser.fromJson(user.cast<String, dynamic>());
    // The route always embeds `user`; falling back to the envelope keeps a
    // shape change from throwing where the fields happen to still be there.
    return AuthUser.fromJson(raw);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});
