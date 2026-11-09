import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/auth_controller.dart';
import '../domain/auth_validation.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_shell.dart';

/// Step two of a password reset: the emailed code and a new password.
///
/// A success **signs the customer in**, so this pops the whole reset flow
/// rather than returning to the sign-in form they no longer need.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.email, super.key});

  final String email;

  static const routePath = '/reset-password';
  static const routeName = 'reset-password';

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  bool _resent = false;
  ApiException? _error;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            email: widget.email,
            code: _code.text,
            password: _password.text,
          );
      if (!mounted) return;

      // Signed in now, so unwind the whole flow — this screen, the email
      // screen, and the sign-in form underneath them.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .forgotPassword(widget.email);
      if (mounted) setState(() => _resent = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return AuthShell(
      title: 'Enter your code',
      subtitle: 'We sent a six-digit code to ${widget.email}. '
          'It is good for fifteen minutes.',
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
              : const Text('Set new password'),
        ),
      ),
      footer: TextButton(
        onPressed: _busy ? null : _resend,
        child: Text(_resent ? 'Code sent again' : 'Send another code'),
      ),
      children: [
        if (_error case final error?) ...[
          AuthErrorBanner(error: error),
          const SizedBox(height: AppTokens.space16),
        ],
        Form(
          key: _formKey,
          // Re-validate as the customer edits, and drop any server complaint
          // the moment they touch the field it was about. Without this a
          // message stays on screen after it has been fixed, until the next
          // submit says otherwise.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: () {
            if (_error != null) setState(() => _error = null);
          },
          child: Column(
            children: [
              AuthField(
                label: 'Six-digit code',
                controller: _code,
                enabled: !_busy,
                hint: '123456',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.oneTimeCode],
                validator: AuthValidation.resetCode,
              ),
              const SizedBox(height: AppTokens.space16),
              AuthField(
                label: 'New password',
                controller: _password,
                enabled: !_busy,
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => AuthValidation.newPassword(
                  value,
                  email: widget.email,
                ),
                onSubmitted: (_) => _busy ? null : _submit(),
                trailing: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  color: palette.muted,
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        Text(
          'Setting a new password signs you out everywhere else.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}
