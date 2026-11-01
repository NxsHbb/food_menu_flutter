import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// Account screen. Filled in by Phase 3.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static const routePath = '/account';
  static const routeName = 'account';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Account',
      detail: 'Register and sign in arrive in Phase 3.',
      icon: Icons.person_outline,
    );
  }
}
