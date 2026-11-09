import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/auth_controller.dart';
import '../domain/auth_validation.dart';
import 'reset_password_screen.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_shell.dart';

/// Step one of a password reset: ask for the code.
///
/// Not in the design, which has no auth screens at all, so it follows the
/// sign-in and register screens built in task 3.3.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({this.email, super.key});

  /// Prefilled from the sign-in form, so a customer who has already typed
  /// their address does not type it twice.
  final String? email;

  static const routePath = '/forgot-password';
  static const routeName = 'forgot-password';

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.email ?? '');

  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).forgotPassword(
            _email.text,
          );
      if (!mounted) return;

      // Straight on to the code screen, **without** saying whether the
      // address had an account. The server will not tell us, and a screen
      // that only advanced for real customers would leak exactly what the
      // server is refusing to.
      await context.pushNamed(
        ResetPasswordScreen.routeName,
        queryParameters: {'email': _email.text.trim()},
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Reset your password',
      subtitle: 'We will email you a six-digit code to get back in.',
      action: SizedBox(
        height: AppTokens.buttonHeight,
        child: FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Email me a code'),
        ),
      ),
      footer: TextButton(
        onPressed: _busy ? null : () => context.pop(),
        child: const Text('Back to sign in'),
      ),
      children: [
        if (_error case final error?) ...[
          AuthErrorBanner(error: error),
          const SizedBox(height: AppTokens.space16),
        ],
        Form(
          key: _formKey,
          child: AuthField(
            label: 'Email',
            controller: _email,
            enabled: !_busy,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: AuthValidation.email,
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
        ),
      ],
    );
  }
}
