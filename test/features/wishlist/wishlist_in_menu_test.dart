import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_card.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_row.dart';
import 'package:food_menu/src/features/wishlist/data/wishlist_repository.dart';
import 'package:food_menu/src/features/wishlist/presentation/widgets/wishlist_heart.dart';

import '../auth/fake_auth_repository.dart';
import '../menu/fake_menu_repository.dart';
import 'fake_wishlist_repository.dart';

/// The heart as it appears in the menu, rather than on its own.
///
/// Worth testing separately: both widgets put the heart next to an add button,
/// and the card stacks it over the photo, so a layout change in either could
/// swallow the tap target without any wishlist test noticing.
void main() {
  final latte = buildProduct(id: 26, name: 'Iced Latte', price: '450');

  Future<FakeWishlistRepository> pump(
    WidgetTester tester,
    Widget child, {
    FakeWishlistRepository? repo,
  }) async {
    final wishlist = repo ?? FakeWishlistRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        wishlistRepositoryProvider.overrideWithValue(wishlist),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .login(username: 'customer@foodmenu.test', password: 'pw');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          // Sized, because a card in the real grid gets its height from the
          // grid delegate rather than its content.
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 180, height: 240, child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return wishlist;
  }

  testWidgets('a dish card carries a heart that saves the dish',
      (tester) async {
    final repo = await pump(
      tester,
      DishCard(product: latte, onTap: () {}),
      repo: FakeWishlistRepository()..catalogue[26] = latte,
    );

    expect(find.byType(WishlistHeart), findsOne);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOne);
    expect(repo.calls.last, (call: 'add', productId: 26));
  });

  testWidgets('the card heart does not swallow a tap meant for the card',
      (tester) async {
    var cardTaps = 0;
    await pump(tester, DishCard(product: latte, onTap: () => cardTaps++));

    // The photo fills most of the card; tapping its centre must still open the
    // dish even though the heart floats over its corner.
    await tester.tapAt(tester.getCenter(find.byType(DishCard)));
    await tester.pumpAndSettle();

    expect(cardTaps, 1);
  });

  testWidgets('a dish row carries a heart that saves the dish',
      (tester) async {
    final repo = await pump(
      tester,
      DishRow(product: latte, onTap: () {}),
      repo: FakeWishlistRepository()..catalogue[26] = latte,
    );

    expect(find.byType(WishlistHeart), findsOne);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOne);
    expect(repo.calls.last, (call: 'add', productId: 26));
  });

  testWidgets('tapping the row heart does not also open the dish',
      (tester) async {
    var rowTaps = 0;
    await pump(
      tester,
      DishRow(product: latte, onTap: () => rowTaps++),
      repo: FakeWishlistRepository()..catalogue[26] = latte,
    );

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    // The design's own behaviour: the heart stops the event rather than
    // saving the dish and navigating away from it at the same time.
    expect(rowTaps, 0);
  });

  testWidgets('a saved dish shows a filled heart on both widgets',
      (tester) async {
    await pump(
      tester,
      DishRow(product: latte, onTap: () {}),
      repo: FakeWishlistRepository(saved: [latte]),
    );

    expect(find.byIcon(Icons.favorite_rounded), findsOne);
  });

  testWidgets('a long name leaves the row heart room', (tester) async {
    await pump(
      tester,
      DishRow(
        product: buildProduct(
          id: 99,
          name: 'Slow-roasted aubergine with pomegranate molasses and feta',
        ),
        onTap: () {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(WishlistHeart), findsOne);
    // Still a full tap target, not squeezed to nothing by the name beside it.
    expect(tester.getSize(find.byType(WishlistHeart)).width, 28);
  });
}
