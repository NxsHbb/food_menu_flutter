import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// Cart screen. Filled in by Phase 4.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static const routePath = '/cart';
  static const routeName = 'cart';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Cart',
      detail: 'Your cart and add-on choices arrive in Phase 4.',
      icon: Icons.shopping_bag_outlined,
    );
  }
}
