import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/data/cart_controller.dart';
import 'orders_repository.dart';

/// Puts a past order back in the cart.
///
/// **Two steps, and the second is the Store API's.** The plugin route answers
/// what the lines would be; each one then goes through the same
/// `cart/add-item` a dish screen uses, so add-on validation, branch scoping,
/// timed products and stock all apply exactly as they would on a first order.
/// Nothing is added server-side by the reorder route itself.
///
/// **Adds to the cart, never replaces it.** A customer who reorders while
/// mid-shop keeps what they had, which is what the design's prototype does.
class ReorderController {
  const ReorderController(this._ref);

  final Ref _ref;

  /// Reads the order and adds everything that can go back.
  ///
  /// Throws only if the **read** fails — at that point nothing has changed and
  /// the screen can simply say so. A line that fails to add is reported in the
  /// outcome instead, because by then some of the order may already be in the
  /// cart and pretending otherwise would be a lie.
  Future<ReorderOutcome> run(int orderId) async {
    final reorder = await _ref.read(ordersRepositoryProvider).reorder(orderId);
    final cart = _ref.read(cartControllerProvider.notifier);

    final skipped = <String>[
      for (final line in reorder.unavailable) '${line.name} — ${line.reason.message}',
    ];
    var added = 0;

    for (final line in reorder.available) {
      try {
        await cart.add(
          productId: line.productId,
          quantity: line.quantity,
          addons: line.addons,
        );
        added++;
      } on Object {
        // The server refused it just now — sold out since the read, or a
        // group that has become required. Named, not swallowed: the customer
        // is about to see a cart that is not their old order.
        skipped.add('${line.name} — could not be added');
      }
    }

    return ReorderOutcome(added: added, skipped: skipped);
  }
}

/// What a reorder actually managed.
class ReorderOutcome {
  const ReorderOutcome({required this.added, required this.skipped});

  /// How many lines went into the cart.
  final int added;

  /// One line of plain English per line that did not, dish first.
  final List<String> skipped;

  bool get isEmpty => added == 0;
  bool get isPartial => added > 0 && skipped.isNotEmpty;

  /// The design shows a toast. This is what it says.
  String get message {
    if (isEmpty) return 'Nothing from this order could be added.';
    if (isPartial) {
      return added == 1
          ? '1 item added. ${skipped.length} could not be.'
          : '$added items added. ${skipped.length} could not be.';
    }
    return added == 1 ? 'Item added to cart' : 'Items added to cart';
  }
}

final reorderControllerProvider = Provider<ReorderController>(
  ReorderController.new,
);
