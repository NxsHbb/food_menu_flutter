import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../menu/presentation/menu_screen.dart';
import '../../fulfilment/data/fulfilment_controller.dart';
import '../../fulfilment/presentation/widgets/fulfilment_section.dart';
import '../data/checkout_controller.dart';
import '../data/checkout_repository.dart';
import '../domain/order_draft.dart';
import '../domain/placed_order.dart';
import 'widgets/checkout_address_section.dart';
import 'widgets/checkout_card.dart';
import 'widgets/checkout_total_bar.dart';
import 'widgets/contact_details_section.dart';
import 'widgets/order_summary_section.dart';

/// The design's checkout: how and when the order arrives, where it goes, who
/// it is for, and what it comes to.
///
/// Outside the tab shell, with its own back button, because the design shows
/// no tab bar here.
///
/// Built in two passes. Task 5.4 added [FulfilmentSection] — the order type
/// and the time. Task 6.1 added the rest of the screen: the address block,
/// contact details, the order summary and the total bar. **Payment is task
/// 6.3 and placing the order is task 6.2**, and the card between contact
/// details and the summary says so, where the design draws the payment list.
///
/// Nothing on this screen is computed from parts. The times come from
/// `/app/slots`, the address from the address book, the money from the cart's
/// own totals — so the screen cannot show a number the order will contradict.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  static const routePath = '/checkout';
  static const routeName = 'checkout';

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Off until the first attempt, so a checkout that opens with an empty name
  /// does not greet the customer in red.
  bool _autovalidate = false;

  /// True while the order is in flight, so the button cannot be pressed
  /// twice. **Not a provider**: a second order is a second charge, and this
  /// has to be impossible, not merely unlikely.
  bool _placing = false;

  Future<void> _placeOrder() async {
    if (_placing) return;

    // The form first. Everything it checks is on screen, so a message beside
    // the field beats the same complaint in a snackbar — and when the form is
    // not on screen at all, signed out or with an empty cart, it passes and
    // the readiness below says the useful thing instead.
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = true);
      return;
    }

    // Read, never watched: this is what is true at the moment of the tap.
    switch (ref.read(checkoutReadinessProvider)) {
      case CheckoutBlocked(:final reason):
        _say(reason);
      case CheckoutReady(:final draft):
        await _submit(draft);
    }
  }

  /// Sends it, and leaves the screen exactly as it was if the server says no.
  Future<void> _submit(OrderDraft draft) async {
    setState(() => _placing = true);
    PlacedOrder? order;

    try {
      order = await ref.read(checkoutRepositoryProvider).placeOrder(draft);

      // A successful checkout empties the cart server-side, so it has to be
      // re-read rather than assumed — the mini cart and the tab badge both
      // watch it.
      if (order.exists) {
        await ref.read(cartControllerProvider.notifier).reload();
      }
    } on ApiException catch (error) {
      // The Store API's own sentence, which names what it rejected — "Street
      // address is required" — and is more use than anything composed here.
      // Task 6.5 gives the failure paths their own treatment.
      if (mounted) _say(error.message);
    } finally {
      // **Before the dialog, not after it.** The button's spinner is an
      // animation, and leaving it running behind a modal is a frame loop that
      // never settles.
      if (mounted) setState(() => _placing = false);
    }

    if (!mounted || order == null) return;

    // A 200 with no order is a refusal dressed as a success. Saying so beats
    // confirming an order number of zero, and the cart is still there to try
    // again with.
    if (!order.exists) {
      _say('The order was not confirmed. Please try again.');
      return;
    }

    await _confirm(order);
  }

  /// Confirms the order, until task 6.4 draws the screen for it.
  Future<void> _confirm(PlacedOrder order) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Order placed'),
        content: Text(
          'Your order #${order.reference} is with the kitchen. '
          'We will let you know as it progresses.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    // Back to the menu rather than to a checkout for a cart that no longer
    // exists. Task 6.4 lands on the order instead.
    context.goNamed(MenuScreen.routeName);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final cart = ref.watch(cartControllerProvider).value;
    final signedIn = ref.watch(isSignedInProvider);

    // Reached with an empty cart only by a deep link or by clearing the cart
    // in another tab, but it has to say something rather than offer times,
    // addresses and a total for nothing.
    final isEmpty = cart != null && cart.isEmpty;

    return Scaffold(
      backgroundColor: palette.page,
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidate
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space16,
                  AppTokens.space16,
                  AppTokens.space16,
                  AppTokens.space24,
                ),
                children: isEmpty
                    ? const [_EmptyCartCard()]
                    : [
                        const CheckoutCard(child: FulfilmentSection()),
                        const SizedBox(height: AppTokens.space12),
                        // Accounts are required to order, so a signed-out
                        // customer gets one prompt here rather than a dead
                        // address block and a form that asks again for what
                        // the account already knows.
                        if (!signedIn)
                          const _SignInRequired()
                        else ...[
                          const CheckoutAddressSection(),
                          const SizedBox(height: AppTokens.space12),
                          const ContactDetailsSection(),
                        ],
                        const SizedBox(height: AppTokens.space12),
                        const _PaymentPending(),
                        if (cart != null) ...[
                          const SizedBox(height: AppTokens.space12),
                          OrderSummarySection(cart: cart),
                        ],
                        const SizedBox(height: AppTokens.space12),
                        const _Terms(),
                      ],
              ),
            ),
          ),
          if (cart != null && !isEmpty)
            CheckoutTotalBar(
              cart: cart,
              label: 'Place order',
              busy: _placing,
              onPlaceOrder: _placeOrder,
            ),
        ],
      ),
    );
  }
}

/// "Checkout", and under it what the customer has settled on so far.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    // The store's own words for both — the type's label as the server
    // translated it, and the slot's label as the server formatted it.
    final subtitle = [
      ref.watch(slotsProvider).value?.label,
      ref.watch(selectedSlotProvider)?.label,
    ].nonNulls.where((part) => part.isNotEmpty).join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space10,
            AppTokens.space16,
            AppTokens.space12,
          ),
          child: Row(
            children: [
              const _BackButton(),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Checkout',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: palette.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        side: BorderSide(color: palette.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        // The cart, not `pop`, when there is nothing to pop: this route sits
        // outside the shell, so a deep link lands here with an empty stack
        // and a dead button.
        onTap: () => context.canPop()
            ? context.pop()
            : context.goNamed(CartScreen.routeName),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_back, size: 20),
        ),
      ),
    );
  }
}

class _EmptyCartCard extends StatelessWidget {
  const _EmptyCartCard();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return CheckoutCard(
      child: Text(
        'Your cart is empty.',
        style: text.bodyMedium?.copyWith(color: palette.muted),
      ),
    );
  }
}

/// The gate the plan calls for: an account before an order.
class _SignInRequired extends StatelessWidget {
  const _SignInRequired();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckoutSectionTitle('Sign in to order'),
          const SizedBox(height: AppTokens.space6),
          Text(
            'Your order needs an account, so we can send you updates and keep '
            'your address for next time.',
            style: text.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppTokens.space12),
          FilledButton(
            onPressed: () => context.pushNamed(LoginScreen.routeName),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

/// What the order will be paid with, until task 6.3 draws the design's list.
class _PaymentPending extends StatelessWidget {
  const _PaymentPending();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return CheckoutCard(
      child: Row(
        children: [
          Icon(Icons.construction_outlined, size: 18, color: palette.muted),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: Text(
              'Paying with cash on delivery. Choosing a payment method '
              'arrives in task 6.3.',
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Terms extends StatelessWidget {
  const _Terms();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space4),
      child: Text(
        'By placing your order you agree to our Terms & Conditions and '
        'Privacy Policy.',
        style: text.bodySmall?.copyWith(color: palette.muted),
      ),
    );
  }
}
