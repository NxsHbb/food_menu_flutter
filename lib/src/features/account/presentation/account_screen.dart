import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';

/// Account tab.
///
/// Intentionally minimal: this exists so the auth flow from task 3.3 is
/// reachable and its result visible. The design's full account screen — the
/// row list, Edit profile, Saved addresses — is task 3.7.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const routePath = '/account';
  static const routeName = 'account';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space16),
          child: session == null
              ? _SignedOut(
                  onSignIn: () => context.pushNamed(LoginScreen.routeName),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: palette.tint,
                          child: Text(
                            session.user.initials,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: palette.brand),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.user.greetingName,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                session.user.email,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      height: AppTokens.buttonHeight,
                      child: OutlinedButton(
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).logout(),
                        child: const Text('Log out'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 48, color: palette.muted),
          const SizedBox(height: AppTokens.space12),
          Text('Your account', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTokens.space6),
          Text(
            'Sign in to place an order, track it and keep your favourites.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppTokens.space20),
          SizedBox(
            height: AppTokens.buttonHeight,
            child: FilledButton(
              onPressed: onSignIn,
              child: const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}
