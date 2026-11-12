import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../address/data/address_controller.dart';
import '../../../address/presentation/address_form_screen.dart';
import '../../../branch/data/branch_controller.dart';
import '../../../branch/presentation/widgets/branch_picker_sheet.dart';
import '../../../fulfilment/data/fulfilment_controller.dart';
import '../../../fulfilment/domain/order_types.dart';
import '../../data/checkout_controller.dart';
import 'checkout_address_sheet.dart';
import 'checkout_card.dart';
import '../../data/checkout_repository.dart';

/// Where the order goes, or where it is collected from.
///
/// **One block, two sources.** A delivery order needs the customer's own
/// address, which is the address book; a pickup order needs the branch's,
/// which is the branch list. The design draws the same pin-and-Change row for
/// both, so this switches on the order type in force rather than on anything
/// it stores.
class CheckoutAddressSection extends ConsumerWidget {
  const CheckoutAddressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(resolvedOrderTypeProvider);

    // Nothing is known about the order yet, or the store takes no orders at
    // all — the fulfilment section above says so, so this stays out of the
    // way rather than guessing which address to ask for.
    if (kind == null) return const SizedBox.shrink();

    return switch (kind) {
      // **Only the pickup card answers to the store** (task 10.2). The
      // website's "Your location" toggle hides the branch card, and the
      // server already folds in that a single-branch store has nothing to
      // say. The delivery card is *not* governed by
      // `show_shipping_address`: on the website that hides a separate
      // shipping card while the billing fields still collect an address,
      // and this card is the app's only address surface — hiding it would
      // leave a delivery order with nowhere to send the food.
      OrderTypeKind.pickup =>
        ref.watch(checkoutSectionsProvider).yourLocation
            ? const _PickupBranch()
            : const SizedBox.shrink(),
      OrderTypeKind.delivery => const _DeliveryAddress(),
    };
  }
}

/// The customer's saved address for a delivery order.
class _DeliveryAddress extends ConsumerWidget {
  const _DeliveryAddress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(addressControllerProvider);
    final address = ref.watch(checkoutAddressProvider);

    if (book case AsyncError(:final error)) {
      return _AddressCard(
        title: 'Deliver to',
        line: 'Could not load your addresses.',
        subtitle: error is ApiException ? error.message : null,
        actionLabel: 'Try again',
        onAction: () =>
            ref.read(addressControllerProvider.notifier).reload(),
      );
    }

    if (address == null) {
      // Signed in with an empty book, or still loading it. Either way the
      // only useful offer is to add one.
      return _AddressCard(
        title: 'Deliver to',
        line: book.isLoading ? 'Loading your addresses…' : 'No address yet',
        subtitle: book.isLoading
            ? null
            : 'Add where this order should be delivered.',
        actionLabel: book.isLoading ? null : 'Add',
        onAction: () => context.pushNamed(AddressFormScreen.newRouteName),
      );
    }

    return _AddressCard(
      title: 'Deliver to',
      line: address.title,
      subtitle: address.subtitle.isEmpty ? null : address.subtitle,
      badge: address.label.isEmpty ? null : address.label,
      actionLabel: 'Change',
      onAction: () => CheckoutAddressSheet.show(context),
    );
  }
}

/// The branch a pickup order is collected from.
class _PickupBranch extends ConsumerWidget {
  const _PickupBranch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);
    final branch = ref.watch(activeBranchProvider);

    if (branch == null) {
      return _AddressCard(
        title: 'Pick up from',
        line: branches.hasError
            ? 'Could not load the branches.'
            : 'Loading branches…',
        actionLabel: branches.hasError ? 'Try again' : null,
        onAction: () => ref.invalidate(branchesProvider),
      );
    }

    // A store that runs no branches has exactly one place to collect from, so
    // offering "Change" would open a picker with a single row in it.
    final choosable = branches.value?.multiLocation == true;

    return _AddressCard(
      title: 'Pick up from',
      line: branch.name,
      // The admin types the address as free text with its own line breaks,
      // which would make this row three lines tall.
      subtitle: branch.address.isEmpty
          ? null
          : branch.address.split(RegExp(r'\r?\n')).join(', '),
      actionLabel: choosable ? 'Change' : null,
      onAction: () => BranchPickerSheet.show(context),
    );
  }
}

/// The design's address row: a tinted pin, three lines, and one action.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.title,
    required this.line,
    this.subtitle,
    this.badge,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String line;
  final String? subtitle;

  /// The customer's own name for the address — "Home", "Work".
  final String? badge;

  /// Null leaves the row without an action, for the cases where there is
  /// nothing to change.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return CheckoutCard(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space14,
        AppTokens.space14,
        AppTokens.space8,
        AppTokens.space14,
      ),
      child: Row(
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
                Text(
                  badge == null ? title : '$title · $badge',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
                const SizedBox(height: AppTokens.space2),
                Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                if (subtitle case final subtitle?) ...[
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel case final label?)
            TextButton(onPressed: onAction, child: Text(label)),
        ],
      ),
    );
  }
}
