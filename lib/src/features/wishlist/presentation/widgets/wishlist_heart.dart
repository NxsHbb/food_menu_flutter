import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../data/wishlist_controller.dart';

/// How a heart is dressed, which differs by where it sits in the design.
enum HeartStyle {
  /// Over a dish photo: a translucent white disc, so it reads on any image.
  /// The design's dish card and product detail both use this.
  onImage,

  /// Inside a row, with no backing shape of its own.
  bare,

  /// The wishlist screen's own button: a tinted square, always filled.
  tinted,
}

/// The favourite heart.
///
/// Shown to everyone, not only to signed-in customers: the design puts it on
/// every dish, and hiding it would leave a signed-out customer no way to
/// discover that dishes can be saved at all. Tapping it while signed out
/// opens sign-in instead of calling the API, which is the journey the router
/// already anticipates — the customer is sent there mid-task and popping
/// returns them to the dish they were looking at.
class WishlistHeart extends ConsumerWidget {
  const WishlistHeart({
    required this.product,
    this.style = HeartStyle.onImage,
    this.size,
    super.key,
  });

  final Product product;
  final HeartStyle style;

  /// Tap-target size. Defaults per [style] to the design's own measurements.
  final double? size;

  double get _size =>
      size ??
      switch (style) {
        HeartStyle.onImage => 30,
        HeartStyle.bare => 28,
        HeartStyle.tinted => 38,
      };

  double get _iconSize => switch (style) {
        HeartStyle.onImage => 16,
        HeartStyle.bare => 18,
        HeartStyle.tinted => 18,
      };

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (!ref.read(isSignedInProvider)) {
      await context.pushNamed(LoginScreen.routeName);
      return;
    }

    try {
      await ref.read(wishlistControllerProvider.notifier).toggle(product);
    } on ApiException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  /// The server's own wording where it is useful, ours where it is not.
  ///
  /// A 409 is the wishlist cap and says so precisely, so it is passed through.
  /// A 401 is a session that expired between opening the menu and tapping, and
  /// "You must be signed in to do that" read as an app bug rather than an
  /// instruction.
  String _message(ApiException error) {
    return switch (error.statusCode) {
      401 => 'Please sign in again to save dishes.',
      404 => 'That dish is no longer on the menu.',
      409 => error.message,
      _ => 'Could not save that dish. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final saved = ref.watch(wishlistIdsProvider).contains(product.id);

    // The design fills the heart red when saved and otherwise draws it as a
    // grey outline, which is also what distinguishes "not saved" from
    // "nothing loaded yet" — both render as the outline.
    final icon = Icon(
      saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      size: _iconSize,
      color: saved ? palette.brand : _outlineColor(palette),
    );

    final button = InkWell(
      onTap: () => _onTap(context, ref),
      customBorder: _shape,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Center(child: icon),
      ),
    );

    return Semantics(
      button: true,
      label: saved
          ? 'Remove ${product.name} from wishlist'
          : 'Save ${product.name} to wishlist',
      child: Material(
        color: _background(palette),
        shape: _shape,
        clipBehavior: Clip.antiAlias,
        child: button,
      ),
    );
  }

  /// Grey rather than muted text colour: the design uses a dedicated tone for
  /// an unfilled heart, the same one it uses for an unselected tab.
  Color _outlineColor(AppPalette palette) => switch (style) {
        // Over a photo the disc is near-white in both themes, so the dark
        // theme's lighter grey would wash out against it.
        HeartStyle.onImage => AppTokens.tabLight,
        _ => palette.tab,
      };

  Color _background(AppPalette palette) => switch (style) {
        // Not fully opaque, so a little of the photo shows through, exactly as
        // the design has it.
        HeartStyle.onImage => Colors.white.withValues(alpha: 0.92),
        HeartStyle.bare => Colors.transparent,
        HeartStyle.tinted => palette.tint,
      };

  ShapeBorder get _shape => switch (style) {
        HeartStyle.onImage => const CircleBorder(),
        HeartStyle.bare => const CircleBorder(),
        HeartStyle.tinted => RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          ),
      };
}
