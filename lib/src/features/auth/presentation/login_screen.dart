import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/auth_controller.dart';
import '../domain/auth_validation.dart';
import 'register_screen.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_field.dart';
import 'forgot_password_screen.dart';
import 'widgets/auth_shell.dart';

/// Sign in with an email (or username) and password.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const routePath = '/sign-in';
  static const routeName = 'sign-in';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  ApiException? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear the banner first: leaving a stale error on screen while a new
    // attempt is in flight reads as though the new one already failed.
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).login(
            username: _username.text,
            password: _password.text,
          );
      if (!mounted) return;
      // Whoever sent the customer here is waiting for a result, so pop rather
      // than navigate: the gated action they were attempting resumes.
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in to order, track deliveries and keep your favourites.',
      action: AuthSubmitButton(
        label: 'Sign in',
        busy: _busy,
        onPressed: _submit,
      ),
      footer: Column(
        children: [
          TextButton(
            onPressed: _busy
                ? null
                : () => context.pushNamed(
                      ForgotPasswordScreen.routeName,
                      // Carried over so a customer who has already typed
                      // their address does not type it again.
                      queryParameters: {'email': _username.text.trim()},
                    ),
            child: const Text('Forgot your password?'),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'New here? ',
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
              ),
              GestureDetector(
                onTap: _busy
                    ? null
                    : () => context.pushNamed(RegisterScreen.routeName),
                child: Text(
                  'Create an account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthField(
                label: 'Email',
                controller: _username,
                hint: 'you@example.com',
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: AuthValidation.emailOrUsername,
              ),
              AuthField(
                label: 'Password',
                controller: _password,
                enabled: !_busy,
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: AuthValidation.existingPassword,
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
          AuthErrorBanner(
            error: _error!,
            onRetry: _submit,
          ),
          const SizedBox(height: AppTokens.space12),
        ],
      ],
    );
  }
}
