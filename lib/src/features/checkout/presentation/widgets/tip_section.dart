import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/store_api/models/cart.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../cart/data/cart_controller.dart';
import 'checkout_card.dart';

/// The store's tip prompt (task 9.4).
///
/// **Drawn from the store's own setup, not the design.** The design has no tip
/// anywhere, so this is built in the app's own vocabulary — like the address
/// screens — out of the four things the plugin actually configures: whether
/// tipping is on, which kinds are allowed, where the form belongs, and the
/// store's own wording for the prompt.
///
/// **No preset amounts.** The plugin configures none — the website asks the
/// customer to type one — so offering "10% / 15% / 20%" would be the app
/// inventing a store policy and then charging the customer for it.
class TipSection extends ConsumerStatefulWidget {
  const TipSection({this.screen = 'checkout', super.key});

  /// Which of the store's two places this is: `checkout` or `cart`.
  final String screen;

  @override
  ConsumerState<TipSection> createState() => _TipSectionState();
}

class _TipSectionState extends ConsumerState<TipSection> {
  final _controller = TextEditingController();
  String? _type;
  var _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The kind in force: what the customer picked, else what is already on the
  /// cart, else the only kind the store allows.
  String _resolvedType(CartTip tip) {
    if (_type != null && tip.allow.contains(_type)) return _type!;
    if (tip.type.isNotEmpty && tip.allow.contains(tip.type)) return tip.type;
    return tip.allowsFixed ? 'fixed' : 'percentage';
  }

  Future<void> _send(int amount) async {
    final tip = ref.read(cartControllerProvider).value?.tip ?? CartTip.none;

    setState(() => _busy = true);
    try {
      await ref
          .read(cartControllerProvider.notifier)
          .setTip(type: _resolvedType(tip), amount: amount);
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not change the tip.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider).value;
    final tip = cart?.tip ?? CartTip.none;

    if (!tip.enabled || tip.allow.isEmpty || !tip.showOn(widget.screen)) {
      return const SizedBox.shrink();
    }

    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final type = _resolvedType(tip);

    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckoutSectionTitle(
            tip.heading.isNotEmpty ? tip.heading : 'Add a tip',
          ),
          const SizedBox(height: AppTokens.space12),
          // Only when the store allows both. One kind is not a choice, and a
          // toggle that cannot move reads as a broken control.
          if (tip.allowsFixed && tip.allowsPercentage) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fixed', label: Text('Amount')),
                ButtonSegment(value: 'percentage', label: Text('Percent')),
              ],
              selected: {type},
              onSelectionChanged: _busy
                  ? null
                  : (selected) => setState(() {
                        _type = selected.first;
                        _controller.clear();
                      }),
            ),
            const SizedBox(height: AppTokens.space12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    hintText: type == 'percentage' ? '10' : '2.00',
                    prefixText: type == 'percentage' ? null : ' ',
                    suffixText: type == 'percentage' ? '%' : null,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              // **Width, because the theme gives every FilledButton
              // `Size.fromHeight` — which is an infinite width.** That is
              // right for the full-bleed buttons the design is made of, and
              // it means one cannot sit in a Row without being told how wide
              // to be.
              SizedBox(
                width: 96,
                child: FilledButton(
                  onPressed: _busy ? null : () => _send(_entered(type)),
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
          if (tip.isSet) ...[
            const SizedBox(height: AppTokens.space8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _currentLabel(tip),
                    style: text.bodySmall?.copyWith(color: palette.muted),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _send(0),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// What the customer typed, in the units the plugin's session stores:
  /// minor units for an amount, whole percent for a percentage.
  int _entered(String type) {
    final raw = double.tryParse(_controller.text.trim()) ?? 0;
    if (raw <= 0) return 0;

    return type == 'percentage' ? raw.round() : (raw * 100).round();
  }

  String _currentLabel(CartTip tip) {
    if (tip.type == 'percentage') return '${tip.percentage}% tip added.';
    final fixed = tip.fixed;
    return fixed == null ? 'Tip added.' : '${fixed.format()} tip added.';
  }
}
