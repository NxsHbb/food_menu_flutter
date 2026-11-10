import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/branch_interceptor.dart';

import 'fake_adapter.dart';

void main() {
  late FakeAdapter adapter;
  int? branch;
  var reads = 0;

  Dio dioWith() {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
    adapter = FakeAdapter((_) => FakeResponse(body: const {'ok': true}));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      BranchInterceptor(
        read: () async {
          reads++;
          return branch;
        },
      ),
    );
    return dio;
  }

  setUp(() {
    branch = null;
    reads = 0;
  });

  test('sends nothing before a branch is chosen', () async {
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/wc/store/v1/products');

    expect(
      adapter.requests.single.headers.containsKey(BranchInterceptor.header),
      isFalse,
    );
  });

  test('carries the chosen branch', () async {
    branch = 51;
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/wc/store/v1/products');

    expect(adapter.requests.single.headers[BranchInterceptor.header], '51');
  });

  test('sends nothing for store-wide, which the server already assumes',
      () async {
    branch = 0;
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/wc/store/v1/products');

    expect(
      adapter.requests.single.headers.containsKey(BranchInterceptor.header),
      isFalse,
    );
  });

  test('carries it to the cart as well as the menu', () async {
    branch = 51;
    final dio = dioWith();
    await dio.post<Map<String, dynamic>>('/wp-json/wc/store/v1/cart/add-item');

    expect(adapter.requests.single.headers[BranchInterceptor.header], '51');
  });

  test('is awaited, so the first request already carries it', () async {
    branch = 51;
    final dio = dioWith();

    // The restore is asynchronous; a request that went out before it resolved
    // would be answered with every branch's dishes and the menu would then
    // visibly swap.
    await dio.get<Map<String, dynamic>>('/wp-json/wc/store/v1/products');

    expect(reads, 1);
    expect(adapter.requests.single.headers[BranchInterceptor.header], '51');
  });

  test('never overwrites a header the caller set deliberately', () async {
    branch = 51;
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>(
      '/wp-json/wc/store/v1/products',
      options: Options(headers: {BranchInterceptor.header: '99'}),
    );

    expect(adapter.requests.single.headers[BranchInterceptor.header], '99');
    expect(reads, 0);
  });
}
