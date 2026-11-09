import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/domain/auth_user.dart';

/// The design's red account header: avatar, name, email and an Edit button.
///
/// Its bottom corners are rounded and the row card below overlaps it, so this
/// deliberately carries extra bottom padding for the card to sit on.
class AccountHeader extends StatelessWidget {
  const AccountHeader({
    required this.user,
    required this.onEdit,
    super.key,
  });

  final AuthUser user;
  final VoidCallback onEdit;

  /// How far the row card below is pulled up over this header.
  static const overlap = 40.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.brand,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space20,
            AppTokens.space20,
            AppTokens.space20,
            // The design's 64px, which the row card then overlaps by 40.
            AppTokens.space24 + overlap,
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  user.initials,
                  style: text.titleLarge?.copyWith(color: palette.brand),
                ),
              ),
              const SizedBox(width: AppTokens.space14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.greetingName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              _EditButton(onTap: onEdit),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusControl),
    );

    return Material(
      // A white wash over the brand red, as the design has it, rather than a
      // second opaque colour that would need its own token.
      color: Colors.white.withValues(alpha: 0.18),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space14,
            vertical: AppTokens.space8,
          ),
          child: Text(
            'Edit',
            style: text.labelMedium?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
