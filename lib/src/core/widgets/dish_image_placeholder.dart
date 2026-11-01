import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The diagonal stripe fill the design uses wherever a dish has no photo.
///
/// It appears on the home cards, the menu rows, cart lines, upsells and order
/// thumbnails, which is why it lives in `core/widgets` rather than in one
/// feature. The design draws it as
/// `repeating-linear-gradient(135deg, #EFEDEA 0 6px, #E6E3DF 6px 12px)`.
class DishImagePlaceholder extends StatelessWidget {
  const DishImagePlaceholder({this.label, this.stripeWidth = 6, super.key});

  /// Optional caption, as in the design's "drink shot" and "product image".
  final String? label;

  /// Width of one stripe in logical pixels; the pattern repeats every two.
  final double stripeWidth;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = label;

    return CustomPaint(
      painter: _StripePainter(
        light: palette.placeholderLight,
        dark: palette.placeholderDark,
        stripeWidth: stripeWidth,
      ),
      child: text == null
          ? const SizedBox.expand()
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.placeholderInk,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ),
    );
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter({
    required this.light,
    required this.dark,
    required this.stripeWidth,
  });

  final Color light;
  final Color dark;
  final double stripeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);

    final paint = Paint()
      ..color = dark
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    // 135° stripes: step along the top edge and draw down-left, far enough
    // past the bounds that corners stay covered.
    final step = stripeWidth * 2;
    final extent = size.width + size.height;
    for (var x = -size.height; x < extent; x += step) {
      canvas.drawLine(
        Offset(x + stripeWidth / 2, 0),
        Offset(x + stripeWidth / 2 + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.light != light || old.dark != dark || old.stripeWidth != stripeWidth;
}
