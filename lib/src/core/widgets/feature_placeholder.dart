import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

/// Stand-in for a destination whose phase has not landed yet.
///
/// Each tab renders something honest before its feature exists, instead of a
/// blank screen that looks broken. Removed as each phase lands.
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
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: palette.brand),
              const SizedBox(height: AppTokens.space16),
              Text(title, style: text.titleLarge),
              const SizedBox(height: AppTokens.space8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
