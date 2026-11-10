import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../cart/data/cart_controller.dart';
import '../domain/unserved_dish.dart';
import 'branch_controller.dart';
import 'branch_repository.dart';

/// Switching branches, and what it costs the cart.
///
/// Branches do not all serve the same menu, so a cart filled at one can hold
/// a dish another will not make. The website drops those lines on the next
/// page load and says so afterwards; the app **asks first**, because a cart
/// that quietly loses a dish between two taps is the kind of thing a customer
/// notices at checkout and not before.
///
/// The server still refuses such an order — see the plugin's cart guard — so
/// this is about telling the customer in time, not about correctness.
class BranchSwitcher {
  const BranchSwitcher(this._ref);

  final Ref _ref;

  /// What switching to [branchId] would take out of the cart, if anything.
  ///
  /// **The cart is awaited, not sampled.** Reading whatever value it happens
  /// to hold would answer "nothing to lose" for a cart that has simply not
  /// loaded yet — and the one moment that is likeliest is a cold start, where
  /// the customer opens the branch picker before anything has touched the
  /// cart. The whole point of this question is not to answer it wrongly.
  ///
  /// **An empty list on failure, not an exception.** A branch switch is not
  /// worth blocking on a question the server could not answer: the customer
  /// gets the branch they asked for, the cart response flags the line, and
  /// checkout refuses it. Failing closed here would instead leave them unable
  /// to change branch at all whenever this one route is unhappy.
  Future<List<UnservedDish>> check(int branchId) async {
    try {
      final cart = await _ref.read(cartControllerProvider.future);
      if (cart.isEmpty) return const [];

      return await _ref.read(branchRepositoryProvider).unserved(
            branchId: branchId,
            productIds: cart.items.map((item) => item.id),
          );
    } on ApiException {
      return const [];
    }
  }

  /// Switches to [branchId], dropping [dropping] from the cart first.
  ///
  /// In that order deliberately: the removals go out while the old branch is
  /// still in force, so nothing is asked of the server in a state where the
  /// cart it holds is one it would refuse.
  ///
  /// A failed removal still switches. The alternative — refusing to change
  /// branch because a line would not delete — strands the customer on a
  /// branch they are trying to leave, and the line is flagged on the cart
  /// screen either way.
  Future<void> commit({
    required int branchId,
    List<UnservedDish> dropping = const [],
  }) async {
    if (dropping.isNotEmpty) {
      try {
        await _ref.read(cartControllerProvider.notifier).removeProducts(
              dropping.map((dish) => dish.id).toSet(),
            );
      } on ApiException {
        // Deliberately swallowed; see above.
      }
    }

    await _ref.read(selectedBranchProvider.notifier).choose(branchId);
  }
}

final branchSwitcherProvider = Provider<BranchSwitcher>(BranchSwitcher.new);
