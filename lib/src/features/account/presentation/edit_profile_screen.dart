import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/auth_validation.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../../auth/presentation/widgets/auth_field.dart';
import '../../auth/presentation/widgets/auth_shell.dart';
import '../data/profile_repository.dart';
import 'change_email_screen.dart';

/// Edit profile, behind the design's Edit button on the account header.
///
/// Name and phone only. The email address is shown here but changed on its
/// own screen, because doing so needs the current password and replaces the
/// session — not something to bury among two optional text fields.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  static const routePath = 'edit';
  static const routeName = 'edit-profile';

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;

  bool _busy = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    // Seeded from the session rather than fetched: it was written by the last
    // `/me` or sign-in, so the form opens filled instead of empty-then-filled.
    final user = ref.read(currentSessionProvider)?.user;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    setState(() => _busy = true);
    try {
      final updated = await ref.read(profileRepositoryProvider).update(
            firstName: _firstName.text,
            lastName: _lastName.text,
            phone: _phone.text,
          );

      // The session carries the customer's details, so without this the
      // account header keeps showing the old name until the next sign-in.
      // `updateSession` persists it too, so the change survives a restart.
      await ref
          .read(authControllerProvider.notifier)
          .updateSession(session.copyWith(user: updated));

      if (!mounted) return;
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
    final email = ref.watch(currentSessionProvider)?.user.email ?? '';

    return AuthShell(
      title: 'Edit profile',
      subtitle: 'Your name is used on your orders and receipts.',
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
              : const Text('Save changes'),
        ),
      ),
      children: [
        if (_error case final error?) ...[
          AuthErrorBanner(error: error),
          const SizedBox(height: AppTokens.space16),
        ],
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthField(
                label: 'First name',
                controller: _firstName,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                validator: (value) =>
                    AuthValidation.name(value, field: 'first name'),
              ),
              const SizedBox(height: AppTokens.space16),
              AuthField(
                label: 'Last name',
                controller: _lastName,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                validator: (value) =>
                    AuthValidation.name(value, field: 'last name'),
              ),
              const SizedBox(height: AppTokens.space16),
              AuthField(
                label: 'Phone',
                controller: _phone,
                enabled: !_busy,
                hint: 'Optional',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: AuthValidation.optionalPhone,
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space20),
        _EmailNote(email: email),
      ],
    );
  }
}

/// The address, and the way to change it.
class _EmailNote extends ConsumerWidget {
  const _EmailNote({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    if (email.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTokens.space14),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mail_outline_rounded, size: 18, color: palette.muted),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: text.bodyMedium),
                const SizedBox(height: AppTokens.space2),
                Text(
                  'Changing this needs your password.',
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.pushNamed(ChangeEmailScreen.routeName),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}
