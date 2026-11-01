import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/dish_image_placeholder.dart';
import '../../domain/promo_banner.dart';

/// The design's horizontally scrolling promo band, with page dots.
///
/// Every banner currently opens the menu, because a WordPress post cannot
/// carry a tap target without registered meta — see [PromoBanner].
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({required this.banners, required this.onTap, super.key});

  final List<PromoBanner> banners;
  final ValueChanged<PromoBanner> onTap;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (page) => setState(() => _page = page),
            padEnds: false,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? AppTokens.space16 : AppTokens.space6,
                right: AppTokens.space6,
              ),
              child: _BannerCard(
                banner: banners[index],
                onTap: () => widget.onTap(banners[index]),
              ),
            ),
          ),
        ),
        // Dots are pointless for a single banner.
        if (banners.length > 1) ...[
          const SizedBox(height: AppTokens.space10),
          _Dots(count: banners.length, active: _page),
        ],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onTap});

  final PromoBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final image = banner.imageUrl;

    return Material(
      color: palette.brand,
      borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Artwork bleeds off the right edge, as in the design.
            if (image != null)
              Positioned(
                right: -8,
                top: 0,
                bottom: 0,
                width: 150,
                child: Image.network(
                  image,
                  fit: BoxFit.contain,
                  // A banner whose artwork fails still reads as a banner, so
                  // the copy stays and the image area just goes away.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppTokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (banner.badge case final badge?) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.space8,
                        vertical: AppTokens.space2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge.toUpperCase(),
                        style: text.labelSmall?.copyWith(color: palette.brand),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space8),
                  ],
                  // Constrained so long copy never runs under the artwork.
                  SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banner.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        if (banner.subtitle.isNotEmpty) ...[
                          const SizedBox(height: AppTokens.space2),
                          Text(
                            banner.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (image == null)
              const Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 90,
                child: Opacity(
                  opacity: 0.25,
                  child: DishImagePlaceholder(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? palette.brand : palette.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
