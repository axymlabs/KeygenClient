import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keygen_app/api/keygen_client.dart';
import 'package:keygen_app/state/device_activity.dart';
import 'package:keygen_app/theme.dart';
import 'package:keygen_app/ui/heartbeat_chart.dart';

Resource device(String id, Map<String, dynamic> attrs) =>
    Resource(id: id, type: 'machines', attributes: attrs, relationships: {});

DeviceActivity snapshot() => DeviceActivity.fromResources([
      for (var i = 0; i < 6; i++)
        device('healthy-$i', {'heartbeatStatus': 'ALIVE'}),
      device('late-1', {'heartbeatStatus': 'DEAD'}),
      device('late-2', {'nextHeartbeat': '2026-10-26T10:00:00Z'}),
      device('pending',
          {'requireHeartbeat': true, 'heartbeatStatus': 'NOT_STARTED'}),
      device('optional',
          {'requireHeartbeat': false, 'heartbeatStatus': 'NOT_STARTED'}),
      device('unknown', {}),
    ], [], DateTime.utc(2026, 10, 26, 12));

void main() {
  test('heartbeat groups preserve unknown and optional states', () {
    final data = snapshot();
    final counts = <HeartbeatGroup, int>{};
    for (final m in data.machines) {
      final group = data.heartbeatGroup(m);
      counts[group] = (counts[group] ?? 0) + 1;
    }
    expect(counts, {
      HeartbeatGroup.onTime: 6,
      HeartbeatGroup.overdue: 2,
      HeartbeatGroup.notStarted: 1,
      HeartbeatGroup.unmonitored: 1,
      HeartbeatGroup.unknown: 1
    });
  });

  testWidgets('legend filters devices and toggles back to all', (tester) async {
    List<Resource>? opened;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: HeartbeatChart(
                    activity: snapshot(),
                    onOpen: (devices, _) => opened = devices)))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('heartbeat-overdue')));
    await tester.pumpAndSettle();
    expect(find.text('18% of devices'), findsOneWidget);
    await tester.ensureVisible(find.text('View 2 devices'));
    await tester.tap(find.text('View 2 devices'));
    expect(opened!.map((d) => d.id), ['late-1', 'late-2']);
    await tester.tap(find.byKey(const ValueKey('heartbeat-overdue')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all devices'));
    expect(opened!.length, 11);
  });

  testWidgets('tapping the ring selects its corresponding status',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: HeartbeatChart(
                    activity: snapshot(), onOpen: (_, __) {})))));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const ValueKey('heartbeat-ring')));
    // About 229 degrees clockwise from the top: the middle of the overdue
    // segment (6 on time, then 2 overdue, out of 11 devices).
    await tester.tapAt(rect.center + const Offset(-71, 62));
    await tester.pumpAndSettle();
    expect(find.text('View 2 devices'), findsOneWidget);
    expect(
        find.text(
            'Past the heartbeat deadline or reported dead by the server.'),
        findsOneWidget);
  });

  for (final width in [320.0, 800.0]) {
    testWidgets('heartbeat chart fits width $width with enlarged text',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 1100),
                  textScaler: const TextScaler.linear(1.5)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: HeartbeatChart(
                              activity: snapshot(), onOpen: (_, __) {})))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty chart remains honest and cannot open a device list',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: HeartbeatChart(
                    activity:
                        DeviceActivity.fromResources([], [], DateTime.now()),
                    onOpen: (_, __) => fail('Empty list opened'))))));
    await tester.pumpAndSettle();
    expect(find.text('No devices yet'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });

  testWidgets('capture heartbeat chart previews', (tester) async {
    final out = Platform.environment['HEARTBEAT_SHOTS'];
    if (out == null) return;
    for (final entry in {
      'SF': '/System/Library/Fonts/SFNS.ttf',
      'Menlo': '/System/Library/Fonts/SFNSMono.ttf'
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(
            ByteData.sublistView(File(entry.value).readAsBytesSync())));
      await loader.load();
    }
    tester.view.physicalSize = const Size(780, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final brightness in [Brightness.dark, Brightness.light]) {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(brightness, fontFamily: 'SF'),
          home: RepaintBoundary(
              key: key,
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 36, 16, 24),
                          child: HeartbeatChart(
                              activity: snapshot(), onOpen: (_, __) {})))))));
      await tester.pumpAndSettle();
      if (brightness == Brightness.dark) {
        await tester.tap(find.byKey(const ValueKey('heartbeat-overdue')));
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        File('$out/heartbeat-${brightness.name}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }, skip: Platform.environment['HEARTBEAT_SHOTS'] == null);
}
