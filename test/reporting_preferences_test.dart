import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/reporting.dart';

void main() {
  testWidgets('reporting is optional before Firebase is initialized',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: SingleChildScrollView(child: ReportingSettings()),
    )));
    expect(find.text('Crash reports'), findsOneWidget);
    expect(find.text('Usage analytics'), findsOneWidget);
    final controls =
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
    expect(
        controls
            .every((control) => !control.value && control.onChanged == null),
        isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('offline reporting failure never replaces the app',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: ReportingConsent(
      child: Scaffold(body: Text('App works offline')),
    )));
    await tester.pumpAndSettle();
    expect(find.text('App works offline'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
