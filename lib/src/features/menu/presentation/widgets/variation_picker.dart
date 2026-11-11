import 'package:flutter/material.dart';

import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/variation_selection.dart';

/// A variable dish's attributes, as cards on the dish screen.
///
/// Drawn like an add-on group deliberately: to a customer, "Size: small,
/// medium, large" and "Choose your size" are the same question, and they
/// should not look like two different controls because one is a WooCommerce
/// attribute and the other a Food Menu add-on.
///
/// **Always required, and never pre-answered.** A variable dish has no price
/// until a combination is picked, and the Store API sends no default
/// attributes to seed from — so the customer answers every one.
class VariationPicker extends StatelessWidget {
  const VariationPicker({
    required this.attributes,
    required this.selection,
    required this.onChoose,
    this.showError = false,
    super.key,
  });

  final List<ProductAttribute> attributes;
  final VariationSelection selection;
  final void Function(ProductAttribute attribute, AttributeTerm term) onChoose;

  /// Set once the customer has pressed Add with something unanswered.
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final attribute in attributes) ...[
          _AttributeCard(
            attribute: attribute,
            selection: selection,
            onChoose: onChoose,
            showError: showError && selection.slugFor(attribute) == null,
          ),
          const SizedBox(height: AppTokens.space12),
        ],
      ],
    );
  }
}

class _AttributeCard extends StatelessWidget {
  const _AttributeCard({
    required this.attribute,
    required this.selection,
    required this.onChoose,
    required this.showError,
  });

  final ProductAttribute attribute;
  final VariationSelection selection;
  final void Function(ProductAttribute attribute, AttributeTerm term) onChoose;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final answered = selection.slugFor(attribute) != null;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
        border: showError ? Border.all(color: palette.brand) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // The store's own word for it. There is no separate label
                  // to fall back on, and a store that calls an attribute
                  // `pa_size` calls it that on its own website too.
                  attribute.name,
                  style: text.titleSmall,
                ),
              ),
              _Badge(answered: answered, error: showError),
            ],
          ),
          if (showError) ...[
            const SizedBox(height: AppTokens.space2),
            Text(
              'Please make a selection',
              style: text.bodySmall?.copyWith(color: palette.brand),
            ),
          ],
          const SizedBox(height: AppTokens.space12),
          for (final term in attribute.terms)
            _TermRow(
              term: term,
              chosen: selection.isChosen(attribute, term),
              onTap: () => onChoose(attribute, term),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.answered, required this.error});

  final bool answered;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    final (label, foreground, background) = switch ((answered, error)) {
      (true, _) => ('Done', palette.okForeground, palette.okBackground),
      (false, true) => ('Required', palette.contrast, palette.brand),
      (false, false) => ('Required', palette.muted2, palette.chip),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space10,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
      ),
      child: Text(
        label,
        style: text.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// One choice. A radio, because exactly one term of each attribute applies.
class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.term,
    required this.chosen,
    required this.onTap,
  });

  final AttributeTerm term;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chosen ? palette.brand : palette.card,
                border: Border.all(
                  color: chosen ? palette.brand : palette.ring,
                  width: 1.5,
                ),
              ),
              child: chosen
                  ? Icon(Icons.check, size: 14, color: palette.contrast)
                  : null,
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(
                term.name,
                style: text.bodyMedium?.copyWith(
                  fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
