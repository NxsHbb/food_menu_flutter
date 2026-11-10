import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/branch/data/branch_repository.dart';
import 'package:food_menu/src/features/branch/data/branch_store.dart';
import 'package:food_menu/src/features/branch/presentation/widgets/branch_picker_sheet.dart';

import 'fake_branch_repository.dart';

void main() {
  late FakeBranchRepository repo;
  late FakeBranchStore store;

  setUp(() {
    repo = FakeBranchRepository();
    store = FakeBranchStore();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchRepositoryProvider.overrideWithValue(repo),
          branchStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => BranchPickerSheet.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the store\'s branches with their addresses',
      (tester) async {
    await pump(tester);

    expect(find.text('Probe North'), findsOneWidget);
    expect(find.text('Probe South'), findsOneWidget);
    expect(find.textContaining('12 North Road'), findsOneWidget);
  });

  testWidgets('says which branches are taking orders', (tester) async {
    await pump(tester);

    expect(find.text('Open now'), findsOneWidget);
    // Closed today, not merely closed now — the fixture's South branch keeps
    // its own hours and is shut every day.
    expect(find.text('Closed today'), findsOneWidget);
  });

  testWidgets('a closed branch can still be chosen', (tester) async {
    // The design lets a customer browse a branch and order for later; the
    // slot list is what refuses a time the kitchen cannot make.
    await pump(tester);

    await tester.tap(find.text('Probe South'));
    await tester.pumpAndSettle();

    expect(store.writes, [51]);
  });

  testWidgets('choosing remembers it and closes the sheet', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Probe South'));
    await tester.pumpAndSettle();

    expect(store.writes, [51]);
    expect(find.text('Probe South'), findsNothing);
  });

  testWidgets('the branch already in force is ticked', (tester) async {
    store.stored = 51;
    await pump(tester);

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('a single-location store is told, not offered a list of one',
      (tester) async {
    repo.list = branchesFromFixture('branches_single');
    await pump(tester);

    expect(find.text('This store has one location.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('a failed load offers a retry that asks again', (tester) async {
    repo.failNext = const ApiException(
      failure: ApiFailure.network,
      message: 'No connection.',
    );
    await pump(tester);

    expect(find.text('No connection.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Probe North'), findsOneWidget);
  });
}
