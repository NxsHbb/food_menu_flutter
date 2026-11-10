import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/branch/data/branch_controller.dart';
import 'package:food_menu/src/features/branch/data/branch_repository.dart';
import 'package:food_menu/src/features/branch/data/branch_store.dart';
import 'package:food_menu/src/features/fulfilment/domain/order_types.dart';

import 'fake_branch_repository.dart';

void main() {
  late FakeBranchRepository repo;
  late FakeBranchStore store;

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [
        branchRepositoryProvider.overrideWithValue(repo),
        branchStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repo = FakeBranchRepository();
    store = FakeBranchStore();
  });

  group('the model, from a captured response', () {
    final list = branchesFromFixture('branches');
    final single = branchesFromFixture('branches_single');

    test('a multi-location store lists its branches', () {
      expect(list.multiLocation, isTrue);
      expect(list.branches.map((b) => b.name), ['Probe North', 'Probe South']);
    });

    test('a store with no branches still answers with itself', () {
      expect(single.multiLocation, isFalse);
      expect(single.branches.single.id, 0);
      expect(single.branches.single.isStore, isTrue);
      // WooCommerce's own store address, so the design's "Pick up from" line
      // has something to show on a single-location shop.
      expect(single.branches.single.address, isNotEmpty);
    });

    test('coordinates are null unless the branch really has them', () {
      expect(list.byId(50)!.coordinates, isNotNull);
      expect(list.byId(50)!.coordinates!.latitude, closeTo(23.78, 0.01));
      // Never 0,0 — a distance to that is a point in the Atlantic.
      expect(list.byId(51)!.coordinates, isNull);
    });

    test('open now is read per branch, not per store', () {
      expect(list.byId(50)!.openNow, isTrue);
      expect(list.byId(51)!.openNow, isFalse);
      expect(list.byId(51)!.openToday, isFalse);
    });

    test('each branch carries its own per-type rules', () {
      final south = list.byId(51)!;
      expect(south.type(OrderTypeKind.pickup)!.hasCustomSchedule, isTrue);
      expect(south.type(OrderTypeKind.pickup)!.openToday, isFalse);
    });
  });

  group('resolving which branch is in force', () {
    final list = branchesFromFixture('branches');

    test('nothing chosen falls to the first', () {
      expect(list.resolve(null)!.id, 50);
    });

    test('a remembered branch is honoured', () {
      expect(list.resolve(51)!.id, 51);
    });

    test('a branch that no longer exists falls back rather than sticking', () {
      // Deleted, or the store turned multi-location off. Leaving the app
      // pointed at it would scope every request to nothing.
      expect(list.resolve(9999)!.id, 50);
    });
  });

  group('remembering the choice', () {
    test('nothing is chosen on a first run', () async {
      final container = containerWith();

      expect(await container.read(selectedBranchProvider.future), isNull);
    });

    test('a stored branch is restored', () async {
      store.stored = 51;
      final container = containerWith();

      expect(await container.read(selectedBranchProvider.future), 51);
      await container.read(branchesProvider.future);
      expect(container.read(activeBranchProvider)!.id, 51);
    });

    test('choosing writes it through', () async {
      final container = containerWith();
      await container.read(selectedBranchProvider.future);

      await container.read(selectedBranchProvider.notifier).choose(51);

      expect(store.writes, [51]);
      expect(container.read(activeBranchIdProvider), 51);
    });

    test('choosing the same branch again writes nothing', () async {
      store.stored = 51;
      final container = containerWith();
      await container.read(selectedBranchProvider.future);

      await container.read(selectedBranchProvider.notifier).choose(51);

      expect(store.writes, isEmpty);
    });

    test('zero is a real choice, not an absent one', () async {
      // Store-wide. A null here would mean "never chose", which is different.
      final container = containerWith();
      await container.read(selectedBranchProvider.future);

      await container.read(selectedBranchProvider.notifier).choose(0);

      expect(container.read(activeBranchIdProvider), 0);
      expect(store.writes, [0]);
    });

    test('an unreadable keystore does not stop the app', () async {
      store.readFailure = Exception('keychain locked');
      final container = containerWith();

      expect(await container.read(selectedBranchProvider.future), isNull);
    });
  });

  group('failures', () {
    test('a failed load surfaces and resolves no branch', () async {
      repo.failNext = const ApiException(
        failure: ApiFailure.network,
        message: 'no branches',
      );
      final container = containerWith();

      await expectLater(
        container.read(branchesProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(activeBranchProvider), isNull);
    });

    test('it is not retried behind the customer\'s back', () async {
      repo.failNext = const ApiException(
        failure: ApiFailure.network,
        message: 'no branches',
      );
      final container = containerWith();

      await expectLater(
        container.read(branchesProvider.future),
        throwsA(isA<ApiException>()),
      );

      expect(repo.calls, 1);
    });
  });
}
