import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../address/data/address_controller.dart';
import '../../address/presentation/address_book_screen.dart';
import '../../auth/presentation/login_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../wishlist/data/wishlist_controller.dart';
import '../../wishlist/presentation/wishlist_screen.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'widgets/account_header.dart';
import 'widgets/account_row.dart';

/// The design's account screen (screen 9).
///
/// **Three of the design's six rows are not here.** Payment methods shows
/// "Visa 4242", Notifications shows "On" and Help & support goes to a help
/// centre — none of which exist. Card payment is deferred to v2, and
/// notifications and help are not in the plan at all, so rendering them would
/// mean inventing values and a destination. The other three are here, with
/// the account-security pair from task 3.11 in a card of their own.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const routePath = '/account';
  static const routeName = 'account';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      body: auth.isLoading
          // Restoring the session from the keychain. Showing the signed-out
          // prompt here would flash "Sign in" at somebody who already is.
          ? const Center(child: CircularProgressIndicator())
          : auth.value == null
              ? _SignedOut(
                  onSignIn: () => context.pushNamed(LoginScreen.routeName),
                )
              : _SignedIn(user: auth.value!.user),
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistCount = ref.watch(wishlistCountProvider);
    final addressCount = ref.watch(addressCountProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppTokens.space24),
      children: [
        AccountHeader(
          user: user,
          onEdit: () => context.pushNamed(EditProfileScreen.routeName),
        ),
        // Pulled up over the header, as the design has it. A translate
        // rather than a negative margin, which Container forbids; it leaves
        // `overlap` of dead space at the end of the scroll, which the tab bar
        // covers anyway.
        Transform.translate(
          offset: const Offset(0, -AccountHeader.overlap),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space16,
            ),
            child: Column(
              children: [
                AccountRowCard(
                  rows: [
                    AccountRow(
                      mono: 'OR',
                      label: 'My orders',
                      // No count: the orders endpoint is task 7.1, and a
                      // zero here would read as "you have never ordered".
                      onTap: () =>
                          context.goNamed(OrdersScreen.routeName),
                    ),
                    AccountRow(
                      mono: 'WL',
                      label: 'Wishlist',
                      value: '$wishlistCount',
                      onTap: () =>
                          context.pushNamed(WishlistScreen.routeName),
                    ),
                    AccountRow(
                      mono: 'AD',
                      label: 'Saved addresses',
                      value: '$addressCount',
                      onTap: () =>
                          context.pushNamed(AddressBookScreen.routeName),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space16),
                // Its own card, because these two change credentials rather
                // than navigate to a list, and sitting them among the others
                // invites a mis-tap.
                AccountRowCard(
                  rows: [
                    AccountRow(
                      mono: 'PW',
                      label: 'Change password',
                      onTap: () =>
                          context.pushNamed(ChangePasswordScreen.routeName),
                    ),
                    AccountRow(
                      mono: 'EM',
                      label: 'Change email',
                      onTap: () =>
                          context.pushNamed(ChangeEmailScreen.routeName),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space16),
                const _LogOutButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LogOutButton extends ConsumerWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        child: const Text('Log out'),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Center(
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
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: palette.muted),
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
      ),
    );
  }
}
