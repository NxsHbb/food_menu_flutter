import 'package:food_menu/src/features/menu/data/banner_repository.dart';
import 'package:food_menu/src/features/menu/domain/promo_banner.dart';

/// A [BannerRepository] answering from memory.
///
/// Screen tests override this even when they do not care about banners:
/// without it the landing screen reaches for the real posts endpoint, and
/// relying on the error fallback to paper over a live request makes the suite
/// slow and dependent on the environment.
class FakeBannerRepository implements BannerRepository {
  FakeBannerRepository({this.bannerList = const [], this.error});

  final List<PromoBanner> bannerList;
  final Object? error;

  @override
  String get categorySlug => 'app-banners';

  @override
  Future<List<PromoBanner>> banners({int limit = 6}) async {
    if (error != null) throw error!;
    return bannerList;
  }
}
