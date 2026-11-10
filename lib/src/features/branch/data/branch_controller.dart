import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/branch.dart';
import 'branch_repository.dart';
import 'branch_store.dart';

/// The branch the customer is ordering from, remembered between launches.
///
/// An `AsyncNotifier` because the first value comes from storage, and the
/// network interceptor **awaits** it: a Store API request that goes out before
/// the branch is restored is answered with every branch's dishes, and the menu
/// would then visibly swap under the customer.
class SelectedBranchController extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    try {
      return await ref.read(branchStoreProvider).read();
    } on Object {
      // A store that cannot be read means **no branch chosen**, not a broken
      // app. This must never become an error state: the network interceptor
      // awaits this value before every request, so an error here would stall
      // the first menu load behind a keystore problem.
      return null;
    }
  }

  /// Chooses a branch and remembers it.
  ///
  /// Everything scoped by the branch — the menu, the order types, the slots —
  /// watches [activeBranchIdProvider], so there is nothing to invalidate by
  /// hand here. The **cart is deliberately left alone**: the website removes
  /// lines the new branch does not serve, and the app cannot, so a customer
  /// can carry a dish across. See `FINDINGS.md`.
  Future<void> choose(int branchId) async {
    if (state.value == branchId) return;

    state = AsyncData(branchId);
    await ref.read(branchStoreProvider).write(branchId);
  }
}

final selectedBranchProvider =
    AsyncNotifierProvider<SelectedBranchController, int?>(
  SelectedBranchController.new,
  // No retry. Riverpod retries a failed build with a growing backoff, and
  // because the interceptor awaits this, a retry loop would hold every
  // request behind it rather than letting the app run with no branch.
  retry: (retryCount, error) => null,
);

/// The chosen branch id as a plain value, for everything that only needs to
/// know **when it changed**. Null while the restore is still in flight.
final activeBranchIdProvider = Provider<int?>((ref) {
  return ref.watch(selectedBranchProvider).value;
});

/// The branches this store offers.
final branchesProvider = FutureProvider<BranchList>(
  (ref) => ref.watch(branchRepositoryProvider).branches(),
  // The picker offers "Try again"; a background retry would keep firing while
  // the customer reads the error.
  retry: (retryCount, error) => null,
);

/// The branch in force: the remembered one if the store still has it, and the
/// first otherwise.
///
/// Resolved on every read rather than stored, so a branch that is deleted, or
/// a store that switches multi-location off, does not leave the app pointed at
/// something that no longer exists.
final activeBranchProvider = Provider<Branch?>((ref) {
  final branches = ref.watch(branchesProvider).value;
  if (branches == null) return null;

  return branches.resolve(ref.watch(activeBranchIdProvider));
});
