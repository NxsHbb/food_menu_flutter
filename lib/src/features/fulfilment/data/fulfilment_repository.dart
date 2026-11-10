import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/order_types.dart';
import '../domain/slots.dart';

/// Pickup and delivery, as the plugin describes them.
///
/// Two reads, both public — opening hours are the store's, not the
/// customer's, and the design puts this choice in front of sign-in.
///
/// Neither route exists in the Store API: the website builds its time list in
/// the browser and checks one slot at a time over AJAX, which a mobile client
/// cannot reuse. See `FINDINGS.md`.
class FulfilmentRepository {
  const FulfilmentRepository(this._client);

  final ApiClient _client;

  /// Which types the store offers, and its weekly hours for each.
  Future<OrderTypes> orderTypes({int branch = 0}) async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/order-types'),
      query: {if (branch > 0) 'branch': branch},
    );
    return OrderTypes.fromJson(raw);
  }

  /// The choosable times on one date.
  ///
  /// [date] is `Y-m-d`; omitting it asks for the earliest date this type can
  /// be fulfilled on, which is what a screen with no date picker wants.
  ///
  /// [items] is the cart already encoded by [encodeItems] — `42:2,17:1`.
  /// Without it the answer covers only the store-wide slot caps: per-dish
  /// limits and dishes that are not served at a given hour both need to know
  /// what is being ordered. The route cannot read the cart itself, being
  /// public, and the cart lives behind a Store API `Cart-Token` that only
  /// Store API routes resolve.
  ///
  /// Taken **as the encoded string** rather than as a map, because this value
  /// is also what decides whether a fresh request is needed, and two equal
  /// maps are never `==` to each other while two equal strings always are.
  Future<SlotList> slots({
    required OrderTypeKind type,
    String? date,
    int branch = 0,
    String items = '',
  }) async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/slots'),
      query: {
        'type': type.name,
        if (date != null && date.isNotEmpty) 'date': date,
        if (branch > 0) 'branch': branch,
        if (items.isNotEmpty) 'items': items,
      },
    );
    return SlotList.fromJson(raw);
  }

  /// `42:2,17:1`, the shape the route parses.
  ///
  /// Sorted so the same cart always produces the same string, which keeps it
  /// usable as a provider key and stops an identical request looking new.
  static String encodeItems(Map<int, int> items) {
    final ids = items.keys.toList()..sort();
    return ids
        .where((id) => id > 0 && (items[id] ?? 0) > 0)
        .map((id) => '$id:${items[id]}')
        .join(',');
  }
}

final fulfilmentRepositoryProvider = Provider<FulfilmentRepository>((ref) {
  return FulfilmentRepository(ref.watch(apiClientProvider));
});
