import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/store_api/models/product.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/screen_header.dart';
import '../../account/presentation/account_screen.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../../menu/presentation/product_detail_screen.dart';
import '../data/wishlist_controller.dart';
import 'widgets/wishlist_row.dart';

/// The design's wishlist screen (screen 10).
///
/// Nested under the Account tab rather than given its own, because the design
/// shows the tab bar here with Account still highlighted, and reaches this
/// screen from the Account row list.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  static const routePath = 'wishlist';
  static const routeName = 'wishlist';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final signedIn = ref.watch(isSignedInProvider);
    final wishlist = ref.watch(wishlistControllerProvider);

    return Scaffold(
      backgroundColor: palette.page,
      body: Column(
        children: [
          ScreenHeader(
            title: 'Wishlist',
            // A deep link can land here with nothing to pop.
            onBack: () => context.goNamed(AccountScreen.routeName),
          ),
          Expanded(
            child: !signedIn
                ? _SignedOut(
                    onSignIn: () => context.pushNamed(LoginScreen.routeName),
                  )
                : wishlist.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _WishlistError(
                      error: error,
                      onRetry: () => ref
                          .read(wishlistControllerProvider.notifier)
                          .reload(),
                    ),
                    data: (products) => products.isEmpty
                        ? const _Empty()
                        : _List(products: products),
                  ),
          ),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(wishlistControllerProvider.notifier).reload(),
      child: ListView.separated(
        // The design's own padding, with room at the bottom for the tab bar
        // and the floating cart bar that Phase 4 adds.
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space16,
          AppTokens.space14,
          AppTokens.space16,
          120,
        ),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space10),
        itemBuilder: (context, index) {
          final product = products[index];

          return WishlistRow(
            product: product,
            onTap: () => context.pushNamed(
              ProductDetailScreen.routeName,
              pathParameters: {'id': '${product.id}'},
            ),
          );
        },
      ),
    );
  }
}

/// The design's empty state, word for word.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space20,
          vertical: 60,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 40,
              color: palette.muted,
            ),
            const SizedBox(height: AppTokens.space12),
            Text(
              'Tap the heart on any dish to save it here.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Not in the design, which assumes a signed-in customer throughout.
///
/// Reachable all the same: the wishlist is server-backed, so a signed-out
/// customer has no list to show, and the Account screen can be opened by
/// anyone.
class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 48, color: palette.muted),
            const SizedBox(height: AppTokens.space12),
            Text('Your favourites', style: text.titleMedium),
            const SizedBox(height: AppTokens.space6),
            Text(
              'Sign in to save dishes and find them on any device.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.muted),
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
      ),
    );
  }
}

class _WishlistError extends StatelessWidget {
  const _WishlistError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final api = error is ApiException ? error as ApiException : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: palette.muted),
            const SizedBox(height: AppTokens.space12),
            Text(
              api?.message ?? 'Could not load your wishlist.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppTokens.space16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
