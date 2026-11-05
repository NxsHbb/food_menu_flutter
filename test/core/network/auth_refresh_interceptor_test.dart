import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/auth_interceptor.dart';
import 'package:food_menu/src/core/network/auth_refresh_interceptor.dart';

import 'fake_adapter.dart';

void main() {
  late FakeAdapter adapter;
  late Dio dio;
  late List<String> events;

  String? token;
  bool signedIn = true;
  bool refreshSucceeds = true;
  int refreshCalls = 0;
  Future<bool>? inFlight;

  /// 401 until a refresh happens, then 200 — the shape of an expired token.
  Dio buildDio({bool alwaysUnauthorised = false}) {
    final d = Dio(BaseOptions(baseUrl: 'http://example.test'));
    adapter = FakeAdapter((options) {
      final auth = options.headers['Authorization'];
      final ok = !alwaysUnauthorised && auth == 'Bearer fresh';
      return FakeResponse(
        statusCode: ok ? 200 : 401,
        body: ok ? const {'ok': true} : const {'code': 'rest_forbidden'},
      );
    });
    d.httpClientAdapter = adapter;
    d.interceptors.add(AuthInterceptor(readToken: () async => token));
    d.interceptors.add(
      AuthRefreshInterceptor(
        hasSession: () => signedIn,
        // Mirrors AuthController.refresh: one in-flight future shared by every
        // caller. Deduplication is the controller's job, not the
        // interceptor's, so the test wires it the same way the app does.
        refresh: () => inFlight ??= () async {
              refreshCalls++;
              events.add('refresh');
              await Future<void>.delayed(const Duration(milliseconds: 20));
              if (!refreshSucceeds) {
                signedIn = false;
                token = null;
                return false;
              }
              token = 'fresh';
              return true;
            }()
                .whenComplete(() => inFlight = null),
        accessToken: () => token,
        retry: (options) => d.fetch<dynamic>(options),
      ),
    );
    return d;
  }

  setUp(() {
    token = 'stale';
    signedIn = true;
    refreshSucceeds = true;
    refreshCalls = 0;
    events = [];
    inFlight = null;
  });

  test('a 401 refreshes once and replays the request', () async {
    dio = buildDio();

    final response = await dio.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/me');

    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    // Original attempt, then the replay.
    expect(adapter.requests.length, 2);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer fresh');
  });

  test('a burst of 401s produces exactly one refresh', () async {
    dio = buildDio();

    final responses = await Future.wait([
      dio.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/me'),
      dio.get<Map<String, dynamic>>('/wp-json/wc/store/v1/cart'),
      dio.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/orders'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    // The server revokes the session if a spent refresh token is replayed, so
    // this is correctness, not efficiency.
    expect(refreshCalls, 1);
  });

  test('gives up after one retry rather than looping', () async {
    dio = buildDio(alwaysUnauthorised: true);

    await expectLater(
      dio.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/me'),
      throwsA(isA<DioException>()),
    );

    expect(refreshCalls, 1);
    expect(adapter.requests.length, 2);
  });

  test('a failed refresh surfaces the original error', () async {
    refreshSucceeds = false;
    dio = buildDio();

    await expectLater(
      dio.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/me'),
      throwsA(
        isA<DioException>().having((e) => e.response?.statusCode, 'status', 401),
      ),
    );

    expect(signedIn, isFalse, reason: 'refresh signs the customer out');
    expect(adapter.requests.length, 1, reason: 'no pointless replay');
  });

  test('does not refresh while signed out', () async {
    signedIn = false;
    token = null;
    dio = buildDio();

    await expectLater(
      dio.get<Map<String, dynamic>>('/wp-json/wc/store/v1/cart'),
      throwsA(isA<DioException>()),
    );

    expect(refreshCalls, 0);
  });

  test('never refreshes on the auth routes themselves', () async {
    dio = buildDio(alwaysUnauthorised: true);

    await expectLater(
      dio.post<Map<String, dynamic>>('/wp-json/fmp/v1/app/auth/login'),
      throwsA(isA<DioException>()),
    );

    // A 401 from /login means wrong password, not an expired token.
    expect(refreshCalls, 0);
    expect(adapter.requests.length, 1);
  });

  test('leaves non-401 failures alone', () async {
    final d = Dio(BaseOptions(baseUrl: 'http://example.test'));
    adapter = FakeAdapter(
      (_) => FakeResponse(statusCode: 500, body: const {'code': 'boom'}),
    );
    d.httpClientAdapter = adapter;
    d.interceptors.add(
      AuthRefreshInterceptor(
        hasSession: () => true,
        refresh: () async {
          refreshCalls++;
          return true;
        },
        accessToken: () => 'fresh',
        retry: (options) => d.fetch<dynamic>(options),
      ),
    );

    await expectLater(
      d.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/me'),
      throwsA(isA<DioException>()),
    );

    expect(refreshCalls, 0);
  });
}
