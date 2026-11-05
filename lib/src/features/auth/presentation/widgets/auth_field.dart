import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// A labelled text field in the design's field style.
///
/// The design has no auth screens, so this follows its checkout inputs: a
/// filled rounded box on `field`, a hairline `line` border, and the brand red
/// only on focus and error.
class AuthField extends StatelessWidget {
  const AuthField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscure = false,
    this.enabled = true,
    this.validator,
    this.onSubmitted,
    this.trailing,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final bool enabled;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(color: palette.muted2),
        ),
        const SizedBox(height: AppTokens.space6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: trailing,
            filled: true,
            fillColor: palette.field,
            // Errors are shown under the field, so the box must not jump when
            // one appears and disappears.
            helperText: ' ',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space14,
              vertical: AppTokens.space14,
            ),
            border: _border(palette.line),
            enabledBorder: _border(palette.line),
            focusedBorder: _border(palette.brand, width: 1.5),
            errorBorder: _border(palette.brand),
            focusedErrorBorder: _border(palette.brand, width: 1.5),
            disabledBorder: _border(palette.line),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
