import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/screen_header.dart';
import '../domain/payment_return.dart';

/// The gateway's own payment page, inside the app (task 12.4).
///
/// **Replaces the Custom Tab task 12.2 shipped with.** That was already
/// in-app in the technical sense, but it wore browser chrome and a URL bar
/// and read as leaving for Chrome. A webview sits under the app's own header
/// instead — and, more usefully, the app can *see* where the gateway
/// navigates, so it closes itself the moment the customer lands back on the
/// store rather than waiting for them to find the X.
///
/// **The URL is a hint, never the answer.** Landing on `order-received` means
/// come back and look; whether the order was actually paid is decided by
/// re-reading the order, exactly as it was when this was a Custom Tab. A
/// webview that guessed from a URL would eventually tell somebody their money
/// had arrived when it had not.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({
    required this.payUrl,
    required this.title,
    super.key,
  });

  static const routePath = '/pay';
  static const routeName = 'pay';

  final String payUrl;

  /// The merchant's own name for the gateway, as everywhere else.
  final String title;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Every gateway's checkout is JavaScript, and Razorpay's keeps state in
      // DOM storage; without it the page loads and then does nothing.
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigate,
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Only the main document matters. A gateway page pulls in fonts
            // and beacons that fail routinely and mean nothing.
            if (!error.isForMainFrame!) return;
            if (mounted) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.payUrl));
  }

  FutureOr<NavigationDecision> _onNavigate(NavigationRequest request) async {
    final url = Uri.tryParse(request.url);
    if (url == null) return NavigationDecision.navigate;

    switch (classifyPaymentUrl(url, storeHost: _storeHost)) {
      case PaymentNavigation.allow:
        return NavigationDecision.navigate;

      case PaymentNavigation.finished:
        _close();
        return NavigationDecision.prevent;

      case PaymentNavigation.delegate:
        // A UPI intent or a banking app: a webview cannot open these and
        // fails silently, which looks like a dead button.
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } on PlatformException {
          // Nothing installed that can take it. Staying put is better than
          // closing the payment the customer is in the middle of.
        }
        return NavigationDecision.prevent;
    }
  }

  /// The host the app talks to, so a return to the shop is recognisable.
  String? get _storeHost =>
      Uri.tryParse(AppConfig.fromEnvironment().baseUrl)?.host;

  void _close() {
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.bg,
      body: Column(
        children: [
          ScreenHeader(title: widget.title, onBack: _close),
          Expanded(
            child: _failed
                ? _Failed(onBack: _close)
                : Stack(
                    children: [
                      WebViewWidget(controller: _controller),
                      if (_loading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The gateway's page would not load at all.
///
/// No retry here on purpose: the screen behind this one still has the order
/// and its own **Pay now**, so going back is the retry and there is nothing
/// for a second button to do differently.
class _Failed extends StatelessWidget {
  const _Failed({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.space24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_outlined, size: 44, color: palette.muted),
          const SizedBox(height: AppTokens.space16),
          Text(
            'The payment page could not be loaded.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppTokens.space16),
          FilledButton(onPressed: onBack, child: const Text('Go back')),
        ],
      ),
    );
  }
}
