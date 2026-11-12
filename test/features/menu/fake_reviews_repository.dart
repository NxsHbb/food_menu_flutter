import 'package:food_menu/src/core/network/paged.dart';
import 'package:food_menu/src/features/menu/data/reviews_repository.dart';
import 'package:food_menu/src/features/menu/domain/review.dart';

Review buildReview({
  int id = 1,
  String reviewer = 'Ayesha R.',
  String review = 'Best in the city.',
  int? rating = 5,
  bool verified = false,
  String formattedDate = 'November 10, 2026',
  String? avatarUrl,
}) {
  return Review(
    id: id,
    reviewer: reviewer,
    review: review,
    rating: rating,
    verified: verified,
    formattedDate: formattedDate,
    avatarUrl: avatarUrl,
  );
}

/// Stands in for `wc/store/v1/products/reviews` and the write route.
class FakeReviewsRepository implements ReviewsRepository {
  FakeReviewsRepository({
    List<Review>? stored,
    this.total,
    this.perPageOverride,
  }) : stored = stored ?? const [];

  /// Every review the fake store holds, paged out of this list.
  List<Review> stored;

  /// Reported as `X-WP-Total`. Defaults to [reviews]'s length, and is
  /// settable so a test can claim more pages than it supplies.
  int? total;

  final int? perPageOverride;

  /// Every call made, as `'reviews 7 page 2'` or `'leave 7 5'`.
  final List<String> calls = [];

  /// Thrown by the next call of any kind, then cleared.
  Object? failNext;

  /// What [leave] answers with.
  ReviewOutcome outcome = const ReviewOutcome(
    id: 99,
    pending: false,
    message: 'Thanks for your review.',
  );

  void _tick() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<Paged<Review>> reviews({
    required int productId,
    int page = 1,
    int perPage = 10,
  }) async {
    calls.add('reviews $productId page $page');
    _tick();

    final size = perPageOverride ?? perPage;
    final start = (page - 1) * size;
    final items = start >= stored.length
        ? const <Review>[]
        : stored.skip(start).take(size).toList(growable: false);

    final count = total ?? stored.length;
    final pages = count == 0 ? 0 : (count / size).ceil();

    return Paged(items: items, total: count, totalPages: pages, page: page);
  }

  @override
  Future<ReviewOutcome> leave({
    required int productId,
    required String review,
    int? rating,
  }) async {
    calls.add('leave $productId ${rating ?? '-'} $review');
    _tick();
    return outcome;
  }
}
