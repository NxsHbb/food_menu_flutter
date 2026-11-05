import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// Shared chrome for the sign-in and register screens.
///
/// The design has no auth screens at all — the account screen assumes somebody
/// is already signed in — so this is built from the design's own vocabulary:
/// the `page` background, a card-less form on it, 16px gutters and the red
/// full-width call to action from checkout.
class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.action,
    this.footer,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  /// The primary button, pinned under the form.
  final Widget action;

  /// The "no account yet?" line below the button.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: palette.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space16,
              0,
              AppTokens.space16,
              AppTokens.space24,
            ),
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppTokens.space6),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: AppTokens.space24),
              ...children,
              const SizedBox(height: AppTokens.space8),
              action,
              if (footer != null) ...[
                const SizedBox(height: AppTokens.space16),
                Center(child: footer),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The design's primary call to action: full width, 48 high, brand red.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTokens.buttonHeight,
      child: FilledButton(
        // Disabled while in flight, so a double tap cannot submit twice — on
        // register that would mean two accounts' worth of rate limit spent.
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
