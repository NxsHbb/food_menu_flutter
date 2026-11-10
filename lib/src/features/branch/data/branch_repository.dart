import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/branch.dart';
import '../domain/unserved_dish.dart';

/// The store's branches, as the plugin describes them.
class BranchRepository {
  const BranchRepository(this._client);

  final ApiClient _client;

  Future<BranchList> branches() async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/branches'),
    );
    return BranchList.fromJson(raw);
  }

  /// Which of [productIds] the branch will not serve.
  ///
  /// Asked about a branch the customer has **not** switched to yet, which is
  /// why the ids travel in the query rather than the request carrying
  /// `X-FMP-Branch` — that header says where they are now, not where they are
  /// going.
  Future<List<UnservedDish>> unserved({
    required int branchId,
    required Iterable<int> productIds,
  }) async {
    final ids = productIds.toSet();
    if (ids.isEmpty) return const [];

    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/branches/$branchId/unserved'),
      query: {'products': ids.join(',')},
    );

    final list = raw['unserved'];
    if (list is! List) return const [];

    return list
        .whereType<Map>()
        .map((e) => UnservedDish.fromJson(e.cast<String, dynamic>()))
        .where((dish) => dish.id > 0)
        .toList(growable: false);
  }
}

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository(ref.watch(apiClientProvider));
});
