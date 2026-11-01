import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Holds the current [StoreSession] for the app's lifetime.
///
/// In-memory only. Task 4.6 adds persistence so a cart survives an app
/// restart; keeping that behind this notifier means nothing else changes when
/// it does.
class StoreSessionNotifier extends Notifier<StoreSession> {
  @override
  StoreSession build() => const StoreSession();

  /// Records whatever the API just told us, ignoring absent values so a
  /// response that carries only one header does not erase the other.
  void absorb({String? nonce, String? cartToken}) {
    final next = state.copyWith(nonce: nonce, cartToken: cartToken);
    if (next != state) state = next;
  }

  /// Drops the cart identity, e.g. after an order is placed or on sign-out.
  void clear() => state = const StoreSession();
}

final storeSessionProvider =
    NotifierProvider<StoreSessionNotifier, StoreSession>(
  StoreSessionNotifier.new,
);
