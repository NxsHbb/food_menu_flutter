import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/promo_banner.dart';

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

/// Banners for the landing screen.
///
/// Failures resolve to an empty list rather than an error: a banner is
/// decoration, and a down posts endpoint must not take the menu with it.
final bannersProvider = FutureProvider<List<PromoBanner>>((ref) async {
  try {
    return await ref.watch(bannerRepositoryProvider).banners();
  } catch (_) {
    return const [];
  }
});
