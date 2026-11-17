import 'package:dio/dio.dart';

import '../capability/plugin_route.dart';

/// Notices when the store says it has no such route, and says so once (task
/// 14.7).
///
/// **`rest_no_route` is the signal, not the 404.** WordPress answers 404 for
/// two unrelated things, and treating them alike would be a bug either way:
///
/// * `{"code": "rest_no_route"}` — nothing is registered at that path. The
///   store's plugin does not have the feature, and it never will until it is
///   updated.
/// * `{"code": "fmp_app_product_not_found"}`, `fmp_order_not_found` and the
///   rest — the route is there and the *thing* is not. A deleted dish, an
///   order belonging to somebody else.
///
/// Both were checked against the dev store, which is why this reads the code
/// rather than the status: keying on 404 alone would disable add-ons for the
/// session because one dish had been removed, and keying on nothing would go
/// on reporting "That is no longer available." for a feature the store never
/// shipped.
///
/// This is the **fallback**, not the mechanism. [CapabilityProbe] asks the
/// store's REST index at launch and is authoritative; this covers the store
/// whose probe never landed, and corrects an index that disagrees with the
/// store it came from.
class CapabilityInterceptor extends Interceptor {
  const CapabilityInterceptor({
    required this.pluginApiBase,
    required this.onRouteMissing,
  });

  /// The plugin namespace root, e.g. `https://shop.example/wp-json/fmp/v1`.
  /// Requests outside it are none of this interceptor's business.
  final String pluginApiBase;

  final void Function(PluginRoute route) onRouteMissing;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final route = _unregisteredRoute(err);
    if (route != null) onRouteMissing(route);

    // Always passed on. This interceptor only watches: the feature that made
    // the request still gets its error, and still decides what to draw for
    // it. Swallowing it here would leave a screen waiting forever.
    handler.next(err);
  }

  /// The route this failure says does not exist, or null when it says
  /// something else.
  PluginRoute? _unregisteredRoute(DioException err) {
    if (err.response?.statusCode != 404) return null;

    final body = err.response?.data;
    if (body is! Map || body['code'] != 'rest_no_route') return null;

    final uri = err.requestOptions.uri;
    if (!uri.toString().startsWith(pluginApiBase)) return null;

    // Trimmed by the base's own path length, which is what makes this work on
    // a site in a subdirectory — `/demos/food-menu/wp-json/fmp/v1` is as
    // ordinary a base as `/wp-json/fmp/v1`. The query goes with it: `app/slots`
    // and `app/slots?type=pickup` are one route.
    final base = Uri.parse(pluginApiBase).path;
    if (!uri.path.startsWith(base)) return null;

    final relative = uri.path.substring(base.length).replaceFirst('/', '');

    return PluginRoute.byTemplate(PluginRoute.templateOf(relative));
  }
}
