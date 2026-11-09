import 'dart:math' as math;

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
        // Everything inside is a fraction of the card, never a fixed number
        // of pixels. The design's card is a fixed 330x160; here it is a
        // fraction of the viewport, so a copy column measured in the design's
        // pixels runs under the artwork on anything narrower — which is every
        // phone below 390pt wide.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _BannerMetrics(constraints.biggest);

            return Stack(
              children: [
                // Artwork bleeds off the right edge, as in the design.
                if (image != null)
                  Positioned(
                    right: -metrics.bleed,
                    top: metrics.artworkTop,
                    width: metrics.artworkWidth,
                    height: metrics.artworkHeight,
                    child: ClipRRect(
                      borderRadius: metrics.artworkRadius,
                      child: Image.network(
                        image,
                        // `cover`, not `contain`: the artwork is a band that
                        // runs off the card, so letterboxing it leaves the
                        // card's red around a floating rectangle.
                        fit: BoxFit.cover,
                        // A banner whose artwork fails still reads as a
                        // banner, so the copy stays and the band goes away.
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                if (image == null)
                  Positioned(
                    right: 0,
                    top: metrics.artworkTop,
                    width: metrics.artworkWidth - metrics.bleed,
                    height: metrics.artworkHeight,
                    child: Opacity(
                      opacity: 0.25,
                      child: ClipRRect(
                        borderRadius: metrics.artworkRadius,
                        child: const DishImagePlaceholder(),
                      ),
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
                            style:
                                text.labelSmall?.copyWith(color: palette.brand),
                          ),
                        ),
                        const SizedBox(height: AppTokens.space8),
                      ],
                      // Stops short of the artwork's left edge, so the copy
                      // never sits on top of a photo.
                      SizedBox(
                        width: metrics.copyWidth,
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
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The banner card's geometry, as fractions of the design's 330x160 card.
///
/// Kept in one place so the copy column and the artwork cannot drift apart:
/// the whole bug was a copy width and an artwork width that were each
/// plausible alone and overlapped together.
class _BannerMetrics {
  _BannerMetrics(Size size)
      : bleed = size.width * (_bleed / _designWidth),
        artworkWidth = size.width * (_artwork / _designWidth),
        artworkTop = size.height * (_artworkTop / _designHeight),
        artworkHeight = size.height * (_artworkHeight / _designHeight);

  static const _designWidth = 330.0;
  static const _designHeight = 160.0;
  static const _artwork = 170.0;
  static const _artworkTop = 20.0;
  static const _artworkHeight = 120.0;
  static const _bleed = 10.0;

  final double bleed;
  final double artworkWidth;
  final double artworkTop;
  final double artworkHeight;

  /// Where the artwork starts, measured from the card's left edge.
  double get artworkLeft => artworkWidth - bleed;

  /// The copy column, stopping a gutter short of the artwork.
  ///
  /// The design lets its copy overlap the artwork by 20px and relies on the
  /// rounded left edge curving away under the text. That holds at exactly
  /// 330pt and nowhere else, so the copy stops short here instead. Floored at
  /// zero because a very narrow card would otherwise ask for a negative width.
  double get copyWidth => math.max(
        0,
        artworkLeft - AppTokens.space16 - AppTokens.space8,
      );

  /// A fully rounded left edge, as the design's `border-radius: 60px 0 0 60px`
  /// gives on a 120-tall band.
  BorderRadius get artworkRadius => BorderRadius.horizontal(
        left: Radius.circular(artworkHeight / 2),
      );
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
