import 'package:flutter/material.dart';

/// Menu landing screen. Filled in by Phase 2.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const routePath = '/';
  static const routeName = 'menu';

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderBody(
      title: 'Menu',
      detail: 'Categories and dishes arrive in Phase 2.',
      icon: Icons.restaurant_menu,
    );
  }
}

/// Shared placeholder so every tab renders something real before its phase
/// lands. Removed as each feature is implemented.
class _PlaceholderBody extends StatelessWidget {
  const _PlaceholderBody({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Exposed so the other feature placeholders can reuse it without each
/// declaring its own copy.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.title,
    required this.detail,
    required this.icon,
    super.key,
  });

  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      _PlaceholderBody(title: title, detail: detail, icon: icon);
}
