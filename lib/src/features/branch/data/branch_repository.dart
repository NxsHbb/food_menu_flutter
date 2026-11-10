import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/branch.dart';

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
}

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository(ref.watch(apiClientProvider));
});
