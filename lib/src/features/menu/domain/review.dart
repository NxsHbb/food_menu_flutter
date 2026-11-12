import '../../../core/util/html_text.dart';

/// One approved review of one dish, as `wc/store/v1/products/reviews` sends it.
///
/// The store composes the date (`formatted_date_created`) in its own format,
/// so the app never formats one itself — same rule as every other date that
/// arrives already worded.
class Review {
  const Review({
    required this.id,
    required this.reviewer,
    required this.review,
    required this.rating,
    required this.verified,
    required this.formattedDate,
    required this.avatarUrl,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reviewer: plainText(json['reviewer'] as String? ?? ''),
      // Reviews arrive as HTML, wrapped in `<p>` by WordPress.
      review: plainText(json['review'] as String? ?? ''),
      // Null on a review left while the store had ratings switched off, which
      // is a review with no stars rather than a zero-star one.
      rating: (json['rating'] as num?)?.toInt(),
      verified: json['verified'] as bool? ?? false,
      formattedDate: json['formatted_date_created'] as String? ?? '',
      avatarUrl: _avatar(json['reviewer_avatar_urls']),
    );
  }

  /// The largest avatar the store offers, or null.
  ///
  /// Sent as a map keyed by pixel size — `{"48": "…", "96": "…"}` — so the
  /// biggest key wins rather than a hard-coded one, which would break on a
  /// store whose sizes differ.
  static String? _avatar(Object? raw) {
    if (raw is! Map) return null;

    final sizes = <int, String>{};
    raw.forEach((key, value) {
      final size = int.tryParse(key.toString());
      if (size != null && value is String && value.isNotEmpty) {
        sizes[size] = value;
      }
    });

    if (sizes.isEmpty) return null;

    final largest = sizes.keys.reduce((a, b) => a > b ? a : b);
    return sizes[largest];
  }

  final int id;
  final String reviewer;
  final String review;

  /// Null when the review carries no rating at all.
  final int? rating;

  /// Whether the store could match this reviewer to an order for the dish.
  final bool verified;

  /// Already worded by the store, in its own `date_format`.
  final String formattedDate;

  final String? avatarUrl;

  bool get hasRating => rating != null && rating! > 0;
}

/// What the store's settings let a customer do about reviews.
///
/// **Store-level only.** Whether *this* customer qualifies under
/// [verificationRequired] has a per-customer answer, and the product payload
/// this comes from is public and cacheable. So the app states the store's
/// condition and learns whether the customer meets it from the refusal the
/// write route gives it — the same shape as task 8.7's ordering gate.
class ReviewPolicy {
  const ReviewPolicy({
    required this.enabled,
    required this.ratingEnabled,
    required this.ratingRequired,
    required this.verificationRequired,
  });

  /// What a site that says nothing allows: reviews with a required rating,
  /// which is WooCommerce's own default.
  static const unknown = ReviewPolicy(
    enabled: true,
    ratingEnabled: true,
    ratingRequired: true,
    verificationRequired: false,
  );

  factory ReviewPolicy.fromExtension(Map<String, dynamic> json) {
    final extensions = json['extensions'];
    if (extensions is! Map) return unknown;

    final foodMenu = extensions['food-menu-pro'];
    if (foodMenu is! Map) return unknown;

    final reviews = foodMenu['reviews'];
    if (reviews is! Map) return unknown;

    return ReviewPolicy(
      enabled: reviews['enabled'] != false,
      ratingEnabled: reviews['rating_enabled'] != false,
      ratingRequired: reviews['rating_required'] != false,
      verificationRequired: reviews['verification_required'] == true,
    );
  }

  final bool enabled;
  final bool ratingEnabled;
  final bool ratingRequired;

  /// Only customers who ordered the dish may review it.
  final bool verificationRequired;
}

/// What came back from leaving a review.
///
/// **[pending] is the field that matters.** A store with `comment_moderation`
/// on, or a customer with no approved comment yet under
/// `comment_previously_approved`, gets a review that is saved and invisible.
/// Showing it in the list anyway would tell the customer it is public when it
/// is not; showing nothing would look like the app had lost it.
class ReviewOutcome {
  const ReviewOutcome({
    required this.id,
    required this.pending,
    required this.message,
  });

  factory ReviewOutcome.fromJson(Map<String, dynamic> json) {
    return ReviewOutcome(
      id: (json['id'] as num?)?.toInt() ?? 0,
      pending: json['status'] != 'approved',
      // The store's own sentence, which says which of the two happened.
      message: plainText(json['message'] as String? ?? ''),
    );
  }

  final int id;
  final bool pending;
  final String message;
}
