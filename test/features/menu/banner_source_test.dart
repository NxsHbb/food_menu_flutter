import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/menu/data/banner_repository.dart';
import 'package:food_menu/src/features/menu/domain/promo_banner.dart';
import 'package:food_menu/src/features/menu/domain/special_menu.dart';

import 'fake_banner_repository.dart';

/// Which source wins, and what happens when one of them is missing.
void main() {
  const post = PromoBanner(
    id: 7,
    title: 'From a WordPress post',
    subtitle: 'edited in WordPress',
  );

  const special = SpecialMenu(
    active: true,
    title: 'Weekend Specials',
    offer: '20% off',
    duration: 'Friday to Sunday only',
    dishes: [SpecialMenuDish(id: 18, name: 'Double Smash')],
  );

  Future<List<PromoBanner>> bannersFrom(FakeBannerRepository repo) async {
    final container = ProviderContainer(
      overrides: [bannerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    return container.read(bannersProvider.future);
  }

  test('the store\'s own promotion wins over its banner posts', () async {
    final banners = await bannersFrom(
      FakeBannerRepository(bannerList: const [post], special: special),
    );

    expect(banners.single.title, 'Double Smash');
    expect(banners.single.productId, 18);
  });

  test('posts still run the carousel when no promotion is on', () async {
    final banners = await bannersFrom(
      FakeBannerRepository(bannerList: const [post]),
    );

    expect(banners.single.title, 'From a WordPress post');
    expect(banners.single.productId, isNull);
  });

  test('an older plugin has no such route, and keeps its posts', () async {
    // A 404 on `/app/special-menu` must not cost a store the carousel it
    // already had.
    final banners = await bannersFrom(
      FakeBannerRepository(
        bannerList: const [post],
        specialError: Exception('404'),
      ),
    );

    expect(banners.single.title, 'From a WordPress post');
  });

  test('neither source is not an error, just no carousel', () async {
    final banners = await bannersFrom(
      FakeBannerRepository(error: Exception('posts are down')),
    );

    expect(banners, isEmpty);
  });

  test('a promotion whose dishes were all filtered out falls back', () async {
    // Every dish unserved at this branch, so the promotion is running but has
    // nothing to show here.
    final banners = await bannersFrom(
      FakeBannerRepository(
        bannerList: const [post],
        special: const SpecialMenu(
          active: true,
          title: 'Weekend Specials',
          offer: '20% off',
          duration: '',
          dishes: [],
        ),
      ),
    );

    expect(banners.single.title, 'From a WordPress post');
  });
}
