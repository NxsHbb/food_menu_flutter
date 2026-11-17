import 'plugin_route.dart';

/// What the store in front of the app can actually do (task 14.7).
///
/// **The app is built against the newest Pro and runs against whatever is
/// installed.** Before this, a store on an older build answered 404 to a route
/// the app had grown to depend on, and the app reported an error for a feature
/// that store simply does not have — "That is no longer available." in front of
/// a wishlist the plugin never shipped. Doc C4 asks for the opposite: a missing
/// endpoint should hide a feature, not fail.
///
/// **Learned from the plugin's own REST index**, `GET /wp-json/fmp/v1`, which
/// lists every route WordPress has registered in the namespace. One request at
/// launch and the app knows what this store has before it asks for any of it.
/// That is the only honest way round: a capability *list* in the launch payload
/// would be no use to the stores this is for, because a Pro too old to have the
/// route is also too old to publish the list. See `FINDINGS.md`.
///
/// Three states, and they are not the same:
/// * [fromIndex] — the store answered. Authoritative, both ways.
/// * [absent] — the namespace itself is not registered. No Food Menu plugin
///   here, so none of this exists.
/// * [unknown] — the probe could not be made. **Everything is assumed
///   present**, which keeps a dropped connection at launch from stripping the
///   app down to a menu; the per-request fallback then learns from refusals.
class StoreCapabilities {
  /// Positional, because a named parameter cannot be a private field's
  /// initializing formal — and both sets are private so no caller outside
  /// this file can hand the app a capability the store never claimed.
  const StoreCapabilities._(this._routes, this._ruledOut, {required this.known});

  /// The probe could not be made — no network, a 500, an unreadable body.
  ///
  /// **Assume the store has everything.** A store that cannot be reached at
  /// launch is not a store without a wishlist, and hiding half the app over a
  /// tunnel is a worse answer than letting one request fail. This is the same
  /// ruling `StoreConfig.unknown` makes about ordering.
  static const unknown = StoreCapabilities._({}, {}, known: false);

  /// WordPress answered, and has no `fmp/v1` namespace at all.
  ///
  /// The plugin is not installed or not active. Every plugin feature is off,
  /// which is the truth and is far better than twenty failing requests.
  static const absent = StoreCapabilities._({}, {}, known: true);

  /// Reads the plugin's REST namespace index.
  ///
  /// Keys arrive as `/fmp/v1/app/orders/(?P<id>\d+)/tracking`: the namespace,
  /// then the route, with each path parameter as a named regex group. Both the
  /// prefix and the groups are normalised away so what is left matches
  /// [PluginRoute.template].
  ///
  /// **Methods are not checked.** The index carries them, but a route is
  /// registered by the same code that declares what it accepts, so a route
  /// that exists with the wrong verb would be a plugin bug rather than an
  /// older build — and answering "absent" would hide the evidence.
  factory StoreCapabilities.fromIndex(Map<String, dynamic> json) {
    final routes = json['routes'];
    if (routes is! Map) return unknown;

    final namespace = json['namespace'] as String? ?? '';
    final prefix = namespace.isEmpty ? '/' : '/$namespace/';

    final templates = <String>{};
    for (final key in routes.keys) {
      if (key is! String || !key.startsWith(prefix)) continue;

      templates.add(_templateOfIndexKey(key.substring(prefix.length)));
    }

    return StoreCapabilities._(templates, const {}, known: true);
  }

  /// Whether the store answered the probe at all.
  ///
  /// Read by nothing in the UI — it is [has] that decides — but it is the
  /// difference between "this store has no wishlist" and "the app could not
  /// ask", which is worth keeping distinguishable in a log and in a test.
  final bool known;

  final Set<String> _routes;

  /// Routes the store refused with `rest_no_route` while the app was running.
  ///
  /// Only reached when [known] is false, or when the index and the store
  /// disagree. Held separately so a later probe cannot un-learn it.
  final Set<PluginRoute> _ruledOut;

  /// Whether this store has [route].
  bool has(PluginRoute route) {
    if (_ruledOut.contains(route)) return false;
    // Nothing was learned, so nothing is denied.
    if (!known) return true;

    return _routes.contains(route.template);
  }

  bool hasAll(Iterable<PluginRoute> routes) => routes.every(has);

  /// Records a route the store says it does not have.
  StoreCapabilities ruleOut(PluginRoute route) {
    if (_ruledOut.contains(route)) return this;

    return StoreCapabilities._(_routes, {..._ruledOut, route}, known: known);
  }

  /// [ruleOut] for several at once, used to carry what was learned across a
  /// re-probe.
  StoreCapabilities ruleOutAll(Iterable<PluginRoute> routes) {
    final next = {..._ruledOut, ...routes};
    if (next.length == _ruledOut.length) return this;

    return StoreCapabilities._(_routes, next, known: known);
  }

  // ---------------------------------------------------------------------------
  // The questions the app actually asks. One per feature that can be hidden,
  // rather than route checks scattered through widgets: a feature is often
  // more than one route, and the widget is the wrong place to remember which.
  // ---------------------------------------------------------------------------

  /// Whether this store can take an order through the app at all.
  ///
  /// The app cannot place one without the store's order types, its time slots
  /// and its gateways — the checkout refuses an order with no slot (task 8.9),
  /// so a store missing these is a showcase menu as surely as one with
  /// ordering switched off (8.7), and the app says so on the first screen
  /// instead of failing at the cart.
  bool get canOrder => hasAll(const [
        PluginRoute.orderTypes,
        PluginRoute.slots,
        PluginRoute.paymentMethods,
      ]);

  /// Whether accounts exist here. Without these there is nothing to sign in
  /// to, so the app does not offer it.
  bool get canSignIn => hasAll(const [
        PluginRoute.login,
        PluginRoute.register,
        PluginRoute.refresh,
      ]);

  /// Both halves, because a heart that fills and cannot be emptied is worse
  /// than no heart.
  bool get hasWishlist =>
      hasAll(const [PluginRoute.wishlist, PluginRoute.wishlistItem]);

  /// The history list and one order in full: the list exists to be opened.
  bool get hasOrderHistory =>
      hasAll(const [PluginRoute.orderHistory, PluginRoute.order]);

  bool get hasOrderTracking => has(PluginRoute.orderTracking);

  bool get hasReorder => has(PluginRoute.reorder);

  bool get hasBranches => has(PluginRoute.branches);

  /// The book is the profile route plus the store's address inputs. Without
  /// the fields the app cannot draw a form for the country, which is the whole
  /// of what task 3.9 built.
  bool get hasAddressBook =>
      hasAll(const [PluginRoute.profile, PluginRoute.addressFields]);

  /// Both halves of the reset: a link in an email the app cannot complete is
  /// a dead end, and the request is what sends the email.
  bool get canResetPassword =>
      hasAll(const [PluginRoute.forgotPassword, PluginRoute.resetPassword]);

  bool get canChangePassword => has(PluginRoute.changePassword);

  bool get canChangeEmail => has(PluginRoute.changeEmail);

  /// Task 14.1's route. **A store whose Pro predates it cannot offer deletion
  /// in the app**, and both consoles require that of a published build — so
  /// this hiding is correct for the customer and a release blocker for the
  /// store. See `docs/STORE-SUBMISSION.md`.
  bool get canDeleteAccount => has(PluginRoute.deleteAccount);

  bool get hasAddons => has(PluginRoute.addons);

  bool get hasSpecialMenu => has(PluginRoute.specialMenu);

  /// Writing one. Reading is the Store API's, so reviews still show.
  bool get canWriteReviews => has(PluginRoute.writeReview);

  bool get hasCheckoutFields => has(PluginRoute.checkoutFields);

  /// `/fmp/v1/app/products/(?P<id>\d+)/addons` → `app/products/{}/addons`.
  ///
  /// Matched per segment rather than with one regex over the whole key: a
  /// parameter never spans a `/`, and the patterns themselves contain
  /// brackets, braces and nested groups that a single expression gets wrong.
  static String _templateOfIndexKey(String route) {
    return [
      for (final segment in route.split('/'))
        if (segment.contains('(?P<')) '{}' else segment,
    ].join('/');
  }
}
