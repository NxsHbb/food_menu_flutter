import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/store_api/models/product.dart';
import 'cart_controller.dart';

/// What came of tapping a dish's quick-add `+`.
sealed class QuickAddOutcome {
  const QuickAddOutcome();
}

/// The dish is in the cart.
class QuickAddSucceeded extends QuickAddOutcome {
  const QuickAddSucceeded(this.product);

  final Product product;
}

/// The server will not take this dish without choices being made first.
///
/// Reached only on a store whose plugin does not publish `requires_choices`,
/// since the button routes a dish that declares itself to the dish screen
/// without asking. Kept because the alternative is a `+` that answers
/// "Please choose an option" on a screen with nothing to choose from.
class QuickAddNeedsChoices extends QuickAddOutcome {
  const QuickAddNeedsChoices(this.product);

  final Product product;
}

/// The add was refused for some other reason — sold out, a stock limit, a
/// dropped connection. [message] is the server's own words where it sent any.
class QuickAddFailed extends QuickAddOutcome {
  const QuickAddFailed(this.message);

  final String message;
}

/// The product ids with a quick add in flight.
///
/// State rather than a flag inside each button, so the `+` for one dish stays
/// busy across a rebuild — a menu list rebuilds on every cart change, which is
/// precisely while an add is running.
class QuickAddController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  bool isAdding(int productId) => state.contains(productId);

  /// Adds one of [product] to the cart.
  ///
  /// Returns null when a tap is ignored, which is how a double tap is stopped
  /// from putting two in the cart. The cart itself is updated by
  /// [CartController], so nothing here has to report what the totals became.
  Future<QuickAddOutcome?> add(Product product) async {
    if (state.contains(product.id)) return null;
    state = {...state, product.id};

    try {
      await ref.read(cartControllerProvider.notifier).add(
            productId: product.id,
          );
      return QuickAddSucceeded(product);
    } on ApiException catch (error) {
      return _classify(product, error);
    } finally {
      state = {...state}..remove(product.id);
    }
  }

  QuickAddOutcome _classify(Product product, ApiException error) {
    // The plugin's add-on validation, which names the group it wants. Every
    // code it throws starts this way, so the group's own rule — required,
    // a minimum, a character limit — does not have to be mirrored here.
    final code = error.code;
    if (code != null && code.startsWith('fmp_app_addon_')) {
      return QuickAddNeedsChoices(product);
    }

    return QuickAddFailed(error.message);
  }
}

final quickAddControllerProvider =
    NotifierProvider<QuickAddController, Set<int>>(QuickAddController.new);

/// True while this dish's `+` has a request in flight.
final quickAddPendingProvider = Provider.family<bool, int>((ref, productId) {
  return ref.watch(quickAddControllerProvider).contains(productId);
});
