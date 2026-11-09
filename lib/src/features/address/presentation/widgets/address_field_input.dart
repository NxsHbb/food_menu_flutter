import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/presentation/widgets/auth_field.dart';
import '../../domain/address_field.dart';

/// One input of the address form, drawn from the server's description of it.
///
/// A text field, a phone field or a picker, decided by [AddressField.type] and
/// whether the field came with options. The app never decides which — see the
/// screen's docblock.
class AddressFieldInput extends StatelessWidget {
  const AddressFieldInput({
    required this.field,
    this.controller,
    this.value,
    this.options,
    this.onChanged,
    this.enabled = true,
    this.hint,
    this.serverError,
    super.key,
  });

  final AddressField field;

  /// For a text input. Null for a picker.
  final TextEditingController? controller;

  /// For a picker. Null for a text input.
  final String? value;

  /// Overrides [AddressField.options] — used for `country`, whose choices
  /// live on the response rather than on the field.
  final Map<String, String>? options;

  final ValueChanged<String?>? onChanged;
  final bool enabled;
  final String? hint;

  /// A message the server returned for this field, shown until it is edited.
  final String? serverError;

  Map<String, String> get _options => options ?? field.options;

  /// Required-ness comes from the server, so this is the only validation the
  /// app does. Format is the server's business: it knows a US ZIP from a UK
  /// postcode, and rejecting here would mean encoding that twice.
  String? _validate(String? input) {
    if (serverError != null) return serverError;
    if (!field.required) return null;
    if ((input ?? '').trim().isEmpty) return '${field.label} is required.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (field.isPicker) return _picker(context);

    return AuthField(
      label: _label,
      controller: controller!,
      enabled: enabled,
      hint: hint,
      keyboardType: switch (field.type) {
        'tel' => TextInputType.phone,
        _ => TextInputType.streetAddress,
      },
      textInputAction: TextInputAction.next,
      validator: _validate,
    );
  }

  /// The server's own wording, with the app's required marker.
  String get _label => field.required ? '${field.label} *' : field.label;

  Widget _picker(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final entries = _options.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_label, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppTokens.space6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          validator: _validate,
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.field,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space14,
              vertical: AppTokens.space12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              borderSide: BorderSide(color: palette.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              borderSide: BorderSide(color: palette.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              borderSide: BorderSide(color: palette.brand),
            ),
          ),
          hint: Text(
            'Select ${field.label.toLowerCase()}',
            style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
          items: [
            for (final entry in entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ],
    );
  }
}
