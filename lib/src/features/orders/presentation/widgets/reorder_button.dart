import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../cart/presentation/cart_screen.dart';
import '../../data/reorder_controller.dart';

/// The design's "Reorder" — on a past history row, and in the order footer.
///
/// Does the whole thing itself rather than handing a callback up: a row and a
/// footer want identical behaviour, and the only difference between them is
/// how the button is painted. [filled] picks which.
///
/// **It does not ask first.** Reorder adds to the cart, it does not place an
/// order or charge anything, and the cart is the confirmation step — which is
/// where this lands the customer. A dialog in front of it would be one tap
/// between a customer and the thing they already decided to do.
class ReorderButton extends ConsumerStatefulWidget {
  const ReorderButton({
    required this.orderId,
    this.filled = false,
    super.key,
  });

  final int orderId;

  /// The footer's primary action. A row's is an outline, as the design draws
  /// it beside "Details".
  final bool filled;

  @override
  ConsumerState<ReorderButton> createState() => _ReorderButtonState();
}

class _ReorderButtonState extends ConsumerState<ReorderButton> {
  bool _busy = false;

  Future<void> _reorder() async {
    setState(() => _busy = true);

    try {
      final outcome =
          await ref.read(reorderControllerProvider).run(widget.orderId);

      if (!mounted) return;

      _say(outcome.message);

      // Only where something actually landed. Sending a customer to an
      // unchanged cart to find out nothing worked is worse than the message.
      if (!outcome.isEmpty) {
        context.goNamed(CartScreen.routeName);
      }
    } on ApiException catch (error) {
      // The **read** failed, so nothing has changed and the cart is as it was.
      if (mounted) _say(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final child = _busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Reorder');

    final onPressed = _busy ? null : _reorder;

    return widget.filled
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}
