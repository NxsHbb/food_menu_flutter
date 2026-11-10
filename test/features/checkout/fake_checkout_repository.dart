export 'package:food_menu/src/features/checkout/domain/order_draft.dart';
export 'package:food_menu/src/features/checkout/domain/placed_order.dart';

import 'package:food_menu/src/features/checkout/data/checkout_repository.dart';
import 'package:food_menu/src/features/checkout/domain/order_draft.dart';
import 'package:food_menu/src/features/checkout/domain/placed_order.dart';

/// A [CheckoutRepository] that answers from memory.
///
/// It keeps the drafts it was given, because most of what task 6.2 does is
/// decide **what** to submit — the extension block, the split name, the
/// server's own date and time strings — and that is only observable here.
class FakeCheckoutRepository implements CheckoutRepository {
  FakeCheckoutRepository({this.order, this.delay = Duration.zero});

  /// What the next order comes back as. Null answers with a plain placed
  /// order carrying number 1042.
  PlacedOrder? order;

  final Duration delay;

  /// Thrown by the next call, then cleared.
  Object? failNext;

  /// Every draft submitted, in order.
  final List<OrderDraft> drafts = [];

  /// The last submitted body, as it would go over the wire.
  Map<String, dynamic> get lastBody => drafts.last.toJson();

  /// The plugin's extension block from the last submission.
  Map<String, dynamic> get lastExtension =>
      (lastBody['extensions'] as Map)['food-menu-pro'] as Map<String, dynamic>;

  @override
  Future<PlacedOrder> placeOrder(OrderDraft draft) async {
    drafts.add(draft);
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }

    return order ?? placedOrder();
  }
}

PlacedOrder placedOrder({
  int id = 1042,
  String number = '1042',
  String status = 'processing',
  int customerId = 8,
  String paymentStatus = 'success',
}) {
  return PlacedOrder.fromJson({
    'order_id': id,
    'order_number': number,
    'order_key': 'wc_order_test$id',
    'status': status,
    'customer_id': customerId,
    'payment_result': {'payment_status': paymentStatus, 'redirect_url': ''},
  });
}
