import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/saved_address.dart';

/// One saved address, in the design's checkout-address vocabulary: a tinted
/// pin tile, a label line, the street in bold and the locality beneath.
///
/// The design has no address book, only this card on its checkout screen, so
/// the list is built from that rather than invented.
class AddressCard extends StatelessWidget {
  const AddressCard({
    required this.address,
    required this.onTap,
    required this.onMenu,
    super.key,
  });

  final SavedAddress address;
  final VoidCallback onTap;

  /// Opens the per-address actions — set default, delete.
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.tint,
                  borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 22,
                  color: palette.brand,
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (address.label.isNotEmpty)
                          Flexible(
                            child: Text(
                              address.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall
                                  ?.copyWith(color: palette.muted),
                            ),
                          ),
                        if (address.isDefault) ...[
                          if (address.label.isNotEmpty)
                            const SizedBox(width: AppTokens.space8),
                          const _DefaultBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Text(
                      address.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                    if (address.subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        address.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: palette.muted),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                color: palette.muted,
                tooltip: 'Address options',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Text(
        'Default',
        style: text.labelSmall?.copyWith(color: palette.brand),
      ),
    );
  }
}
