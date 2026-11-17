import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/capability/plugin_route.dart';
import 'package:food_menu/src/core/capability/store_capabilities.dart';

import 'plugin_index_fixtures.dart';

void main() {
  group('reading a store\'s REST index', () {
    test('the dev store has every route the app knows about', () {
      final caps = StoreCapabilities.fromIndex(indexPayload(newPro));

      // **The app's contract, checked against the real thing.** A typo in a
      // `PluginRoute.template` would otherwise hide a feature on every store
      // — the failure this whole task is about, caused by the fix for it.
      for (final route in PluginRoute.values) {
        expect(
          caps.has(route),
          isTrue,
          reason: '${route.name} (${route.template}) is missing from the dev '
              'store index, so either the template is wrong or the plugin '
              'stopped registering it',
        );
      }
    });

    test('a path parameter is matched whatever the regex says', () {
      final caps = StoreCapabilities.fromIndex(indexPayload(newPro));

      // `(?P<id>\d+)` and `(?P<product_id>\d+)` are different patterns for
      // the same shape, and the app writes both `{}`.
      expect(caps.has(PluginRoute.orderTracking), isTrue);
      expect(caps.has(PluginRoute.wishlistItem), isTrue);
    });

    test('routes the app never calls are ignored, not counted', () {
      final caps = StoreCapabilities.fromIndex(indexPayload(newPro));

      // The index also carries the kitchen dashboard, inventory and the
      // public tracking link. None is a capability of the app's.
      expect(PluginRoute.byTemplate('dashboard/stats'), isNull);
      expect(PluginRoute.byTemplate('track/{}'), isNull);
      expect(caps.known, isTrue);
    });

    test('a body with no routes is an answer the app cannot use', () {
      // Not `absent`: something answered, but not with an index. Assuming the
      // store has nothing on that basis would hide half the app.
      final caps = StoreCapabilities.fromIndex({'namespace': 'fmp/v1'});

      expect(caps.known, isFalse);
      expect(caps.has(PluginRoute.wishlist), isTrue);
    });
  });

  group('the released Pro, which is what this task is for', () {
    final caps = StoreCapabilities.fromIndex(indexPayload(releasedPro));

    test('it can sign a customer in', () {
      expect(caps.canSignIn, isTrue);
    });

    test('and cannot do any of the rest', () {
      expect(caps.canOrder, isFalse);
      expect(caps.hasWishlist, isFalse);
      expect(caps.hasOrderHistory, isFalse);
      expect(caps.hasOrderTracking, isFalse);
      expect(caps.hasReorder, isFalse);
      expect(caps.hasBranches, isFalse);
      expect(caps.hasAddons, isFalse);
      expect(caps.hasSpecialMenu, isFalse);
      expect(caps.canWriteReviews, isFalse);
      expect(caps.hasCheckoutFields, isFalse);
      expect(caps.canResetPassword, isFalse);
      expect(caps.canChangePassword, isFalse);
      expect(caps.canChangeEmail, isFalse);
      expect(caps.canDeleteAccount, isFalse);
    });

    test('the address book needs both its routes, and has one', () {
      // `app/me` is there and `app/address-fields` is not. Half a book is
      // not a book: the form cannot be drawn for a country without the
      // fields, so the row goes.
      expect(caps.has(PluginRoute.profile), isTrue);
      expect(caps.has(PluginRoute.addressFields), isFalse);
      expect(caps.hasAddressBook, isFalse);
    });
  });

  group('a store that could not be asked', () {
    test('is assumed to have everything', () {
      for (final route in PluginRoute.values) {
        expect(StoreCapabilities.unknown.has(route), isTrue);
      }
      expect(StoreCapabilities.unknown.canOrder, isTrue);
    });

    test('until a route refuses, and then only that one', () {
      final learned = StoreCapabilities.unknown.ruleOut(PluginRoute.wishlist);

      expect(learned.hasWishlist, isFalse);
      expect(learned.canOrder, isTrue);
      expect(learned.known, isFalse);
    });

    test('ruling out one that is already out changes nothing', () {
      final once = StoreCapabilities.unknown.ruleOut(PluginRoute.slots);
      final twice = once.ruleOut(PluginRoute.slots);

      expect(twice, same(once));
    });
  });

  group('a store with no Food Menu plugin at all', () {
    test('has nothing, and that is the one time hiding everything is right',
        () {
      for (final route in PluginRoute.values) {
        expect(StoreCapabilities.absent.has(route), isFalse);
      }
      expect(StoreCapabilities.absent.known, isTrue);
    });
  });

  group('a refusal outlives a re-probe', () {
    test('because the index says what exists, not what answered', () {
      final probed = StoreCapabilities.fromIndex(indexPayload(newPro));

      expect(probed.hasWishlist, isTrue);
      expect(
        probed.ruleOutAll(const [PluginRoute.wishlistItem]).hasWishlist,
        isFalse,
      );
    });
  });

  group('turning a request path back into a route', () {
    test('a numeric segment is the parameter and nothing else is', () {
      expect(
        PluginRoute.templateOf('app/orders/412/tracking'),
        'app/orders/{}/tracking',
      );
      expect(PluginRoute.templateOf('app/order-types'), 'app/order-types');
      // `special-menu` has a hyphen and no digits; `me` is two letters.
      expect(PluginRoute.templateOf('app/me'), 'app/me');
    });

    test('and the route is found from it', () {
      expect(
        PluginRoute.byTemplate(PluginRoute.templateOf('app/wishlist/88')),
        PluginRoute.wishlistItem,
      );
      expect(
        PluginRoute.byTemplate(PluginRoute.templateOf('app/products/5/addons')),
        PluginRoute.addons,
      );
    });
  });
}
