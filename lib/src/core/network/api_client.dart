import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
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
    StoreSessionInterceptor(
      read: () => ref.read(storeSessionProvider),
      write: ({String? nonce, String? cartToken}) => ref
          .read(storeSessionProvider.notifier)
          .absorb(nonce: nonce, cartToken: cartToken),
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
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      () => _dio.get<T>(url, queryParameters: query, cancelToken: cancelToken),
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
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      () => _dio.post<T>(
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
