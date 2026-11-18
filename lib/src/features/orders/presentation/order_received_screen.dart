import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../checkout/presentation/payment_webview_screen.dart';
import '../../menu/presentation/menu_screen.dart';
import '../data/orders_repository.dart';
import '../domain/customer_order.dart';
import 'widgets/payment_instructions_card.dart';
import 'order_detail_screen.dart';

/// The design's order-received screen.
///
/// **Everything on it is read back from the server**, by id, rather than
/// carried over from the checkout's answer. Two reasons: the checkout
/// response echoes the plugin's extension schema with its defaults instead of
/// the saved order, so the time the customer chose is not in it; and a store
/// can renumber, reprice or re-status an order between the post and the
/// screen. Reading it back also makes the route survive being opened cold.
///
/// The design's "Track order" button opens the order screen, which task 7.3
/// gave the estimate, the progress strip and the timeline. It navigates into
/// the Orders tab rather than pushing, so backing out of the order lands on
/// the history list instead of on a receipt for an order already placed.
class OrderReceivedScreen extends ConsumerStatefulWidget {
  const OrderReceivedScreen({required this.orderId, this.payUrl, super.key});

  final int orderId;

  /// Where the gateway wants the customer to finish paying (task 12.2).
  ///
  /// Null for everything that completes at checkout. Non-null only for the
  /// run that placed the order: it comes from the checkout's own answer and
  /// is deliberately **not** part of the route path, so reopening this screen
  /// cold — from a notification, or a restored stack — shows the order
  /// rather than reopening a payment page the customer may have finished.
  final String? payUrl;

  static const routePath = '/order-received/:id';
  static const routeName = 'order-received';

  /// Where this screen goes next. The cart is gone and the checkout behind it
  /// is for an order already placed, so there is nothing to go back to.
  static void _home(BuildContext context) =>
      context.goNamed(MenuScreen.routeName);

  @override
  ConsumerState<OrderReceivedScreen> createState() =>
      _OrderReceivedScreenState();
}

class _OrderReceivedScreenState extends ConsumerState<OrderReceivedScreen>
    with WidgetsBindingObserver {
  /// Opened once. A rebuild must not send the customer back to the gateway,
  /// and neither must coming back from it.
  bool _opened = false;

  /// Set when the browser would not open at all, so the screen can say so
  /// instead of looking like nothing happened.
  bool _couldNotOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// **The only way back from an in-app browser view.**
  ///
  /// `LaunchMode.inAppBrowserView` is a Custom Tab on Android and an
  /// `SFSafariViewController` on iOS, and neither reports the URL it ended
  /// on, so there is no return to intercept. Resuming is the signal, and the
  /// order itself is the answer — which also covers the customer who killed
  /// the browser, paid on another device, or never came back at all.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.payUrl != null) {
      ref.invalidate(orderProvider(widget.orderId));
    }
  }

  Future<void> _pay({bool again = false}) async {
    final url = widget.payUrl;
    if (url == null || url.isEmpty) return;
    if (_opened && !again) return;

    if (Uri.tryParse(url) == null) {
      if (mounted) setState(() => _couldNotOpen = true);
      return;
    }

    _opened = true;
    final gateway = ref.read(orderProvider(widget.orderId)).value
        ?.paymentMethodTitle;

    // **Pushed, not launched.** Task 12.2 opened a Custom Tab, which is
    // in-app in the technical sense and reads as leaving for Chrome. This is
    // the app's own screen, and it can watch where the gateway navigates.
    await context.pushNamed(
      PaymentWebViewScreen.routeName,
      extra: (
        url: url,
        title: gateway == null || gateway.isEmpty ? 'Payment' : gateway,
      ),
    );

    // Back from the gateway, however it ended. The order decides.
    if (mounted) ref.invalidate(orderProvider(widget.orderId));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final order = ref.watch(orderProvider(widget.orderId));

    // The gateway opens as soon as the order confirms it is unpaid — not on
    // the first frame, when nothing has been read back yet.
    final unpaid = order.value?.needsPayment ?? false;
    if (widget.payUrl != null && unpaid && !_opened) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pay());
    }

    return PopScope(
      // Back is "home", not "out of the app": this route replaces the stack,
      // so there is nothing beneath it to pop to.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) OrderReceivedScreen._home(context);
      },
      child: Scaffold(
        backgroundColor: palette.card,
        body: SafeArea(
          // **Value before loading**, task 14.8's rule: resuming from the
          // gateway invalidates this provider, and a refreshing provider is
          // loading *while still holding* its last value. Matching loading
          // first would replace the screen with a spinner every time the
          // customer came back from paying.
          child: switch (order) {
            AsyncValue(:final value?) =>
              widget.payUrl != null && value.needsPayment
                  // Only now, and only once: opening on the first frame
                  // would send a customer to pay for an order that the read
                  // we had not waited for says is already paid.
                  ? _AwaitingPayment(
                      order: value,
                      couldNotOpen: _couldNotOpen,
                      onPay: () => _pay(again: true),
                      onCheck: () =>
                          ref.invalidate(orderProvider(widget.orderId)),
                      onHome: () => OrderReceivedScreen._home(context),
                    )
                  : _Placed(order: value),
            AsyncError(:final error) => _Unreadable(
              error: error,
              onRetry: () => ref.invalidate(orderProvider(widget.orderId)),
              onHome: () => OrderReceivedScreen._home(context),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

/// An order that is placed but not paid — the gateway finishes in a browser.
///
/// **Not a failure, and not a success.** The order exists, the kitchen has
/// not started, and the money is somewhere between the app and the gateway.
/// Saying "Order placed!" here would be the same lie task 12.1 took out of
/// the bank-transfer case, and an error page would be worse: the customer may
/// be one tap from finishing.
class _AwaitingPayment extends StatelessWidget {
  const _AwaitingPayment({
    required this.order,
    required this.couldNotOpen,
    required this.onPay,
    required this.onCheck,
    required this.onHome,
  });

  final CustomerOrder order;
  final bool couldNotOpen;
  final VoidCallback onPay;
  final VoidCallback onCheck;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    // The merchant's own name for the gateway, as everywhere else.
    final gateway = order.paymentMethodTitle;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space24,
                AppTokens.space24,
                AppTokens.space24,
                AppTokens.space16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      AppTokens.space24 -
                      AppTokens.space16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: palette.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_clock_outlined,
                        size: 40,
                        color: palette.brand,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    Text(
                      'Finish your payment',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),
                    Text(
                      couldNotOpen
                          ? 'We could not open the payment page. Try again, '
                                'or pay from the order in your account.'
                          : gateway.isEmpty
                          ? 'Your order is placed and waiting to be paid.'
                          : 'Your order is placed. Pay with $gateway to send '
                                'it to the kitchen.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    _Facts(order: order),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space12,
            AppTokens.space16,
            AppTokens.space24,
          ),
          child: Column(
            children: [
              FilledButton(
                onPressed: onPay,
                child: Text(couldNotOpen ? 'Try again' : 'Pay now'),
              ),
              const SizedBox(height: AppTokens.space8),
              // For the customer who paid somewhere this app cannot see — on
              // a desktop, or in a browser it never opened.
              TextButton(
                onPressed: onCheck,
                child: const Text('I have already paid'),
              ),
              TextButton(onPressed: onHome, child: const Text('Back to home')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Placed extends StatelessWidget {
  const _Placed({required this.order});

  final CustomerOrder order;

  /// What the customer is told under "Order placed!".
  static String _subtitle(String name, {required bool waiting}) {
    final what = waiting
        ? 'We will start your order as soon as your payment arrives.'
        : 'The kitchen has your order and is getting started.';

    return name.isEmpty ? what : 'Thanks, $name. $what';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final name = order.firstName;

    return Column(
      children: [
        Expanded(
          // Centred when it fits and scrollable when it does not — a short
          // phone, or a large text scale, otherwise clips the tiles.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space24,
                AppTokens.space24,
                AppTokens.space24,
                AppTokens.space16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight -
                      AppTokens.space24 -
                      AppTokens.space16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Tick(),
                    const SizedBox(height: AppTokens.space20),
                    Text(
                      'Order placed!',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),
                    Text(
                      // The name is the one on the order, not the one in the
                      // session: the order is what the kitchen works from.
                      //
                      // **An unpaid order is not being cooked.** Bank
                      // transfer and cheque leave it on hold until the money
                      // lands, so promising a kitchen already working on it
                      // would be the one sentence on this screen that is not
                      // true (task 12.1).
                      _subtitle(
                        name,
                        waiting: order.paymentInstructions != null,
                      ),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    _Facts(order: order),
                    if (order.paymentInstructions != null) ...[
                      const SizedBox(height: AppTokens.space16),
                      PaymentInstructionsCard(
                        instructions: order.paymentInstructions!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _Actions(
          onTrack: () => context.goNamed(
            OrderDetailScreen.routeName,
            pathParameters: {'id': '${order.id}'},
          ),
          onHome: () => OrderReceivedScreen._home(context),
        ),
      ],
    );
  }
}

/// The design's three tiles: the order, when it is due, and what it cost.
class _Facts extends StatelessWidget {
  const _Facts({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    // `IntrinsicHeight`, because the three tiles have to be equally tall and
    // a bare `stretch` inside the scroll view asks for infinite height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Fact(label: 'Order', value: '#${order.number}'),
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: _Fact(
              // The store's own word for the type — "Pickup", "Delivery" —
              // over its own estimate, neither composed here.
              label: order.typeLabel.isEmpty ? 'Estimated' : order.typeLabel,
              value: order.eta.isEmpty ? '—' : order.eta,
              // Only for an order placed for another day, which the date
              // strip made possible: "12:00 am" alone reads as tonight.
              note: order.scheduledDate,
            ),
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: _Fact(
              label: 'Total',
              value: order.totals.totalPrice.format(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.note = ''});

  final String label;
  final String value;

  /// A quieter line under the value. Empty on most tiles.
  final String note;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppTokens.space2),
          Text(
            value,
            maxLines: 2,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (note.isNotEmpty)
            Text(
              note,
              maxLines: 2,
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.tint, shape: BoxShape.circle),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: palette.brand, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 40, color: Colors.white),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onTrack, required this.onHome});

  final VoidCallback onTrack;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space12,
        AppTokens.space16,
        AppTokens.space24,
      ),
      child: Column(
        children: [
          // Primary, as the design has it: the next thing a customer who has
          // just ordered wants is to watch it being made.
          FilledButton(onPressed: onTrack, child: const Text('Track order')),
          const SizedBox(height: AppTokens.space8),
          TextButton(onPressed: onHome, child: const Text('Back to home')),
        ],
      ),
    );
  }
}

/// The order exists; this screen could not read it.
///
/// **Never says the order failed.** It was placed — the checkout answered
/// with it — so the worst case here is that the customer cannot see it yet.
class _Unreadable extends StatelessWidget {
  const _Unreadable({
    required this.error,
    required this.onRetry,
    required this.onHome,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final api = error is ApiException ? error as ApiException : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _Tick(),
            const SizedBox(height: AppTokens.space20),
            Text(
              'Your order is placed',
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              api?.message ?? 'We could not load its details just now.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppTokens.space20),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            const SizedBox(height: AppTokens.space8),
            TextButton(onPressed: onHome, child: const Text('Back to home')),
          ],
        ),
      ),
    );
  }
}
