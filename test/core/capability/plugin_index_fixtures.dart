/// Route lists read off two real stores, for task 14.7's tests.
///
/// **Captured, not invented.** A fixture that was written by hand would agree
/// with the enum by construction and prove nothing; these were read from
/// `GET /wp-json/fmp/v1` on two stores on 2026-11-17 and pasted verbatim,
/// regex groups and all:
///
/// * [newPro] — the dev store at `192.168.0.165:8080`, running the plugins'
///   `mobile-app` branches, which is what the app is built against.
/// * [releasedPro] — `radiustheme.net/demos/food-menu`, running the
///   **released** Pro at the time. Five `app/*` routes out of 27, which is
///   the store this task exists for.
///
/// Only the keys matter — `StoreCapabilities.fromIndex` reads nothing else —
/// so the bodies are trimmed to one plausible `methods` entry rather than
/// carrying 19 KB of argument schemas.
library;

/// The dev store: every route the app knows about.
const newPro = <String>[
  '/fmp/v1',
  '/fmp/v1/app/address-fields',
  '/fmp/v1/app/auth/change-email',
  '/fmp/v1/app/auth/change-password',
  '/fmp/v1/app/auth/delete-account',
  '/fmp/v1/app/auth/forgot-password',
  '/fmp/v1/app/auth/login',
  '/fmp/v1/app/auth/logout',
  '/fmp/v1/app/auth/refresh',
  '/fmp/v1/app/auth/register',
  '/fmp/v1/app/auth/reset-password',
  '/fmp/v1/app/branches',
  r'/fmp/v1/app/branches/(?P<id>\d+)/unserved',
  '/fmp/v1/app/checkout-fields',
  '/fmp/v1/app/config',
  '/fmp/v1/app/me',
  '/fmp/v1/app/order-types',
  '/fmp/v1/app/orders',
  r'/fmp/v1/app/orders/(?P<id>\d+)',
  r'/fmp/v1/app/orders/(?P<id>\d+)/reorder',
  r'/fmp/v1/app/orders/(?P<id>\d+)/tracking',
  '/fmp/v1/app/payment-methods',
  r'/fmp/v1/app/products/(?P<id>\d+)/addons',
  r'/fmp/v1/app/products/(?P<id>\d+)/reviews',
  '/fmp/v1/app/slots',
  '/fmp/v1/app/special-menu',
  '/fmp/v1/app/wishlist',
  r'/fmp/v1/app/wishlist/(?P<product_id>\d+)',
  // Routes the app never calls, kept because a real index is full of them and
  // they must be ignored rather than counted.
  '/fmp/v1/dashboard/stats',
  '/fmp/v1/inventory',
  '/fmp/v1/orders',
  r'/fmp/v1/orders/(?P<id>\d+)/timeline',
  '/fmp/v1/order-statuses',
  r'/fmp/v1/track/(?P<token>[A-Za-z0-9]+)',
];

/// The live demo store, running the released Pro: auth and the profile, and
/// nothing else the app has grown since.
const releasedPro = <String>[
  '/fmp/v1',
  '/fmp/v1/app/auth/login',
  '/fmp/v1/app/auth/logout',
  '/fmp/v1/app/auth/refresh',
  '/fmp/v1/app/auth/register',
  '/fmp/v1/app/me',
  '/fmp/v1/dashboard/stats',
  '/fmp/v1/orders',
  '/fmp/v1/order-statuses',
];

/// The index payload WordPress sends for a namespace, around [routes].
Map<String, dynamic> indexPayload(List<String> routes) {
  return {
    'namespace': 'fmp/v1',
    'routes': {
      for (final route in routes)
        route: {
          'namespace': 'fmp/v1',
          'methods': ['GET'],
        },
    },
  };
}
