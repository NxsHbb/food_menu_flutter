import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/store_api/models/product.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/menu/data/reviews_repository.dart';
import 'package:food_menu/src/features/menu/domain/review.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/review_sheet.dart';

import 'fake_reviews_repository.dart';

void main() {
  Product dish() => Product.fromJson({
        'id': 7,
        'name': 'Tiramisu',
        'prices': const {'price': '650', 'currency_minor_unit': 2},
      });

  Future<ReviewOutcome?> pumpSheet(
    WidgetTester tester, {
    required FakeReviewsRepository reviews,
    ReviewPolicy policy = ReviewPolicy.unknown,
  }) async {
    ReviewOutcome? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewsRepositoryProvider.overrideWithValue(reviews),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showReviewSheet(
                      context,
                      product: dish(),
                      policy: policy,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    return result;
  }

  testWidgets('sends the stars and the words', (tester) async {
    final reviews = FakeReviewsRepository();
    await pumpSheet(tester, reviews: reviews);

    await tester.tap(find.byTooltip('4 stars'));
    await tester.enterText(find.byType(TextField), 'Very good.');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(reviews.calls, contains('leave 7 4 Very good.'));
    // The sheet closes on success, carrying the outcome back.
    expect(find.text('Submit review'), findsNothing);
  });

  testWidgets('will not send without the rating the store requires',
      (tester) async {
    final reviews = FakeReviewsRepository();
    await pumpSheet(tester, reviews: reviews);

    await tester.enterText(find.byType(TextField), 'Words but no stars.');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    // **Exactly one.** `findsWidgets` let the same sentence be printed twice
    // — once as the field's error and once in the banner — which a device
    // pass caught and this test did not.
    expect(find.text('Please rate the dish from 1 to 5.'), findsOneWidget);
    // And under the stars, not under the text box: that is where it is fixed.
    expect(find.text('Please write your review.'), findsNothing);
    // Not sent: the payload already said the rating is required, so making
    // the customer wait for a round trip to hear it is wasted.
    expect(reviews.calls, isEmpty);
  });

  testWidgets('will not send empty words', (tester) async {
    final reviews = FakeReviewsRepository();
    await pumpSheet(tester, reviews: reviews);

    await tester.tap(find.byTooltip('5 stars'));
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(find.text('Please write your review.'), findsOneWidget);
    expect(reviews.calls, isEmpty);
  });

  testWidgets('both problems are reported once each, in their own places',
      (tester) async {
    // Submitting a blank form: one message under the stars, one under the
    // text box, and nothing in the banner — the banner is the server's.
    final reviews = FakeReviewsRepository();
    await pumpSheet(tester, reviews: reviews);

    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(find.text('Please write your review.'), findsOneWidget);
    expect(find.text('Please rate the dish from 1 to 5.'), findsOneWidget);
    expect(reviews.calls, isEmpty);
  });

  testWidgets('a store with ratings off is not asked for stars',
      (tester) async {
    final reviews = FakeReviewsRepository();
    await pumpSheet(
      tester,
      reviews: reviews,
      policy: const ReviewPolicy(
        enabled: true,
        ratingEnabled: false,
        ratingRequired: false,
        verificationRequired: false,
      ),
    );

    expect(find.byTooltip('5 stars'), findsNothing);

    await tester.enterText(find.byType(TextField), 'No stars here.');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    // Sent with no rating rather than a zero, which the route would ignore
    // anyway — but a zero in the payload is a claim the app should not make.
    expect(reviews.calls, contains('leave 7 - No stars here.'));
  });

  testWidgets('an optional rating can be skipped', (tester) async {
    final reviews = FakeReviewsRepository();
    await pumpSheet(
      tester,
      reviews: reviews,
      policy: const ReviewPolicy(
        enabled: true,
        ratingEnabled: true,
        ratingRequired: false,
        verificationRequired: false,
      ),
    );

    expect(find.text('Your rating (optional)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Fine, no stars.');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(reviews.calls, contains('leave 7 - Fine, no stars.'));
  });

  testWidgets('the store\'s own refusal is shown as the store worded it',
      (tester) async {
    final reviews = FakeReviewsRepository()
      ..failNext = const ApiException(
        failure: ApiFailure.http,
        statusCode: 403,
        code: 'fmp_review_not_verified',
        message: 'Only customers who have ordered this dish can review it.',
      );
    await pumpSheet(tester, reviews: reviews);

    await tester.tap(find.byTooltip('5 stars'));
    await tester.enterText(find.byType(TextField), 'Let me in.');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(
      find.text('Only customers who have ordered this dish can review it.'),
      findsOneWidget,
    );
    // Still open, with the words still in it.
    expect(find.text('Submit review'), findsOneWidget);
    expect(find.text('Let me in.'), findsOneWidget);
  });

  testWidgets('a dropped connection gets our wording, not the server\'s',
      (tester) async {
    final reviews = FakeReviewsRepository()
      ..failNext = const ApiException(
        failure: ApiFailure.network,
        message: 'Connection closed',
      );
    await pumpSheet(tester, reviews: reviews);

    await tester.tap(find.byTooltip('5 stars'));
    await tester.enterText(find.byType(TextField), 'Offline.');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your review could not be sent. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('renders in dark mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewsRepositoryProvider.overrideWithValue(FakeReviewsRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ReviewSheet(product: dish(), policy: ReviewPolicy.unknown),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Write a review'), findsOneWidget);
  });
}
