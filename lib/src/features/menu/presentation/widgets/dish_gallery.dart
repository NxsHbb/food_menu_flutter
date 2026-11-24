import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/dish_image_placeholder.dart';

/// The dish screen's photos: swipe across them, tap one to see it full screen.
///
/// **The pictures were always arriving.** `Product.images` has carried the
/// whole list since the Store API model was written, and `primaryImage` is a
/// convenience getter over `images.first`; the hero drew that one and dropped
/// the rest on the floor. Nothing in the payload changed for task 15.2.
///
/// Dots are drawn here rather than reused from `BannerCarousel`, whose
/// `_Dots` sits on the page background and is coloured for it — brand red on
/// the hairline grey. These sit **on the photograph**, where both of those
/// colours disappear against a bright or a busy picture, so they are white on
/// a translucent white. One widget serving both would need a colour pair
/// passed in on every use, which is a parameter for the sake of a shape.
class DishGallery extends StatefulWidget {
  const DishGallery({
    required this.images,
    required this.height,
    super.key,
  });

  final List<ProductImage> images;

  /// The hero's height, so the gallery fills exactly the box it replaced.
  final double height;

  @override
  State<DishGallery> createState() => _DishGalleryState();
}

class _DishGalleryState extends State<DishGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    // No photo at all is the placeholder, and it is not a gallery: there is
    // nothing to swipe and nothing to open full screen.
    if (images.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const DishImagePlaceholder(label: 'product image'),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final image = images[index];

              return Semantics(
                // The alt text when the store wrote one, and a position
                // otherwise — a screen reader on a gallery of five
                // indistinguishable photos needs to know which it is on.
                label: image.alt.isNotEmpty
                    ? image.alt
                    : 'Photo ${index + 1} of ${images.length}',
                image: true,
                button: true,
                child: GestureDetector(
                  onTap: () => _openViewer(index),
                  // The photo contributes no label of its own, and neither
                  // does the placeholder that stands in when it fails to
                  // load: `button: true` above merges everything below it,
                  // and without this a dish whose photo is missing reads out
                  // as its alt text followed by the words "product image".
                  child: ExcludeSemantics(
                    child: Image.network(
                      image.src,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const DishImagePlaceholder(label: 'product image'),
                    ),
                  ),
                ),
              );
            },
          ),
          // Dots are pointless for a single photo, as on the banners.
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppTokens.space16,
              child: _PhotoDots(count: images.length, active: _page),
            ),
        ],
      ),
    );
  }

  void _openViewer(int index) {
    showDishGalleryViewer(
      context,
      images: widget.images,
      initialIndex: index,
    );
  }
}

/// Opens the full-screen viewer at [initialIndex].
///
/// A route rather than a dialog, so the system back gesture closes it and the
/// photo gets the whole screen including the status bar area. The root
/// navigator, as the sheets on this screen use, because the dish screen is
/// pushed outside the tab shell.
Future<void> showDishGalleryViewer(
  BuildContext context, {
  required List<ProductImage> images,
  int initialIndex = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      // A fade, not a slide: the photo is already on screen behind it, and
      // sliding a copy of it in from the right reads as a different dish.
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (_, _, _) =>
          DishGalleryViewer(images: images, initialIndex: initialIndex),
    ),
  );
}

/// The photo, full screen: pinch to zoom, swipe between, close.
///
/// **Why the gestures are written out rather than handed to
/// `InteractiveViewer`.** That widget cannot share a horizontal drag with the
/// `PageView` it would sit inside: its scale recognizer takes the pointer as
/// soon as one moves, so the photos stop paging altogether. `panEnabled:
/// false` does not help — the recognizer is still registered and still wins
/// the arena; it simply does nothing with what it won. This was measured both
/// ways on a handset and in a test. The three recognizers here divide the
/// same gestures without that collision:
///
/// - **Pinch** is two-pointer only, so a one-finger drag is never claimed and
///   the `PageView` underneath keeps it. That is the whole trick.
/// - **Pan** is registered only while a photo is zoomed in, which is the only
///   time dragging one should move it rather than turn the page.
/// - **Double tap** toggles between fit and 2x, because every photo viewer
///   does and it costs four lines.
///
/// There is no drag-down-to-dismiss: it is the same vertical drag that pans a
/// zoomed photo, and the close button and the back gesture make the fight
/// unnecessary.
class DishGalleryViewer extends StatefulWidget {
  const DishGalleryViewer({
    required this.images,
    this.initialIndex = 0,
    super.key,
  });

  final List<ProductImage> images;
  final int initialIndex;

  @override
  State<DishGalleryViewer> createState() => _DishGalleryViewerState();
}

class _DishGalleryViewerState extends State<DishGalleryViewer> {
  static const _maxScale = 4.0;
  static const _doubleTapScale = 2.0;

  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  late int _page = widget.initialIndex;

  /// How far the photo on screen is zoomed, and where it has been dragged to.
  ///
  /// One photo's worth, not one per page: leaving a page resets it, so there
  /// is never a second zoomed photo to remember.
  double _scale = 1;
  Offset _offset = Offset.zero;

  // Where a pinch or a pan started, so each update is applied to the state at
  // the beginning of the gesture rather than compounding frame by frame.
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  bool get _zoomed => _scale > 1.01;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Leaving a photo returns it to its unzoomed state.
  ///
  /// Without this, a photo zoomed in and swiped away from stays zoomed, so
  /// coming back to it lands on a magnified corner with no sign of why.
  void _onPageChanged(int page) {
    setState(() {
      _page = page;
      _scale = 1;
      _offset = Offset.zero;
    });
  }

  /// Keeps the photo from being dragged off the screen entirely.
  ///
  /// At scale 1 there is nothing to pan, and beyond it the photo may travel
  /// by half the growth in each direction — which is exactly as far as it
  /// takes for its edge to reach the edge of the screen.
  Offset _clamp(Offset offset, Size size) {
    final slackX = (size.width * (_scale - 1)) / 2;
    final slackY = (size.height * (_scale - 1)) / 2;
    return Offset(
      offset.dx.clamp(-slackX, slackX),
      offset.dy.clamp(-slackY, slackY),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    setState(() {
      _scale = (_startScale * details.scale).clamp(1.0, _maxScale);
      // The focal point moving is the pinch being dragged as well as spread,
      // which is what makes zooming in on a corner feel right.
      _offset = _clamp(
        _startOffset + (details.focalPoint - _startFocal),
        size,
      );
    });
  }

  void _onPanStart(DragStartDetails details) {
    _startOffset = _offset;
    _startFocal = details.globalPosition;
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    setState(() {
      _offset = _clamp(
        _startOffset + (details.globalPosition - _startFocal),
        size,
      );
    });
  }

  void _onDoubleTap() {
    setState(() {
      _scale = _zoomed ? 1 : _doubleTapScale;
      _offset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;

              return PageView.builder(
                controller: _controller,
                itemCount: images.length,
                // Belt as well as braces. The pan recognizer below already
                // takes the drag while a photo is zoomed; this says the same
                // thing to the scroll view itself.
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final image = images[index];
                  // Only the photo being looked at is transformed; the ones
                  // either side are always drawn whole.
                  final current = index == _page;

                  return RawGestureDetector(
                    gestures: _gesturesFor(current, size),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..translateByDouble(
                          current ? _offset.dx : 0,
                          current ? _offset.dy : 0,
                          0,
                          1,
                        )
                        ..scaleByDouble(
                          current ? _scale : 1,
                          current ? _scale : 1,
                          1,
                          1,
                        ),
                      child: Center(
                        child: Semantics(
                          label: image.alt.isNotEmpty
                              ? image.alt
                              : 'Photo ${index + 1} of ${images.length}',
                          image: true,
                          child: ExcludeSemantics(
                            // `contain`, not `cover`: this is the view that
                            // exists to show the whole photograph, so nothing
                            // is cropped away.
                            child: Image.network(
                              image.src,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white54,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppTokens.space8,
            left: AppTokens.space16,
            child: Semantics(
              label: 'Close photo',
              button: true,
              child: _ViewerCloseButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + AppTokens.space24,
              child: _PhotoDots(count: images.length, active: _page),
            ),
        ],
      ),
    );
  }

  Map<Type, GestureRecognizerFactory> _gesturesFor(bool current, Size size) {
    if (!current) return const {};

    return {
      _PinchRecognizer:
          GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
        _PinchRecognizer.new,
        (instance) => instance
          ..onStart = _onScaleStart
          ..onUpdate = (details) => _onScaleUpdate(details, size),
      ),
      DoubleTapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
        DoubleTapGestureRecognizer.new,
        (instance) => instance.onDoubleTap = _onDoubleTap,
      ),
      // **Registered only while zoomed.** Leaving it out the rest of the
      // time is what lets a one-finger drag reach the `PageView` and turn
      // the page.
      if (_zoomed)
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          PanGestureRecognizer.new,
          (instance) => instance
            ..onStart = _onPanStart
            ..onUpdate = (details) => _onPanUpdate(details, size),
        ),
    };
  }
}

/// A scale recognizer that will not act on a single finger.
///
/// `ScaleGestureRecognizer` treats one pointer moving as a pan and claims the
/// gesture for it, which is precisely the claim that stops the photos paging.
/// Rejecting while only one pointer is down leaves that drag to the
/// `PageView` and keeps the two-finger pinch this is actually for.
class _PinchRecognizer extends ScaleGestureRecognizer {
  final _pointers = <int>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointers.add(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
    }

    if (event is PointerMoveEvent && _pointers.length < 2) {
      resolve(GestureDisposition.rejected);
      return;
    }

    super.handleEvent(event);
  }

  @override
  void rejectGesture(int pointer) {
    _pointers.remove(pointer);
    super.rejectGesture(pointer);
  }
}

class _ViewerCloseButton extends StatelessWidget {
  const _ViewerCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Page dots sized to sit on a photograph. See [DishGallery] for why these
/// are not the banner carousel's.
class _PhotoDots extends StatelessWidget {
  const _PhotoDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? Colors.white : Colors.white54,
              borderRadius: BorderRadius.circular(3),
              // A white dot on a white plate needs its own edge.
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 2),
              ],
            ),
          ),
      ],
    );
  }
}
