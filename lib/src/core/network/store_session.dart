import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store_session_store.dart';

/// The credentials the WooCommerce Store API hands out to identify a cart.
///
/// Neither value is a login. [cartToken] is a JWT naming a cart — the guest's
/// or the signed-in customer's — and [nonce] is a short-lived token the Store
/// API requires on writes. The API returns both as response headers and
/// expects them echoed back, so they have to be carried between requests.
class StoreSession {
  const StoreSession({this.nonce, this.cartToken});

  /// Value of the `Nonce` response header.
  final String? nonce;

  /// Value of the `Cart-Token` response header.
  final String? cartToken;

  /// True once the API has given us enough to attempt a cart write.
  bool get canWrite => nonce != null;

  StoreSession copyWith({String? nonce, String? cartToken}) => StoreSession(
        nonce: nonce ?? this.nonce,
        cartToken: cartToken ?? this.cartToken,
      );

  @override
  bool operator ==(Object other) =>
      other is StoreSession &&
      other.nonce == nonce &&
      other.cartToken == cartToken;

  @override
  int get hashCode => Object.hash(nonce, cartToken);

  @override
  String toString() =>
      'StoreSession(nonce: ${nonce == null ? 'none' : 'set'}, '
      'cartToken: ${cartToken == null ? 'none' : 'set'})';
}

/// Holds the current [StoreSession], restoring the cart across launches.
///
/// Async because the restore is: the stored cart token is read from secure
/// storage before the first Store API request goes out, which is what makes a
/// cart survive the app being closed. Anything sending that request awaits
/// this first — see `ApiClient`.
///
/// Only the cart token is stored. The nonce comes back on every response and
/// is short-lived, so keeping it would buy nothing.
class StoreSessionNotifier extends AsyncNotifier<StoreSession> {
  @override
  Future<StoreSession> build() async {
    final cartToken = await ref.read(storeSessionStoreProvider).read();
    return StoreSession(cartToken: cartToken);
  }

  StoreSession get _current => state.value ?? const StoreSession();

  /// Records whatever the API just told us, ignoring absent values so a
  /// response that carries only one header does not erase the other.
  ///
  /// A **new** cart token is persisted. The server reissues one whenever it
  /// feels like it — including on the very first response — so writing on
  /// change rather than once is what keeps the stored copy usable.
  void absorb({String? nonce, String? cartToken}) {
    final current = _current;
    final next = current.copyWith(nonce: nonce, cartToken: cartToken);
    if (next == current) return;

    state = AsyncData(next);

    final token = next.cartToken;
    if (token != null && token != current.cartToken) {
      // Not awaited: a cart write must not wait on the keystore, and a failed
      // persist costs this cart its next launch and nothing more.
      unawaited(ref.read(storeSessionStoreProvider).write(token));
    }
  }

  /// Drops the cart identity, e.g. after an order is placed or on sign-out.
  ///
  /// Clears the stored copy too — otherwise the next launch would restore a
  /// cart the customer has already paid for.
  Future<void> clear() async {
    state = const AsyncData(StoreSession());
    await ref.read(storeSessionStoreProvider).clear();
  }
}

final storeSessionProvider =
    AsyncNotifierProvider<StoreSessionNotifier, StoreSession>(
  StoreSessionNotifier.new,
);
