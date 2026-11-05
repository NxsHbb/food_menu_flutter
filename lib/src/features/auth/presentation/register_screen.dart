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

/// Create an account, which signs the customer straight in.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  static const routePath = '/register';
  static const routeName = 'register';

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  ApiException? _error;

  /// Set when the server says the address is taken, so the banner can offer
  /// to go back to sign-in instead of just reporting a dead end.
  bool _emailTaken = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _emailTaken = false;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _email.text,
            password: _password.text,
            firstName: _firstName.text,
            lastName: _lastName.text,
            phone: _phone.text,
          );
      if (!mounted) return;
      // Pops twice-over through the sign-in screen that sent us here, so the
      // customer lands back where they started rather than on a login form
      // they no longer need.
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _emailTaken = error.code == 'fmp_app_email_exists';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return AuthShell(
      title: 'Create your account',
      subtitle: 'An account is needed to place an order and track it.',
      action: AuthSubmitButton(
        label: 'Create account',
        busy: _busy,
        onPressed: _submit,
      ),
      footer: Text(
        'We only use your details for your orders.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AuthField(
                      label: 'First name',
                      controller: _firstName,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      validator: (v) => AuthValidation.name(v, field: 'first name'),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: AuthField(
                      label: 'Last name',
                      controller: _lastName,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      validator: (v) => AuthValidation.name(v, field: 'last name'),
                    ),
                  ),
                ],
              ),
              AuthField(
                label: 'Email',
                controller: _email,
                hint: 'you@example.com',
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                validator: AuthValidation.email,
              ),
              AuthField(
                label: 'Phone (optional)',
                controller: _phone,
                hint: 'So the driver can reach you',
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: AuthValidation.optionalPhone,
              ),
              AuthField(
                label: 'Password',
                controller: _password,
                hint: 'At least ${AuthValidation.minPasswordLength} characters',
                enabled: !_busy,
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => AuthValidation.newPassword(v, email: _email.text),
                onSubmitted: (_) => _submit(),
                trailing: IconButton(
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                  ),
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          AuthErrorBanner(error: _error!, onRetry: _submit),
          if (_emailTaken)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                child: const Text('Sign in instead'),
              ),
            ),
          const SizedBox(height: AppTokens.space12),
        ],
      ],
    );
  }
}
