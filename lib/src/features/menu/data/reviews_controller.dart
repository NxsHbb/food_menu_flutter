import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/review.dart';
import 'reviews_repository.dart';

/// The reviews on screen for one dish, and whether there are more.
class ReviewsState {
  const ReviewsState({
    this.reviews = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<Review> reviews;

  /// Across all pages, from `X-WP-Total` — so "12 reviews" is right while
  /// only three are loaded.
  final int total;

  final int page;
  final bool hasMore;
  final bool loadingMore;

  ReviewsState copyWith({
    List<Review>? reviews,
    int? total,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return ReviewsState(
      reviews: reviews ?? this.reviews,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Loads and accumulates pages of reviews for one dish.
///
/// Keyed by product id, so two dish screens in a back stack keep their own
/// lists. Three at a time: the dish screen is already long, and the design
/// has no reviews screen to send the rest to.
class ReviewsController extends AsyncNotifier<ReviewsState> {
  ReviewsController(this.productId);

  static const pageSize = 3;

  /// The family argument, taken as a constructor parameter — which is how
  /// Riverpod 3 passes it (`_createFn` is `NotifierT Function(ArgT)`).
  final int productId;

  @override
  Future<ReviewsState> build() async {
    final page = await ref.watch(reviewsRepositoryProvider).reviews(
          productId: productId,
          perPage: pageSize,
        );

    return ReviewsState(
      reviews: page.items,
      total: page.total,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  /// Appends the next page. A no-op while one is in flight or at the end.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final next = await ref.read(reviewsRepositoryProvider).reviews(
            productId: productId,
            page: current.page + 1,
            perPage: pageSize,
          );

      state = AsyncData(
        current.copyWith(
          reviews: [...current.reviews, ...next.items],
          total: next.total,
          page: next.page,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } on Object {
      // Keep what is on screen. A failed "show more" is worth a silent stop
      // rather than blanking reviews the customer is reading — unlike the
      // menu list, there is nothing below this to strand.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Re-reads the first page, after the customer has left a review.
  ///
  /// Called only for an **approved** review: a pending one is invisible to
  /// this endpoint by definition, so reloading would show the customer their
  /// review missing from a list they were just told it would join.
  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final reviewsControllerProvider =
    AsyncNotifierProvider.family<ReviewsController, ReviewsState, int>(
  ReviewsController.new,
  // No background retry, for the same reason as the menu list and the order
  // types: the section offers "Try again", and a retry firing on its own
  // would replace the error the customer is reading with another attempt.
  retry: (retryCount, error) => null,
);
