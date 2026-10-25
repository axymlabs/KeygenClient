import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keygen_app/state/session.dart';
import 'package:keygen_app/ui/connect_screen.dart';
import 'package:provider/provider.dart';

void main() {
  for (final size in const [
    Size(800, 600),
    Size(480, 520),
    Size(1400, 900),
    Size(390, 844),
    Size(1000, 560),
  ]) {
    testWidgets('connect screen lays out at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => Session(),
        child: const MaterialApp(home: ConnectScreen()),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (size == const Size(800, 600)) {
        // Default macOS window: the form must fit without scrolling.
        final pos = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        expect(pos.maxScrollExtent, 0);
      }
    });
  }
}
