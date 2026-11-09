import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/auth_validation.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../../auth/presentation/widgets/auth_field.dart';
import '../../auth/presentation/widgets/auth_shell.dart';

/// Change the account email from inside the app.
///
/// **The server sends no confirmation to the new address**, so a typo locks
/// the customer out of an address they can no longer prove they own. That is
/// why this screen shows what they typed back to them before it will submit,
/// rather than trusting a single field.
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  static const routePath = 'email';
  static const routeName = 'change-email';

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _confirm = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).changeEmail(
            password: _password.text,
            email: _email.text,
          );
      if (!mounted) return;
      // Taken **before** the pop: afterwards this route's context is defunct,
      // and looking the messenger up through it throws.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your email address has been changed.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      // **After** the rebuild: the validators read `_error`, so running them
      // here would ask the widgets still on screen, which have the old one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Which field the server's complaint belongs to.
  String? _serverErrorFor(String field) {
    final code = _error?.code;
    if (code == null) return null;

    return switch (field) {
      'email' when code == 'fmp_app_email_exists' ||
          code == 'fmp_app_email_unchanged' ||
          code == 'fmp_app_invalid_email' =>
        _error!.message,
      'password' when code == 'fmp_app_incorrect_password' => _error!.message,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final error = _error;
    final current = ref.watch(currentSessionProvider)?.user.email ?? '';
    final placed = error != null &&
        (_serverErrorFor('email') != null ||
            _serverErrorFor('password') != null);

    return AuthShell(
      title: 'Change email',
      subtitle: 'Your orders and receipts will go to the new address.',
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
              : const Text('Update email'),
        ),
      ),
      children: [
        if (error != null && !placed) ...[
          AuthErrorBanner(error: error),
          const SizedBox(height: AppTokens.space16),
        ],
        if (current.isNotEmpty) ...[
          Text(
            'Signed in as $current',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
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
                label: 'New email',
                controller: _email,
                enabled: !_busy,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    _serverErrorFor('email') ?? AuthValidation.email(value),
              ),
              const SizedBox(height: AppTokens.space16),
              AuthField(
                label: 'Confirm new email',
                controller: _confirm,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                // Typed twice because nothing is sent to the new address to
                // prove it exists — see the class docblock.
                validator: (value) {
                  if ((value ?? '').trim().toLowerCase() !=
                      _email.text.trim().toLowerCase()) {
                    return 'The two addresses do not match.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.space16),
              AuthField(
                label: 'Current password',
                controller: _password,
                enabled: !_busy,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (value) {
                  final server = _serverErrorFor('password');
                  if (server != null) return server;
                  if ((value ?? '').isEmpty) {
                    return 'Enter your current password.';
                  }
                  return null;
                },
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        Text(
          'No confirmation is sent to the new address, so please check it is '
          'right. You will be signed out on your other devices.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}
