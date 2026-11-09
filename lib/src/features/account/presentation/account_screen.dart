import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../../wishlist/data/wishlist_controller.dart';
import '../../wishlist/presentation/wishlist_screen.dart';

/// Account tab.
///
/// Intentionally minimal: this exists so the auth flow from task 3.3 is
/// reachable and its result visible. The design's full account screen — the
/// row list, Edit profile, Saved addresses — is task 3.7.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const routePath = '/account';
  static const routeName = 'account';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final session = auth.value;
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space16),
          child: auth.isLoading
              // Restoring the session from the keychain. Showing the signed-out
              // prompt here would flash "Sign in" at somebody who already is.
              ? const Center(child: CircularProgressIndicator())
              : session == null
              ? _SignedOut(
                  onSignIn: () => context.pushNamed(LoginScreen.routeName),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: palette.tint,
                          child: Text(
                            session.user.initials,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: palette.brand),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.user.greetingName,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                session.user.email,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space20),
                    // One row, not the design's full list: that list is task
                    // 3.7. This is here so the wishlist screen from task 3.6
                    // is reachable, and it is built to drop straight into the
                    // list when 3.7 assembles it.
                    _AccountRow(
                      mono: 'WL',
                      label: 'Wishlist',
                      value: '${ref.watch(wishlistCountProvider)}',
                      onTap: () =>
                          context.pushNamed(WishlistScreen.routeName),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: AppTokens.buttonHeight,
                      child: OutlinedButton(
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).logout(),
                        child: const Text('Log out'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One row of the design's account list: a lettered tile, a label, a value and
/// a chevron.
///
/// Built here rather than in a shared widget because task 3.7 owns the full
/// list and will decide where this lives.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.mono,
    required this.label,
    required this.value,
    required this.onTap,
  });

  /// The design's two-letter tile, e.g. `WL` for Wishlist.
  final String mono;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
            vertical: AppTokens.space14,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.tint,
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusControl),
                ),
                child: Text(
                  mono,
                  style: text.labelMedium?.copyWith(color: palette.brand),
                ),
              ),
              const SizedBox(width: AppTokens.space14),
              Expanded(child: Text(label, style: text.bodyLarge)),
              Text(
                value,
                style: text.bodySmall?.copyWith(color: palette.muted),
              ),
              const SizedBox(width: AppTokens.space6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: palette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 48, color: palette.muted),
          const SizedBox(height: AppTokens.space12),
          Text('Your account', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTokens.space6),
          Text(
            'Sign in to place an order, track it and keep your favourites.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppTokens.space20),
          SizedBox(
            height: AppTokens.buttonHeight,
            child: FilledButton(
              onPressed: onSignIn,
              child: const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}
