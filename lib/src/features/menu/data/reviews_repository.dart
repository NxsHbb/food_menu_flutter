import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import '../domain/review.dart';

/// Reads reviews from the Store API and writes them through the plugin.
///
/// **Two different backends, for one reason.** Reading is
/// `wc/store/v1/products/reviews`, which is public and returns only approved
/// reviews. Writing has no Store API route at all — the Store API's review
/// endpoint is registered `READABLE` and nothing else, and WooCommerce's own
/// `wc/v3/products/reviews` needs `edit_products`, a shop manager capability.
/// So the write goes to `fmp/v1/app/products/{id}/reviews`, built for this.
class ReviewsRepository {
  const ReviewsRepository(this._client);

  final ApiClient _client;

  /// One page of approved reviews for a dish, newest first.
  ///
  /// **`product_id` is a comma-separated *string*, not an array.** The route
  /// declares it `'type' => 'string'` with `wp_parse_id_list` as its
  /// sanitizer, so sending a JSON array fails `rest_validate_request_arg` and
  /// the whole request comes back 400 — which reads like a server fault and
  /// is not one. The plural in its description invites the wrong guess.
  Future<Paged<Review>> reviews({
    required int productId,
    int page = 1,
    int perPage = 10,
  }) async {
    final raw = await _client.getPaged(
      _client.storeApi('products/reviews'),
      page: page,
      query: {
        'product_id': '$productId',
        'per_page': perPage,
        'orderby': 'date_gmt',
        'order': 'desc',
      },
    );

    return Paged(
      items: raw.items.map(Review.fromJson).toList(growable: false),
      total: raw.total,
      totalPages: raw.totalPages,
      page: raw.page,
    );
  }

  /// Leaves a review as the signed-in customer.
  ///
  /// [rating] is omitted rather than sent as zero when the store has ratings
  /// switched off: the route ignores it in that case, and sending a number
  /// the website would never have collected is how a dish ends up with stars
  /// its store never asked for.
  Future<ReviewOutcome> leave({
    required int productId,
    required String review,
    int? rating,
  }) async {
    final raw = await _client.post<Map<String, dynamic>>(
      _client.foodMenuApi('app/products/$productId/reviews'),
      body: {
        'review': review,
        if (rating != null && rating > 0) 'rating': rating,
      },
    );

    return ReviewOutcome.fromJson(raw);
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(ref.watch(apiClientProvider));
});
