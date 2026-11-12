import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_controller.dart';
import '../../features/branch/data/branch_controller.dart';
import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'auth_refresh_interceptor.dart';
import 'branch_interceptor.dart';
import 'paged.dart';
import 'store_session.dart';
import 'store_session_interceptor.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// The configured dio instance.
///
/// Scoped to the whole app so the Store API session headers accumulate in one
/// place. Override this provider in tests to supply a fake adapter.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
      // We classify statuses ourselves, so let dio surface them all as errors
      // except the 2xx range.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      // `read`, not `watch`: rebuilding dio on every sign-in would discard the
      // Store API session headers it is holding.
      readToken: () async {
        try {
          // Awaits the keychain restore on a cold start, then reads the
          // session that is current *now* — `.future` resolves to the value at
          // build time, which a sign-in during startup would already have
          // replaced.
          await ref.read(authControllerProvider.future);
        } on Object {
          // A failed restore means signed out, not a failed request.
        }
        return ref.read(currentSessionProvider)?.tokens.accessToken;
      },
    ),
  );

  dio.interceptors.add(
    AuthRefreshInterceptor(
      hasSession: () => ref.read(currentSessionProvider) != null,
      refresh: () => ref.read(authControllerProvider.notifier).refresh(),
      accessToken: () => ref.read(currentSessionProvider)?.tokens.accessToken,
      // `dio.fetch` re-sends through the adapter without re-entering this
      // interceptor's queue, which would otherwise deadlock: a QueuedInterceptor
      // cannot wait on a request that is itself waiting for the same queue.
      retry: (options) => dio.fetch<dynamic>(options),
    ),
  );

  dio.interceptors.add(
    StoreSessionInterceptor(
      // Awaits the cart-token restore on a cold start, then reads what is
      // current *now* — a response that landed during startup would already
      // have replaced the value `.future` resolved to.
      read: () async {
        try {
          await ref.read(storeSessionProvider.future);
        } on Object {
          // A failed restore means a new cart, not a failed request.
        }
        return ref.read(storeSessionProvider).value ?? const StoreSession();
      },
      write: ({String? nonce, String? cartToken}) => ref
          .read(storeSessionProvider.notifier)
          .absorb(nonce: nonce, cartToken: cartToken),
    ),
  );

  dio.interceptors.add(
    BranchInterceptor(
      // Awaits the restore for the same reason the cart token does: a menu
      // request that goes out first is answered with every branch's dishes,
      // and the list would then visibly swap under the customer.
      read: () async {
        try {
          return await ref.read(selectedBranchProvider.future);
        } on Object {
          // An unreadable store means no branch, not a failed request.
          return null;
        }
      },
    ),
  );

  return dio;
});

/// Thin wrapper over dio that speaks in [ApiException] rather than
/// `DioException`, so no feature layer imports dio's error types.
class ApiClient {
  ApiClient({required Dio dio, required AppConfig config})
      : _dio = dio,
        _config = config;

  final Dio _dio;
  final AppConfig _config;

  /// Absolute URL for a WooCommerce Store API path, e.g. `cart/add-item`.
  String storeApi(String path) => '${_config.storeApiBase}/$path';

  /// Absolute URL for a Food Menu plugin path, e.g. `track/abc123`.
  String foodMenuApi(String path) => '${_config.foodMenuApiBase}/$path';

  /// Absolute URL for a core WordPress REST path, e.g. `posts`.
  String wpApi(String path) => '${_config.wpApiBase}/$path';

  Future<T> get<T>(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      () => _dio.get<T>(
        url,
        queryParameters: query,
        options: headers == null ? null : Options(headers: headers),
        cancelToken: cancelToken,
      ),
    );
  }

  /// A list request that also reads WordPress's pagination headers.
  ///
  /// Needed because the Store API sends totals as headers rather than in an
  /// envelope, so [get] alone cannot say whether another page exists.
  Future<Paged<Map<String, dynamic>>> getPaged(
    String url, {
    Map<String, dynamic>? query,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        url,
        queryParameters: {...?query, 'page': page},
        cancelToken: cancelToken,
      );

      final items = (response.data ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);

      final headers = response.headers;
      final total =
          int.tryParse(headers.value('X-WP-Total') ?? '') ?? items.length;
      // A missing header means a single page, not zero pages — otherwise a
      // proxy that strips headers would make every list look empty.
      final totalPages = int.tryParse(headers.value('X-WP-TotalPages') ?? '') ??
          (items.isEmpty ? 0 : 1);

      return Paged(
        items: items,
        total: total,
        totalPages: totalPages,
        page: page,
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<T> post<T>(
    String url, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      () => _dio.post<T>(
        url,
        data: body,
        queryParameters: query,
        options: headers == null ? null : Options(headers: headers),
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> put<T>(
    String url, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      () => _dio.put<T>(
        url,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> delete<T>(String url, {Object? body, CancelToken? cancelToken}) {
    return _send<T>(
      () => _dio.delete<T>(url, data: body, cancelToken: cancelToken),
    );
  }

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          failure: ApiFailure.malformedResponse,
          message: 'The server returned an empty response.',
        );
      }
      return data;
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    dio: ref.watch(dioProvider),
    config: ref.watch(appConfigProvider),
  );
});
