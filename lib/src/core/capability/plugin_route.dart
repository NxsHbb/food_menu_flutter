/// Every route the app asks the Food Menu plugin for (task 14.7).
///
/// **This enum is the app's side of a contract it does not control.** A store
/// runs whatever Pro build it has installed, and the app is built against the
/// newest one — so any of these may simply not exist on the store in front of
/// it. Naming them in one place is what lets the app ask "does this store have
/// the wishlist" instead of finding out by showing somebody an error.
///
/// [template] is the route as WordPress registers it, with each path parameter
/// written `{}`: `app/orders/{}/tracking`. Both sides of the match normalise
/// to that shape — the plugin's REST index publishes
/// `/fmp/v1/app/orders/(?P<id>\d+)/tracking`, and a request the app made
/// carries `app/orders/42/tracking`. See [StoreCapabilities].
///
/// The Store API is deliberately absent: `wc/store/v1` is WooCommerce's, not
/// the plugin's, and a store either has WooCommerce or is not a shop at all.
enum PluginRoute {
  /// The launch payload (task 14.3).
  config('app/config'),

  /// Pickup and delivery, with the store's hours and its pause (14.2).
  orderTypes('app/order-types'),

  /// The choosable times on one date.
  slots('app/slots'),

  /// Where the store can be ordered from.
  branches('app/branches'),

  /// Which dishes a branch will not serve.
  unservedDishes('app/branches/{}/unserved'),

  /// The store's own checkout questions.
  checkoutFields('app/checkout-fields'),

  /// Which gateways the store offers the app.
  paymentMethods('app/payment-methods'),

  /// Which address inputs this store collects, per country.
  addressFields('app/address-fields'),

  /// The customer's profile and address book.
  profile('app/me'),

  /// A dish's add-on groups.
  addons('app/products/{}/addons'),

  /// Leaving a review. **Reading them is the Store API's**, so a store without
  /// this route still shows reviews — it just cannot take a new one.
  writeReview('app/products/{}/reviews'),

  /// The store's own scheduled promotion (task 9.5).
  specialMenu('app/special-menu'),

  /// The customer's order history.
  orderHistory('app/orders'),

  /// One order in full.
  order('app/orders/{}'),

  /// Where one order has got to.
  orderTracking('app/orders/{}/tracking'),

  /// What an order would add to a cart.
  reorder('app/orders/{}/reorder'),

  /// The customer's saved dishes.
  wishlist('app/wishlist'),

  /// Removing one saved dish.
  wishlistItem('app/wishlist/{}'),

  login('app/auth/login'),
  register('app/auth/register'),
  logout('app/auth/logout'),
  refresh('app/auth/refresh'),
  forgotPassword('app/auth/forgot-password'),
  resetPassword('app/auth/reset-password'),
  changePassword('app/auth/change-password'),
  changeEmail('app/auth/change-email'),

  /// Deleting the account, which both app stores require (task 14.1).
  deleteAccount('app/auth/delete-account');

  const PluginRoute(this.template);

  /// The route with every path parameter written `{}`.
  final String template;

  /// The route whose [template] is [template], or null for one the app does
  /// not use.
  ///
  /// A store runs plenty of plugin routes the app never calls — the kitchen
  /// dashboard, inventory, order statuses — and they are not its business.
  static PluginRoute? byTemplate(String template) {
    for (final route in values) {
      if (route.template == template) return route;
    }
    return null;
  }

  /// Rewrites a concrete path as a [template], so a request can be matched
  /// back to the route it was made against.
  ///
  /// Every parameter in this namespace is numeric — a post id, an order id, a
  /// branch id — so a digits-only segment is a parameter and nothing else is.
  /// That keeps this from having to parse the regexes the index publishes.
  static String templateOf(String path) {
    final segments = path.split('/');

    return [
      for (final segment in segments)
        if (segment.isNotEmpty && int.tryParse(segment) != null) '{}'
        else segment,
    ].join('/');
  }
}
