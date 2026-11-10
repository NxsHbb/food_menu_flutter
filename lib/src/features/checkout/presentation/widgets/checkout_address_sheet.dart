import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../address/data/address_controller.dart';
import '../../../address/domain/saved_address.dart';
import '../../../address/presentation/address_form_screen.dart';
import '../../data/checkout_controller.dart';

/// The sheet behind the address block's "Change".
///
/// A sheet rather than a screen, like the branch picker: choosing which saved
/// address this order goes to is a detour, and the customer should land back
/// on the checkout with their input intact.
class CheckoutAddressSheet extends ConsumerWidget {
  const CheckoutAddressSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // The root navigator, as the branch picker does: the checkout sits
      // outside the tab shell, but a sheet from an inner navigator would come
      // up under the shell's floating cart bar if it were ever reached from
      // inside one.
      useRootNavigator: true,
      builder: (_) => const CheckoutAddressSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final book = ref.watch(addressControllerProvider).value ?? const [];
    final selected = ref.watch(checkoutAddressProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space12,
                AppTokens.space8,
                AppTokens.space8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Deliver to',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppTokens.space8),
                children: [
                  for (final address in book)
                    _AddressOption(
                      address: address,
                      selected: address.id != null &&
                          address.id == selected?.id,
                      onTap: () {
                        final id = address.id;
                        if (id != null) {
                          ref
                              .read(checkoutControllerProvider.notifier)
                              .chooseAddress(id);
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                  ListTile(
                    leading: Icon(Icons.add_rounded, color: palette.brand),
                    title: Text(
                      'Add a new address',
                      style: text.bodyLarge?.copyWith(color: palette.brand),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.pushNamed(AddressFormScreen.newRouteName);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final SavedAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        Icons.location_on_outlined,
        color: selected ? palette.brand : palette.muted,
      ),
      title: Text(address.title, style: text.titleSmall),
      subtitle: Text(
        [
          if (address.label.isNotEmpty) address.label,
          if (address.subtitle.isNotEmpty) address.subtitle,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: text.bodySmall?.copyWith(color: palette.muted),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: palette.brand)
          : null,
    );
  }
}
