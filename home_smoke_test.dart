import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:electro_pass/main.dart';
import 'package:electro_pass/nav.dart';
import 'package:electro_pass/paper.dart';
import 'package:electro_pass/shell.dart';
import 'package:electro_pass/theme.dart';

void main() {
  testWidgets('shell renders page content and switches tabs', (tester) async {
    AppNav.tab.value = 0;
    AppNav.filter.value = null;
    AppNav.tag.value = '';
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(appPalettes.first),
      home: const Shell(),
    ));
    await tester.pumpAndSettle();

    // The regression collapsed the page area to zero height: nav was visible,
    // but none of these widgets were mounted at all.
    expect(find.text('ELECTRO PASS'), findsOneWidget);
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('A quiet place for everything that matters.'),
        findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      tester.getSize(find.byType(RefreshIndicator)).height,
      greaterThan(300),
    );

    // The floating pill still receives taps.
    Future<void> tapTab(String label) async {
      await tester.tap(find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == label,
        ),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();
    }

    await tapTab('Vault');
    expect(AppNav.tab.value, 1);
    expect(find.text('CATEGORIES'), findsOneWidget);

    await tapTab('Autofill');
    expect(AppNav.tab.value, 2);
    expect(find.text('Autofill passwords'), findsOneWidget);

    await tapTab('Settings');
    expect(AppNav.tab.value, 3);
    expect(find.text('SECURITY'), findsOneWidget);

    await tapTab('Home');
    expect(AppNav.tab.value, 0);
    expect(find.text('ELECTRO PASS'), findsOneWidget);
  });

  testWidgets('startup errors are visible instead of a blank screen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ErrorPaper(error: 'Test startup failure'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Test startup failure'), findsOneWidget);
  });
}
