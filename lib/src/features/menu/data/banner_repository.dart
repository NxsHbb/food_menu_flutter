import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../branch/data/branch_controller.dart';
import '../domain/promo_banner.dart';
import '../domain/special_menu.dart';

/// Reads landing-screen banners from WordPress posts.
///
/// The category is resolved **by slug**, never by id: term ids differ between
/// the dev site and production, so a hard-coded id would silently return
/// nothing live.
class BannerRepository {
  const BannerRepository(this._client, {this.categorySlug = 'app-banners'});

  final ApiClient _client;

  /// The category holding banner posts.
  final String categorySlug;

  Future<List<PromoBanner>> banners({int limit = 6}) async {
    final categoryId = await _categoryId();
    // No category, or one nobody has published into, is a normal state — the
    // carousel simply does not appear.
    if (categoryId == null) return const [];

    final raw = await _client.get<List<dynamic>>(
      _client.wpApi('posts'),
      query: {
        'categories': categoryId,
        'per_page': limit,
        'orderby': 'date',
        'order': 'desc',
        // One request instead of one per banner for artwork and tags.
        '_embed': 'wp:featuredmedia,wp:term',
      },
    );

    return raw
        .whereType<Map>()
        .map((e) => PromoBanner.fromJson(e.cast<String, dynamic>()))
        .where((b) => b.isRenderable)
        .toList(growable: false);
  }

  /// The store's own Special Menu (task 9.5).
  ///
  /// A plugin route, because this is plugin data: a scheduled promotion with
  /// chosen dishes. It answers `active: false` rather than 404 when nothing
  /// is running, so there is no error path for the ordinary case.
  Future<SpecialMenu> specialMenu({int branch = 0}) async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/special-menu'),
      query: branch > 0 ? {'branch': branch} : null,
    );

    return SpecialMenu.fromJson(raw);
  }

  Future<int?> _categoryId() async {
    final raw = await _client.get<List<dynamic>>(
      _client.wpApi('categories'),
      query: {'slug': categorySlug, 'per_page': 1},
    );
    if (raw.isEmpty) return null;
    final first = raw.first;
    if (first is! Map) return null;
    return (first['id'] as num?)?.toInt();
  }
}

final bannerRepositoryProvider = Provider<BannerRepository>((ref) {
  return BannerRepository(ref.watch(apiClientProvider));
});

/// The store's own promotion, or [SpecialMenu.none].
///
/// Failures resolve to "no promotion" for the same reason banners do, and for
/// one more: a store running an **older plugin** has no such route, and a 404
/// there must not cost it the carousel it already had.
final specialMenuProvider = FutureProvider<SpecialMenu>((ref) async {
  try {
    return await ref.watch(bannerRepositoryProvider).specialMenu(
          branch: ref.watch(activeBranchIdProvider) ?? 0,
        );
  } catch (_) {
    return SpecialMenu.none;
  }
});

/// Banners for the landing screen.
///
/// **The Special Menu wins when a store is running one** (task 9.5). It is
/// the plugin's own promotion — chosen dishes, offer text, a schedule that
/// expires itself — and every banner it makes has a dish to open. WordPress
/// posts stay as the fallback: task 2.5 built them, stores may already have
/// published into that category, and a post is still the only way to run a
/// banner that is not about one dish.
///
/// Failures resolve to an empty list rather than an error: a banner is
/// decoration, and a down posts endpoint must not take the menu with it.
final bannersProvider = FutureProvider<List<PromoBanner>>((ref) async {
  final special = await ref.watch(specialMenuProvider.future);

  if (special.active) {
    final banners = special.banners;
    if (banners.isNotEmpty) return banners;
  }

  try {
    return await ref.watch(bannerRepositoryProvider).banners();
  } catch (_) {
    return const [];
  }
});
