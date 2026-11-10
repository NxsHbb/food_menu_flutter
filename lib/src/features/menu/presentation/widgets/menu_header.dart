import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// The design's red header: delivery address, greeting and a search entry.
///
/// The address and greeting are **not wired to data yet**. The address needs
/// branch selection (task 5.5) and the name needs an account (Phase 3), so
/// both take what they are given and the screen passes placeholders until
/// then. That keeps the invented copy in one visible place instead of
/// scattered through the tree.
class MenuHeader extends StatelessWidget {
  const MenuHeader({
    required this.addressLabel,
    required this.address,
    required this.greeting,
    required this.prompt,
    required this.onSearchTap,
    this.onAddressTap,
    super.key,
  });

  final String addressLabel;
  final String address;
  final String greeting;
  final String prompt;
  final VoidCallback onSearchTap;

  /// Opens the branch picker. Null leaves the line inert, which is what a
  /// store with a single location wants.
  final VoidCallback? onAddressTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final padding = MediaQuery.paddingOf(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.brand,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        top: padding.top + AppTokens.space16,
        left: AppTokens.space20,
        right: AppTokens.space20,
        bottom: AppTokens.space24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onAddressTap,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addressLabel,
                      style: text.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: AppTokens.space4),
                        Flexible(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (onAddressTap != null)
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: Colors.white,
                          ),
                      ],
                    ),
                  ],
                  ),
                ),
              ),
              const _HeaderIconButton(icon: Icons.notifications_none),
            ],
          ),
          const SizedBox(height: AppTokens.space20),
          Text(
            greeting,
            style: text.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppTokens.space2),
          Text(
            prompt,
            style: text.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppTokens.space16),
          _SearchEntry(onTap: onSearchTap),
        ],
      ),
    );
  }
}

/// A round translucent button, as the design draws the bell.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: null,
        icon: Icon(icon, size: 20, color: Colors.white),
        // Disabled until notifications exist; the design shows the affordance.
        disabledColor: Colors.white,
        tooltip: 'Notifications',
      ),
    );
  }
}

/// Looks like a search field but is a button, as in the design — tapping it
/// opens the search screen rather than focusing an inline input.
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(AppTokens.radiusButton),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space14,
            vertical: AppTokens.space14,
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: palette.ink),
              const SizedBox(width: AppTokens.space10),
              Expanded(
                child: Text(
                  'Search dishes, drinks…',
                  style: text.bodyLarge?.copyWith(color: palette.muted),
                ),
              ),
              Icon(Icons.tune, size: 18, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
