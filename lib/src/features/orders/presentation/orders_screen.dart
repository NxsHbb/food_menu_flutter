import 'package:flutter/material.dart';

import '../../menu/presentation/menu_screen.dart';

/// Orders screen. Filled in by Phase 7.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const routePath = '/orders';
  static const routeName = 'orders';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Orders',
      detail: 'Order history and live tracking arrive in Phase 7.',
      icon: Icons.receipt_long_outlined,
    );
  }
}
