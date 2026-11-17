import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../../auth/presentation/widgets/auth_field.dart';
import '../../auth/presentation/widgets/auth_shell.dart';

/// Delete the account from inside the app, which both app stores require of
/// any app that can create one.
///
/// **Two bars, not one.** The password proves the person rather than the
/// phone, exactly as the other security routes do; the confirmation dialog is
/// about the one thing those routes are not, which is irreversible. Neither
/// stands in for the other — a stolen phone cannot get past the first, and a
/// mis-tap cannot get past the second.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static const routePath = 'delete';
  static const routeName = 'delete-account';

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This cannot be undone. You will be signed out and your profile, '
          'saved addresses and wishlist will be gone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final message = await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password: _password.text);
      if (!mounted) return;
      // Taken before the pop, as the other security screens do: afterwards
      // this route's context is defunct and the messenger lookup throws.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      // The server's own sentence, because only it knows whether the store
      // keeps the details on past orders.
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      // After the rebuild, so the validators read the error that has just
      // arrived rather than the one the widgets on screen were built with.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The server names the wrong-password case, so it goes on the field it
  /// belongs to rather than in the banner above everything.
  String? _passwordError(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    if (_error?.code == 'fmp_app_incorrect_password') return _error!.message;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final onTheField = error?.code == 'fmp_app_incorrect_password';

    return AuthShell(
      title: 'Delete account',
      subtitle: 'Enter your password to confirm. This cannot be undone.',
      // The default fill, deliberately: this theme sets `colorScheme.error` to
      // the brand red the primary button already uses, so styling it as the
      // error colour would change nothing but the code. What marks this
      // button as destructive is its label, the caution box above it and the
      // dialog behind it.
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
              : const Text('Delete my account'),
        ),
      ),
      children: [
        if (error != null && !onTheField) ...[
          AuthErrorBanner(error: error),
          const SizedBox(height: AppTokens.space16),
        ],
        const _WhatHappens(),
        const SizedBox(height: AppTokens.space16),
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: () {
            if (_error != null) setState(() => _error = null);
          },
          child: AuthField(
            label: 'Password',
            controller: _password,
            enabled: !_busy,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: _passwordError,
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
        ),
      ],
    );
  }
}

/// What deletion actually does, said before it is done.
///
/// The orders line is the one that cannot be left out: a customer is entitled
/// to know the store keeps them, and finding out afterwards is the kind of
/// surprise that becomes a complaint. The exact wording of what happened comes
/// back from the server, which has read the store's own setting; this says
/// only the part that is true either way.
class _WhatHappens extends StatelessWidget {
  const _WhatHappens();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    const lines = [
      'Your profile, saved addresses and wishlist are deleted.',
      'You are signed out on every device.',
      'Your past orders stay with the store as its own records.',
      'An order already on its way will no longer be visible to you.',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space14),
      decoration: BoxDecoration(
        color: palette.warnBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, line) in lines.indexed) ...[
            if (index > 0) const SizedBox(height: AppTokens.space8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.circle,
                    size: 5,
                    color: palette.warnForeground,
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                Expanded(
                  child: Text(
                    line,
                    style: text.bodySmall?.copyWith(
                      color: palette.warnForeground,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
