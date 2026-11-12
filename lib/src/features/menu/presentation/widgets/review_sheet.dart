import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/html_text.dart';
import '../../data/reviews_repository.dart';
import '../../domain/review.dart';
import 'star_rating.dart';

/// Opens the review form. Returns the outcome, or null if it was dismissed.
Future<ReviewOutcome?> showReviewSheet(
  BuildContext context, {
  required Product product,
  required ReviewPolicy policy,
}) {
  return showModalBottomSheet<ReviewOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // The root navigator, as every other sheet here: the dish screen is
    // pushed outside the tab shell.
    useRootNavigator: true,
    builder: (_) => ReviewSheet(product: product, policy: policy),
  );
}

/// Leaving a review: the stars the store collects, and the words.
///
/// Not in the design, which has no review form — drawn from the app's own
/// vocabulary, like the address and auth screens before it.
class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({
    required this.product,
    required this.policy,
    super.key,
  });

  final Product product;
  final ReviewPolicy policy;

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  final _controller = TextEditingController();
  int _rating = 0;
  bool _sending = false;
  String? _error;
  bool _showErrors = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The store's own two rules, checked here so the customer is not made to
  /// wait for a round trip to be told what the payload already said.
  String? get _localProblem {
    if (_controller.text.trim().isEmpty) return 'Please write your review.';

    if (widget.policy.ratingEnabled &&
        widget.policy.ratingRequired &&
        _rating < 1) {
      return 'Please rate the dish from 1 to 5.';
    }

    return null;
  }

  Future<void> _send() async {
    final problem = _localProblem;

    if (problem != null) {
      setState(() {
        _showErrors = true;
        _error = problem;
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final outcome = await ref.read(reviewsRepositoryProvider).leave(
            productId: widget.product.id,
            review: _controller.text.trim(),
            // Null, not zero, when nothing was chosen. The repository omits
            // it either way, but "no rating" and "a rating of zero" are
            // different claims and the call should read as the first.
            rating: widget.policy.ratingEnabled && _rating > 0 ? _rating : null,
          );

      if (!mounted) return;
      Navigator.of(context).pop(outcome);
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _sending = false;
        _error = _message(error);
      });
    }
  }

  /// The server's own sentence wherever it is about the store's rules, ours
  /// only where the server's would read as an app fault.
  ///
  /// `fmp_review_not_verified`, `fmp_reviews_closed`,
  /// `fmp_reviews_disabled` and `fmp_review_rating_required` all name the
  /// store's policy in the store's language, so they are passed through.
  String _message(ApiException error) {
    final code = error.code ?? '';

    if (code.startsWith('fmp_review')) return plainText(error.message);

    return switch (error.statusCode) {
      401 => 'Please sign in again to leave a review.',
      404 => 'That dish is no longer on the menu.',
      _ => 'Your review could not be sent. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // Above the keyboard, which this sheet always raises.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.space16,
                    AppTokens.space12,
                    AppTokens.space8,
                    AppTokens.space8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Write a review',
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.space16,
                    0,
                    AppTokens.space16,
                    AppTokens.space16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plainText(widget.product.name),
                        style: text.bodyMedium?.copyWith(color: palette.muted),
                      ),
                      // **No stars where the store collects none.** A rating
                      // sent to a store with `enable_review_rating` off is
                      // ignored by the route, so offering it would be asking
                      // for something that goes nowhere.
                      if (widget.policy.ratingEnabled) ...[
                        const SizedBox(height: AppTokens.space16),
                        Text(
                          widget.policy.ratingRequired
                              ? 'Your rating'
                              : 'Your rating (optional)',
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppTokens.space4),
                        StarPicker(
                          rating: _rating,
                          onChanged: (value) => setState(() => _rating = value),
                        ),
                      ],
                      const SizedBox(height: AppTokens.space16),
                      TextField(
                        controller: _controller,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (_showErrors) setState(() => _error = null);
                        },
                        decoration: InputDecoration(
                          hintText: 'What did you think of it?',
                          errorText: _showErrors ? _localProblem : null,
                        ),
                      ),
                      if (_error case final message?) ...[
                        const SizedBox(height: AppTokens.space8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTokens.space12),
                          decoration: BoxDecoration(
                            color: palette.warnBackground,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusControl),
                          ),
                          child: Text(
                            message,
                            style: text.bodySmall
                                ?.copyWith(color: palette.warnForeground),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTokens.space16),
                      FilledButton(
                        onPressed: _sending ? null : _send,
                        child: Text(_sending ? 'Sending…' : 'Submit review'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
