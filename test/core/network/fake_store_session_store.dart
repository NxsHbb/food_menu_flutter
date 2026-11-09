import 'dart:convert';

import 'package:food_menu/src/core/network/store_session_store.dart';

/// An in-memory [StoreSessionStore], so tests never touch the keystore.
class FakeStoreSessionStore implements StoreSessionStore {
  FakeStoreSessionStore({this.stored});

  String? stored;

  /// Thrown by [read] when set — an unreadable keystore.
  Object? readError;

  final List<String> writes = [];
  int clears = 0;

  @override
  Future<String?> read() async {
    if (readError != null) throw readError!;
    return stored;
  }

  @override
  Future<void> write(String cartToken) async {
    stored = cartToken;
    writes.add(cartToken);
  }

  @override
  Future<void> clear() async {
    stored = null;
    clears++;
  }
}

/// A cart token shaped like the Store API's, expiring [inDays] from now.
///
/// Built rather than pasted so a fixture cannot quietly expire and start
/// failing the suite a year from now.
String cartToken({int inDays = 2, String id = 't_abc'}) {
  final exp = DateTime.now().add(Duration(days: inDays));
  return _jwt({
    'user_id': id,
    'exp': exp.millisecondsSinceEpoch ~/ 1000,
    'iss': 'store-api',
  });
}

String _jwt(Map<String, Object?> payload) {
  String segment(Map<String, Object?> json) {
    return base64Url
        .encode(utf8.encode(jsonEncode(json)))
        .replaceAll('=', '');
  }

  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  return '$header.${segment(payload)}.signature';
}
