export 'package:food_menu/src/features/branch/domain/branch.dart';

import 'dart:convert';
import 'dart:io';

import 'package:food_menu/src/features/branch/data/branch_repository.dart';
import 'package:food_menu/src/features/branch/data/branch_store.dart';
import 'package:food_menu/src/features/branch/domain/branch.dart';
import 'package:food_menu/src/features/branch/domain/unserved_dish.dart';

class FakeBranchRepository implements BranchRepository {
  FakeBranchRepository({BranchList? list, this.delay = Duration.zero})
      : list = list ?? branchesFromFixture('branches');

  BranchList list;
  final Duration delay;

  /// Thrown by the next call, then cleared.
  Object? failNext;

  int calls = 0;

  @override
  Future<BranchList> branches() async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return list;
  }

  /// What [unserved] answers, keyed by branch id. Absent means "serves
  /// everything", which is the common case.
  final Map<int, List<UnservedDish>> unservedByBranch = {};

  /// Every `(branchId, productIds)` asked about, in order.
  final List<({int branchId, List<int> productIds})> unservedCalls = [];

  /// Thrown by the next [unserved], then cleared.
  Object? failNextUnserved;

  @override
  Future<List<UnservedDish>> unserved({
    required int branchId,
    required Iterable<int> productIds,
  }) async {
    unservedCalls.add((branchId: branchId, productIds: productIds.toList()));

    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = failNextUnserved;
    if (failure != null) {
      failNextUnserved = null;
      throw failure;
    }

    final ids = productIds.toSet();

    return [
      for (final dish in unservedByBranch[branchId] ?? const <UnservedDish>[])
        if (ids.contains(dish.id)) dish,
    ];
  }
}

/// A [BranchStore] in memory, so tests never touch the keychain.
class FakeBranchStore implements BranchStore {
  FakeBranchStore({this.stored});

  int? stored;

  /// Every id written, in order, so a test can prove the choice was kept.
  final List<int> writes = [];

  /// Thrown by [read], for a keystore that cannot be opened.
  Object? readFailure;

  @override
  Future<int?> read() async {
    final failure = readFailure;
    if (failure != null) throw failure;
    return stored;
  }

  @override
  Future<void> write(int branchId) async {
    stored = branchId;
    writes.add(branchId);
  }
}

BranchList branchesFromFixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return BranchList.fromJson(json as Map<String, dynamic>);
}
