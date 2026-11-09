import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/screen_header.dart';
import '../../account/presentation/account_screen.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/address_controller.dart';
import '../domain/saved_address.dart';
import 'address_form_screen.dart';
import 'widgets/address_card.dart';

/// The customer's saved addresses.
///
/// **Not in the design**, which only ever shows one address on its checkout
/// screen and sends "Saved addresses" to a toast. The list is therefore drawn
/// from that card's own vocabulary — see [AddressCard].
class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  static const routePath = 'addresses';
  static const routeName = 'addresses';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final signedIn = ref.watch(isSignedInProvider);
    final book = ref.watch(addressControllerProvider);

    return Scaffold(
      backgroundColor: palette.page,
      body: Column(
        children: [
          ScreenHeader(
            title: 'Saved addresses',
            onBack: () => context.goNamed(AccountScreen.routeName),
          ),
          Expanded(
            child: !signedIn
                ? _SignedOut(
                    onSignIn: () => context.pushNamed(LoginScreen.routeName),
                  )
                : book.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _BookError(
                      error: error,
                      onRetry: () => ref
                          .read(addressControllerProvider.notifier)
                          .reload(),
                    ),
                    data: (addresses) => _Book(addresses: addresses),
                  ),
          ),
        ],
      ),
      floatingActionButton: signedIn && book.hasValue
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.pushNamed(AddressFormScreen.newRouteName),
              backgroundColor: palette.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add address'),
            )
          : null,
    );
  }
}

class _Book extends ConsumerWidget {
  const _Book({required this.addresses});

  final List<SavedAddress> addresses;

  Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    SavedAddress address,
  ) async {
    final id = address.id;
    if (id == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!address.isDefault)
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('Set as default'),
                subtitle: const Text(
                  'Used for your orders, and kept in step with your '
                  'account on the web.',
                ),
                onTap: () => Navigator.of(context).pop('default'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete address'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(addressControllerProvider.notifier);

    try {
      if (action == 'default') {
        await controller.setDefault(id);
      } else if (action == 'delete') {
        await controller.remove(id);
      }
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (addresses.isEmpty) return const _Empty();

    return RefreshIndicator(
      onRefresh: () => ref.read(addressControllerProvider.notifier).reload(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space16,
          AppTokens.space14,
          AppTokens.space16,
          // Clear of the tab bar and the Add button over it.
          140,
        ),
        itemCount: addresses.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space10),
        itemBuilder: (context, index) {
          final address = addresses[index];

          return AddressCard(
            address: address,
            onTap: () => context.pushNamed(
              AddressFormScreen.routeName,
              pathParameters: {'id': address.id ?? ''},
            ),
            onMenu: () => _openActions(context, ref, address),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

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
            Icon(
              Icons.location_on_outlined,
              size: 40,
              color: palette.muted,
            ),
            const SizedBox(height: AppTokens.space12),
            Text('No saved addresses', style: text.titleMedium),
            const SizedBox(height: AppTokens.space6),
            Text(
              'Add one and it will be ready at checkout.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.muted),
            ),
          ],
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
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, size: 48, color: palette.muted),
            const SizedBox(height: AppTokens.space12),
            Text('Your addresses', style: text.titleMedium),
            const SizedBox(height: AppTokens.space6),
            Text(
              'Sign in to save an address for checkout.',
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

class _BookError extends StatelessWidget {
  const _BookError({required this.error, required this.onRetry});

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
              api?.message ?? 'Could not load your addresses.',
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
