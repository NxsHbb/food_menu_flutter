import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../data/reviews_controller.dart';
import '../../domain/review.dart';
import 'review_sheet.dart';
import 'star_rating.dart';

/// What other customers said about a dish, and a way to add to it.
///
/// **Drawn only when the store wants reviews at all** — the caller checks
/// `product.sections.reviews`, which combines the store's `hide_options` with
/// `comments_open()` on the dish (task 10.1).
///
/// The design has no reviews list and no review form, so both are drawn from
/// the app's own vocabulary — the same call made for the address screens
/// (3.9) and the auth screens (3.11).
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({required this.product, super.key});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final palette = AppPalette.of(context);
    final state = ref.watch(reviewsControllerProvider(product.id));
    final canWrite = product.reviewPolicy.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                state.value?.total != null && state.value!.total > 0
                    ? 'Reviews (${state.value!.total})'
                    : 'Reviews',
                style: text.titleMedium,
              ),
            ),
            if (canWrite)
              TextButton(
                onPressed: () => _write(context, ref),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('Write a review'),
              ),
          ],
        ),
        // The store's condition, stated as a condition. Whether this customer
        // meets it has a per-customer answer the product payload cannot carry,
        // so it is not claimed either way — the refusal says.
        if (canWrite && product.reviewPolicy.verificationRequired) ...[
          const SizedBox(height: AppTokens.space4),
          Text(
            'Only customers who have ordered this dish can review it.',
            style: text.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
        const SizedBox(height: AppTokens.space10),
        switch (state) {
          AsyncValue(hasError: true) => _Message(
              text: 'Reviews could not be loaded.',
              onRetry: () =>
                  ref.invalidate(reviewsControllerProvider(product.id)),
            ),
          AsyncValue(:final value?) when value.reviews.isEmpty => _Message(
              text: canWrite
                  ? 'No reviews yet. Be the first.'
                  : 'No reviews yet.',
            ),
          AsyncValue(:final value?) => _ReviewList(
              state: value,
              onMore: () => ref
                  .read(reviewsControllerProvider(product.id).notifier)
                  .loadMore(),
            ),
          // First load. A short bar rather than a spinner: this sits at the
          // bottom of a long screen and a spinner there reads as the screen
          // still arriving.
          _ => const _Message(text: 'Loading reviews…'),
        },
      ],
    );
  }

  Future<void> _write(BuildContext context, WidgetRef ref) async {
    if (!ref.read(isSignedInProvider)) {
      await context.pushNamed(LoginScreen.routeName);
      return;
    }

    final outcome = await showReviewSheet(
      context,
      product: product,
      policy: product.reviewPolicy,
    );

    if (outcome == null || !context.mounted) return;

    // **Only an approved review reloads the list.** A pending one is invisible
    // to the read endpoint by definition, so re-reading would show the
    // customer their review missing from the list they were just told it
    // would join.
    if (!outcome.pending) {
      await ref.read(reviewsControllerProvider(product.id).notifier).reload();
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(outcome.message)),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.state, required this.onMore});

  final ReviewsState state;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final review in state.reviews) ...[
          _ReviewTile(review: review),
          const SizedBox(height: AppTokens.space12),
        ],
        if (state.hasMore)
          TextButton(
            onPressed: state.loadingMore ? null : onMore,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(
              state.loadingMore
                  ? 'Loading…'
                  : 'Show more (${state.total - state.reviews.length})',
            ),
          ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      ),
      padding: const EdgeInsets.all(AppTokens.space14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.reviewer.isEmpty ? 'Customer' : review.reviewer,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (review.hasRating)
                StarRating(rating: review.rating!.toDouble(), size: 14),
            ],
          ),
          if (review.formattedDate.isNotEmpty || review.verified) ...[
            const SizedBox(height: AppTokens.space2),
            Row(
              children: [
                if (review.formattedDate.isNotEmpty)
                  Text(
                    review.formattedDate,
                    style: text.bodySmall?.copyWith(color: palette.muted),
                  ),
                if (review.formattedDate.isNotEmpty && review.verified)
                  Text(
                    ' · ',
                    style: text.bodySmall?.copyWith(color: palette.muted),
                  ),
                // The store's own distinction, worth keeping: it is the only
                // thing on the tile that says the reviewer actually ate it.
                if (review.verified)
                  Text(
                    'Verified order',
                    style: text.bodySmall?.copyWith(color: palette.okForeground),
                  ),
              ],
            ),
          ],
          if (review.review.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space8),
            Text(
              review.review,
              style: text.bodyMedium?.copyWith(color: palette.muted2),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(text, style: theme.bodyMedium?.copyWith(color: palette.muted)),
        if (onRetry case final retry?)
          TextButton(
            onPressed: retry,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Try again'),
          ),
      ],
    );
  }
}
