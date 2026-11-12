import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/product.dart';
import 'package:food_menu/src/features/menu/domain/review.dart';

void main() {
  group('Review', () {
    test('reads what the Store API sends', () {
      final review = Review.fromJson(const {
        'id': 42,
        'reviewer': 'Ayesha R.',
        'review': '<p>Best in the city.</p>\n',
        'rating': 5,
        'verified': true,
        'formatted_date_created': 'November 10, 2026',
        'reviewer_avatar_urls': {'24': 'a.png', '96': 'c.png', '48': 'b.png'},
      });

      expect(review.id, 42);
      expect(review.reviewer, 'Ayesha R.');
      // Through plainText: WordPress wraps review bodies in a paragraph.
      expect(review.review, 'Best in the city.');
      expect(review.rating, 5);
      expect(review.hasRating, isTrue);
      expect(review.verified, isTrue);
      expect(review.formattedDate, 'November 10, 2026');
      // The largest size wins, not the first key.
      expect(review.avatarUrl, 'c.png');
    });

    test('decodes entities in a reviewer name', () {
      final review = Review.fromJson(const {
        'id': 1,
        'reviewer': 'Chef&#8217;s friend',
        'review': 'Good.',
      });

      expect(review.reviewer, 'Chef’s friend');
    });

    test('a review left with no rating has none rather than zero', () {
      // A store with ratings switched off collects a review and no stars, and
      // zero stars is a different claim from no stars.
      final review = Review.fromJson(const {
        'id': 1,
        'reviewer': 'Tom B.',
        'review': 'Fine.',
      });

      expect(review.rating, isNull);
      expect(review.hasRating, isFalse);
    });

    test('no avatar map means no avatar', () {
      final review = Review.fromJson(const {'id': 1, 'review': 'Fine.'});

      expect(review.avatarUrl, isNull);
      expect(review.reviewer, isEmpty);
    });
  });

  group('ReviewPolicy', () {
    test('a plugin that sends no policy allows a rated review', () {
      // WooCommerce's own defaults, so a store on an older plugin keeps the
      // behaviour it had rather than losing the form.
      final product = Product.fromJson({
        'id': 7,
        'name': 'Tiramisu',
        'prices': const {'price': '650', 'currency_minor_unit': 2},
      });

      expect(product.reviewPolicy.enabled, isTrue);
      expect(product.reviewPolicy.ratingEnabled, isTrue);
      expect(product.reviewPolicy.ratingRequired, isTrue);
      expect(product.reviewPolicy.verificationRequired, isFalse);
    });

    test('reads the store settings off the extension', () {
      final product = Product.fromJson({
        'id': 7,
        'name': 'Tiramisu',
        'prices': const {'price': '650', 'currency_minor_unit': 2},
        'extensions': const {
          'food-menu-pro': {
            'reviews': {
              'enabled': true,
              'rating_enabled': false,
              'rating_required': false,
              'verification_required': true,
            },
          },
        },
      });

      expect(product.reviewPolicy.enabled, isTrue);
      expect(product.reviewPolicy.ratingEnabled, isFalse);
      expect(product.reviewPolicy.ratingRequired, isFalse);
      expect(product.reviewPolicy.verificationRequired, isTrue);
    });

    test('a store that takes no reviews says so', () {
      final product = Product.fromJson({
        'id': 7,
        'name': 'Tiramisu',
        'prices': const {'price': '650', 'currency_minor_unit': 2},
        'extensions': const {
          'food-menu-pro': {
            'reviews': {'enabled': false},
          },
        },
      });

      expect(product.reviewPolicy.enabled, isFalse);
    });
  });

  group('ReviewOutcome', () {
    test('an approved review is not pending', () {
      final outcome = ReviewOutcome.fromJson(const {
        'id': 12,
        'status': 'approved',
        'message': 'Thanks for your review.',
      });

      expect(outcome.id, 12);
      expect(outcome.pending, isFalse);
      expect(outcome.message, 'Thanks for your review.');
    });

    test('anything but approved is pending', () {
      // Including a status the server has not invented yet: showing a review
      // as public when it is held is the worse of the two mistakes.
      expect(
        ReviewOutcome.fromJson(const {'id': 1, 'status': 'pending'}).pending,
        isTrue,
      );
      expect(ReviewOutcome.fromJson(const {'id': 1}).pending, isTrue);
      expect(
        ReviewOutcome.fromJson(const {'id': 1, 'status': 'spam'}).pending,
        isTrue,
      );
    });
  });
}
