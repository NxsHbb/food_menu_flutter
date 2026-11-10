import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../menu/presentation/product_detail_screen.dart';
import '../../data/quick_add_controller.dart';

/// The design's brand-coloured `+` on a dish card or menu row.
///
/// One widget for both, and the only place that decides what a `+` does, so
/// the rule cannot differ between the landing screen and the menu list:
///
/// - a dish that needs choices opens the dish screen, where they can be made;
/// - anything else goes straight into the cart;
/// - a sold-out dish still opens the dish screen, which says so. Disabling the
///   button instead would leave the card looking broken rather than sold out.
///
/// It is never hidden. The design draws a `+` on every card, and a card
/// missing one reads as a dish that cannot be ordered at all.
class QuickAddButton extends ConsumerWidget {
  const QuickAddButton({
    required this.product,
    required this.size,
    required this.borderRadius,
    this.iconSize = 18,
    super.key,
  });

  final Product product;

  /// The tap target, square. The card and the row draw it at different sizes.
  final double size;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final adding = ref.watch(quickAddPendingProvider(product.id));
    final radius = BorderRadius.circular(borderRadius);

    return Material(
      color: palette.brand,
      borderRadius: radius,
      child: InkWell(
        // Dropped rather than disabled while the add is in flight: a disabled
        // InkWell loses the splash, so the button would appear to go dead at
        // the moment it most needs to look busy.
        onTap: adding ? null : () => _onTap(context, ref),
        borderRadius: radius,
        child: SizedBox(
          width: size,
          height: size,
          child: adding
              ? Center(
                  child: SizedBox.square(
                    dimension: iconSize,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      // White on brand, as the `+` it replaces: `contrast` is
                      // a dark ink and would all but vanish here.
                      color: Colors.white,
                    ),
                  ),
                )
              : Icon(Icons.add, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (!product.canAddDirectly) {
      _openDish(context);
      return;
    }

    final outcome =
        await ref.read(quickAddControllerProvider.notifier).add(product);

    if (!context.mounted || outcome == null) return;

    switch (outcome) {
      // Deliberately silent. The floating cart bar is the design's own
      // confirmation and it appears on the same frame — and a snackbar would
      // land **on top of it**, since both are pinned to the bottom of the
      // shell's `Scaffold`. Two seconds of hiding the thing that says
      // "1 · View cart · $3.95" is worse feedback than none.
      case QuickAddSucceeded():
        break;
      case QuickAddNeedsChoices():
        _say(context, 'This dish needs a few choices first.');
        _openDish(context);
      case QuickAddFailed(:final message):
        _say(context, message);
    }
  }

  void _openDish(BuildContext context) {
    context.pushNamed(
      ProductDetailScreen.routeName,
      pathParameters: {'id': '${product.id}'},
    );
  }

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
