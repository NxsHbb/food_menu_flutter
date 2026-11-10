export 'package:food_menu/src/features/branch/domain/branch.dart';

import 'dart:convert';
import 'dart:io';

import 'package:food_menu/src/features/branch/data/branch_repository.dart';
import 'package:food_menu/src/features/branch/data/branch_store.dart';
import 'package:food_menu/src/features/branch/domain/branch.dart';

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
