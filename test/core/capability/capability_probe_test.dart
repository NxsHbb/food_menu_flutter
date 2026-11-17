import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/capability/capability_probe.dart';
import 'package:food_menu/src/core/capability/plugin_route.dart';
import 'package:food_menu/src/core/config/app_config.dart';
import 'package:food_menu/src/core/network/api_client.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/network/capability_interceptor.dart';

import '../network/fake_adapter.dart';
import 'plugin_index_fixtures.dart';

void main() {
  const config = AppConfig(baseUrl: 'https://example.com');

  ({CapabilityProbe probe, FakeAdapter adapter}) probeFor(
    FakeResponse Function(RequestOptions options) respond,
  ) {
    final adapter = FakeAdapter(respond);
    final dio = Dio(BaseOptions(baseUrl: config.baseUrl))
      ..httpClientAdapter = adapter;

    return (
      probe: CapabilityProbe(ApiClient(dio: dio, config: config)),
      adapter: adapter,
    );
  }

  group('probing the store', () {
    test('asks the namespace root itself, with no trailing path', () async {
      final subject = probeFor((_) => FakeResponse(body: indexPayload(newPro)));

      await subject.probe.probe();

      expect(
        subject.adapter.requests.single.uri.toString(),
        'https://example.com/wp-json/fmp/v1',
      );
    });

    test('a released Pro is read for what it does have', () async {
      final subject =
          probeFor((_) => FakeResponse(body: indexPayload(releasedPro)));

      final caps = await subject.probe.probe();

      expect(caps.known, isTrue);
      expect(caps.canSignIn, isTrue);
      expect(caps.hasWishlist, isFalse);
    });

    test('no such namespace means no plugin, and no features', () async {
      // WordPress answered; it just has no `fmp/v1`. The one case where
      // hiding everything is the truth.
      final subject = probeFor(
        (_) => const FakeResponse(
          statusCode: 404,
          body: {'code': 'rest_no_route'},
        ),
      );

      final caps = await subject.probe.probe();

      expect(caps.known, isTrue);
      expect(caps.canSignIn, isFalse);
      expect(caps.has(PluginRoute.config), isFalse);
    });

    test('a failure the app cannot read leaves every feature alone', () async {
      // **The important one.** A 500, a captive portal, a dropped connection
      // at launch: the app could not ask, so it must not strip itself down.
      for (final response in const [
        FakeResponse(statusCode: 500),
        FakeResponse(statusCode: 403),
        FakeResponse(body: 'not an index at all'),
      ]) {
        final caps = await probeFor((_) => response).probe.probe();

        expect(caps.known, isFalse, reason: '$response');
        expect(caps.canOrder, isTrue, reason: '$response');
        expect(caps.hasWishlist, isTrue, reason: '$response');
      }
    });

    test('never throws, whatever the store does', () async {
      final subject = probeFor(
        (_) => const FakeResponse(statusCode: 418, body: []),
      );

      await expectLater(subject.probe.probe(), completes);
    });
  });

  group('learning from a refusal', () {
    /// A client with the interceptor in its chain, as `dioProvider` builds it.
    ///
    /// Driven through a real request rather than by calling `onError` with a
    /// hand-made handler: the interceptor's contract is that it watches and
    /// passes the failure on, and only the chain can show that it does.
    ({ApiClient client, List<PluginRoute> learned}) clientFor(
      FakeResponse Function(RequestOptions options) respond, {
      AppConfig on = config,
    }) {
      final learned = <PluginRoute>[];
      final dio = Dio(BaseOptions(baseUrl: on.baseUrl))
        ..httpClientAdapter = FakeAdapter(respond)
        ..interceptors.add(
          CapabilityInterceptor(
            pluginApiBase: on.foodMenuApiBase,
            onRouteMissing: learned.add,
          ),
        );

      return (client: ApiClient(dio: dio, config: on), learned: learned);
    }

    const noRoute = FakeResponse(
      statusCode: 404,
      body: {
        'code': 'rest_no_route',
        'message': 'No route was found matching the URL and request method.',
      },
    );

    test('`rest_no_route` names the feature the store has not got', () async {
      final subject = clientFor((_) => noRoute);

      await expectLater(
        subject.client.get<Map<String, dynamic>>(
          subject.client.foodMenuApi('app/wishlist'),
        ),
        throwsA(isA<ApiException>()),
      );

      expect(subject.learned, [PluginRoute.wishlist]);
    });

    test('the request still fails for whoever made it', () async {
      // The interceptor only watches. Swallowing the error here would leave
      // the screen that asked waiting for a reply that never comes.
      final subject = clientFor((_) => noRoute);

      await expectLater(
        subject.client.get<Map<String, dynamic>>(
          subject.client.foodMenuApi('app/slots'),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'rest_no_route'),
        ),
      );
    });

    test('and does so through a path parameter', () async {
      final subject = clientFor((_) => noRoute);

      await subject.client
          .get<Map<String, dynamic>>(
            subject.client.foodMenuApi('app/orders/412/tracking'),
          )
          .catchError((Object _) => <String, dynamic>{});

      expect(subject.learned, [PluginRoute.orderTracking]);
    });

    test('a missing *thing* is not a missing feature', () async {
      // **The distinction this interceptor exists for.** The dev store
      // answers `fmp_app_product_not_found` for a dish that is not there, on
      // a route that is. Keying on the 404 alone would switch add-ons off for
      // the session because one dish had been deleted.
      final subject = clientFor(
        (_) => const FakeResponse(
          statusCode: 404,
          body: {
            'code': 'fmp_app_product_not_found',
            'message': 'That dish does not exist.',
          },
        ),
      );

      await subject.client
          .get<Map<String, dynamic>>(
            subject.client.foodMenuApi('app/products/999999/addons'),
          )
          .catchError((Object _) => <String, dynamic>{});

      expect(subject.learned, isEmpty);
    });

    test('nor is any other failure', () async {
      for (final response in const [
        FakeResponse(statusCode: 401, body: {'code': 'fmp_app_unauthorised'}),
        FakeResponse(statusCode: 500),
        FakeResponse(statusCode: 403, body: {'code': 'fmp_ordering_disabled'}),
      ]) {
        final subject = clientFor((_) => response);

        await subject.client
            .get<Map<String, dynamic>>(
              subject.client.foodMenuApi('app/wishlist'),
            )
            .catchError((Object _) => <String, dynamic>{});

        expect(subject.learned, isEmpty, reason: '$response');
      }
    });

    test('a 404 from outside the plugin is none of its business', () async {
      // The Store API 404s a deleted product and WordPress 404s a page. The
      // plugin's own namespace is the only thing this reads.
      final subject = clientFor((_) => noRoute);

      await subject.client
          .get<Map<String, dynamic>>(
            subject.client.storeApi('products/4000'),
          )
          .catchError((Object _) => <String, dynamic>{});

      expect(subject.learned, isEmpty);
    });

    test('a store in a subdirectory is read the same way', () async {
      // `radiustheme.net/demos/food-menu` is the live one, and the path in
      // front of `/wp-json` must not shift the route.
      final subject = clientFor(
        (_) => noRoute,
        on: const AppConfig(baseUrl: 'https://example.com/demos/food-menu'),
      );

      await subject.client
          .get<Map<String, dynamic>>(subject.client.foodMenuApi('app/slots'))
          .catchError((Object _) => <String, dynamic>{});

      expect(subject.learned, [PluginRoute.slots]);
    });

    test('a route the app does not have an enum for is ignored', () async {
      final subject = clientFor((_) => noRoute);

      await subject.client
          .get<Map<String, dynamic>>(subject.client.foodMenuApi('track/abc123'))
          .catchError((Object _) => <String, dynamic>{});

      expect(subject.learned, isEmpty);
    });
  });
}
