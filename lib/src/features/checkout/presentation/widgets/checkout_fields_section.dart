import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/presentation/widgets/auth_field.dart';
import '../../data/checkout_controller.dart';
import '../../data/checkout_repository.dart';
import '../../domain/checkout_field.dart';
import 'checkout_card.dart';

/// The store's own checkout questions — "Additional information".
///
/// **Absent, not empty**, when a store has defined none or switched the
/// section off: there is no heading over nothing. The same when the route
/// fails or the plugin is too old, because a checkout that will not draw
/// because an optional section could not load is worse than one without it.
///
/// The design has no vocabulary for these — it predates them — so a text
/// field reuses the app's own labelled input and a select is drawn as the
/// add-on group's option rows, which is the control a customer has already
/// met on the dish screen.
class CheckoutFieldsSection extends ConsumerStatefulWidget {
  const CheckoutFieldsSection({super.key});

  @override
  ConsumerState<CheckoutFieldsSection> createState() =>
      _CheckoutFieldsSectionState();
}

class _CheckoutFieldsSectionState
    extends ConsumerState<CheckoutFieldsSection> {
  /// One per text field, seeded once from the checkout state so a refused
  /// order hands the answers back with everything else.
  final _controllers = <String, TextEditingController>{};

  TextEditingController _controllerFor(CheckoutField field, String seed) {
    return _controllers.putIfAbsent(
      field.key,
      () => TextEditingController(text: seed),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = ref.watch(checkoutFieldsProvider).value ?? const [];

    if (fields.isEmpty) return const SizedBox.shrink();

    final answers = ref.watch(checkoutControllerProvider).answers;
    final controller = ref.read(checkoutControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space12),
      child: CheckoutCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CheckoutSectionTitle('Additional information'),
            const SizedBox(height: AppTokens.space12),
            for (final field in fields) ...[
              _Field(
                field: field,
                answers: answers,
                onChanged: controller.answer,
                controller: field.type == CheckoutFieldType.text
                    ? _controllerFor(field, answers.textFor(field))
                    : null,
              ),
              if (field != fields.last)
                const SizedBox(height: AppTokens.space8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.field,
    required this.answers,
    required this.onChanged,
    required this.controller,
  });

  final CheckoutField field;
  final CheckoutFieldAnswers answers;
  final ValueChanged<CheckoutFieldAnswers> onChanged;

  /// Non-null for a text field only.
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    if (controller case final text?) {
      return AuthField(
        label: _label,
        controller: text,
        hint: field.required ? null : 'Optional',
        // The screen's own Form drives this, so a required question errors in
        // the same pass as the name and the phone rather than through a
        // second mechanism of its own.
        validator: field.required ? _requiredText : null,
        onChanged: (value) => onChanged(answers.setText(field, value)),
      );
    }

    return _Select(
      field: field,
      answers: answers,
      onChanged: onChanged,
      label: _label,
    );
  }

  static String? _requiredText(String? value) =>
      (value ?? '').trim().isEmpty ? 'This is required' : null;

  /// The store's own wording, marked when it has to be answered.
  String get _label => field.required ? '${field.label} *' : field.label;
}

class _Select extends StatelessWidget {
  const _Select({
    required this.field,
    required this.answers,
    required this.onChanged,
    required this.label,
  });

  final CheckoutField field;
  final CheckoutFieldAnswers answers;
  final ValueChanged<CheckoutFieldAnswers> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    // A `FormField` rather than a bare column: a select is not a text input,
    // and this is what puts it in the screen's own validate() pass alongside
    // the fields that are.
    return FormField<List<String>>(
      initialValue: answers.forField(field),
      validator: (value) => field.required && (value ?? const []).isEmpty
          ? 'This is required'
          : null,
      builder: (state) {
        final palette = AppPalette.of(context);
        final text = Theme.of(context).textTheme;
        final showError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: text.labelLarge?.copyWith(
                color: showError ? palette.brand : palette.muted,
              ),
            ),
            const SizedBox(height: AppTokens.space4),
            for (final option in field.options)
              _Option(
                label: option,
                chosen: answers.isSelected(field, option),
                // A single-choice select is a radio, a multiple one a
                // checkbox — the same two controls the dish screen's add-on
                // groups use.
                multiple: field.multiple,
                onTap: () {
                  final next = answers.toggle(field, option);
                  // Both: the field's own value for validation, and the
                  // checkout state that actually goes to the server.
                  state.didChange(next.forField(field));
                  onChanged(next);
                },
              ),
            if (showError) ...[
              const SizedBox(height: AppTokens.space2),
              Text(
                state.errorText!,
                style: text.bodySmall?.copyWith(color: palette.brand),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.chosen,
    required this.multiple,
    required this.onTap,
  });

  final String label;
  final bool chosen;
  final bool multiple;
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
                shape: multiple ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: multiple
                    ? BorderRadius.circular(AppTokens.radiusChip / 2)
                    : null,
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
                label,
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
