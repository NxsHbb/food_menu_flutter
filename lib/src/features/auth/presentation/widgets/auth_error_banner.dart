import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// Shows whatever went wrong with a submission, above the form's button.
///
/// The server's own messages are shown verbatim where it sent one: the
/// plugin's auth errors are written for customers ("That email address and
/// password do not match an account"), so paraphrasing them here would only
/// make them vaguer.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.error, this.onRetry, super.key});

  final ApiException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final retryable = error.isRetryable && onRetry != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: palette.brand),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  _message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: palette.ink),
                ),
              ),
            ],
          ),
          if (retryable)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.space4),
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }

  /// The server's message, with one addition: a rate limit tells the customer
  /// how long to wait, which the generic message cannot.
  String get _message {
    if (error.statusCode == 429) {
      final wait = error.retryAfter;
      if (wait != null) {
        return '${error.message} Try again in ${_humanise(wait)}.';
      }
    }
    return error.message;
  }

  static String _humanise(Duration wait) {
    if (wait.inMinutes >= 2) return '${wait.inMinutes} minutes';
    if (wait.inSeconds > 60) return 'a minute';
    return '${wait.inSeconds} seconds';
  }
}
