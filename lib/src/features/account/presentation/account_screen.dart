import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/capability/capability_probe.dart';
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
import 'delete_account_screen.dart';
import 'widgets/legal_card.dart';
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
              // Null where the store's plugin has no auth routes at all
              // (task 14.7): there is nothing to sign in to, and a button
              // that opens a form the server will refuse is the worst of the
              // answers available. The legal rows below stay either way.
              onSignIn: ref.watch(capabilitiesProvider).canSignIn
                  ? () => context.pushNamed(LoginScreen.routeName)
                  : null,
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
    // Task 14.7: a row is drawn only where the store's plugin has the route
    // behind it. Each of these screens is reachable from here and nowhere
    // else, so hiding the row is what closes the feature.
    final can = ref.watch(capabilitiesProvider);

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
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
            child: Column(
              children: [
                if (can.hasOrderHistory ||
                    can.hasWishlist ||
                    can.hasAddressBook) ...[
                  AccountRowCard(
                    rows: [
                      if (can.hasOrderHistory)
                        AccountRow(
                          mono: 'OR',
                          label: 'My orders',
                          // No count: the orders endpoint is task 7.1, and a
                          // zero here would read as "you have never ordered".
                          onTap: () => context.goNamed(OrdersScreen.routeName),
                        ),
                      if (can.hasWishlist)
                        AccountRow(
                          mono: 'WL',
                          label: 'Wishlist',
                          value: '$wishlistCount',
                          onTap: () =>
                              context.pushNamed(WishlistScreen.routeName),
                        ),
                      if (can.hasAddressBook)
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
                ],
                // Its own card, because these two change credentials rather
                // than navigate to a list, and sitting them among the others
                // invites a mis-tap.
                if (can.canChangePassword || can.canChangeEmail) ...[
                  AccountRowCard(
                    rows: [
                      if (can.canChangePassword)
                        AccountRow(
                          mono: 'PW',
                          label: 'Change password',
                          onTap: () =>
                              context.pushNamed(ChangePasswordScreen.routeName),
                        ),
                      if (can.canChangeEmail)
                        AccountRow(
                          mono: 'EM',
                          label: 'Change email',
                          onTap: () =>
                              context.pushNamed(ChangeEmailScreen.routeName),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space16),
                ],
                // The store's own pages, above the destructive pair: a
                // customer looking for the privacy policy should not have to
                // scroll past Delete account to find it (task 14.4).
                const LegalCard(),
                // Its own card, below the log-out button rather than above
                // it, because the two read as a pair and the harmless one
                // should be the one under the thumb.
                const _LogOutButton(),
                const SizedBox(height: AppTokens.space16),
                // **Hidden on a Pro too old to have the route** (task 14.7),
                // which is a store that cannot ship this app: both consoles
                // require in-app deletion of an account the app can create.
                // See `docs/STORE-SUBMISSION.md`.
                if (can.canDeleteAccount)
                  AccountRowCard(
                    rows: [
                      AccountRow(
                        mono: 'DEL',
                        label: 'Delete account',
                        danger: true,
                        onTap: () =>
                            context.pushNamed(DeleteAccountScreen.routeName),
                      ),
                    ],
                  ),
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

  /// Null on a store with no accounts. See the call site.
  final VoidCallback? onSignIn;

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
                onSignIn == null
                    ? 'This restaurant does not use accounts in the app.'
                    : 'Sign in to place an order, track it and keep your '
                          'favourites.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.muted,
                ),
              ),
              if (onSignIn != null) ...[
                const SizedBox(height: AppTokens.space20),
                SizedBox(
                  height: AppTokens.buttonHeight,
                  child: FilledButton(
                    onPressed: onSignIn,
                    child: const Text('Sign in'),
                  ),
                ),
              ],
              // **Here too, not only once signed in** (task 14.4). A store
              // reviewer opens the app and does not make an account, and the
              // privacy policy is one of the things they go looking for. It
              // is also the honest place for it: somebody deciding whether to
              // hand over their details should be able to read the policy
              // first.
              const SizedBox(height: AppTokens.space20),
              const LegalCard(),
            ],
          ),
        ),
      ),
    );
  }
}
