import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/core/widgets/dish_image_placeholder.dart';

void main() {
  Future<void> pump(WidgetTester tester, {String? label, ThemeData? theme}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 80,
            child: DishImagePlaceholder(label: label),
          ),
        ),
      ),
    );
  }

  testWidgets('renders without a label', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(DishImagePlaceholder), findsOneWidget);
  });

  testWidgets('shows the caption when given one', (tester) async {
    await pump(tester, label: 'drink shot');

    expect(find.text('drink shot'), findsOneWidget);
  });

  testWidgets('paints in dark mode without error', (tester) async {
    await pump(tester, label: 'product image', theme: AppTheme.dark());

    expect(tester.takeException(), isNull);
    expect(find.text('product image'), findsOneWidget);
  });
}
