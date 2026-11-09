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

/// Change the account password from inside the app.
///
/// The server requires the **current** password on top of a valid token, and
/// replaces every session on success. [AuthController.changePassword] adopts
/// the replacement, so this screen only has to report the outcome.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  static const routePath = 'password';
  static const routeName = 'change-password';

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  ApiException? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      // Taken **before** the pop: afterwards this route's context is defunct,
      // and looking the messenger up through it throws.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your password has been changed.')),
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

  /// The server names the wrong-password case, so it goes on the field it
  /// belongs to rather than in the banner above everything.
  String? _currentPasswordError(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your current password.';
    if (_error?.code == 'fmp_app_incorrect_password') return _error!.message;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final error = _error;
    final onTheField = error?.code == 'fmp_app_incorrect_password';

    return AuthShell(
      title: 'Change password',
      subtitle: 'You will stay signed in here, and be signed out everywhere '
          'else.',
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
              // Not "Change password" — that is the screen's title, and a
              // button repeating the heading reads as a second heading.
              : const Text('Update password'),
        ),
      ),
      children: [
        if (error != null && !onTheField) ...[
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
                label: 'Current password',
                controller: _current,
                enabled: !_busy,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                validator: _currentPasswordError,
              ),
              const SizedBox(height: AppTokens.space16),
              AuthField(
                label: 'New password',
                controller: _next,
                enabled: !_busy,
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => AuthValidation.newPassword(
                  value,
                  email: ref.read(currentSessionProvider)?.user.email,
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
          'Any other device signed in to this account will need to sign in '
          'again.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}
