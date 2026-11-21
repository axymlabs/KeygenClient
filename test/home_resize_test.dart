import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keygen_app/state/session.dart';
import 'package:keygen_app/ui/home_shell.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('navigation keeps the mounted pages when the viewport expands',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(466, 678);
    addTearDown(tester.view.reset);

    final session = Session();
    addTearDown(session.dispose);
    await tester.runAsync(session.startDemo);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pump();
    final pages = find.byType(IndexedStack).first;
    final initialPages = tester.element(pages);
    expect(find.byType(NavigationBar), findsOneWidget);

    tester.view.physicalSize = const Size(626, 890);
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.element(pages), same(initialPages));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(466, 678);
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.element(pages), same(initialPages));
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Licences'));
    await tester.pump();
    final search = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'Search licences');
    await tester.enterText(search, 'sample');
    await tester.pump();
    expect(tester.widget<TextField>(search).controller?.text, 'sample');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(tester.widget<TextField>(search).controller?.text, isEmpty);
  });
}
