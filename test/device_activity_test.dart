import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keygen_app/api/keygen_client.dart';
import 'package:keygen_app/state/device_activity.dart';
import 'package:keygen_app/state/session.dart';
import 'package:keygen_app/ui/device_activity_panel.dart';
import 'package:provider/provider.dart';

final now = DateTime.utc(2026, 10, 25, 12);
final past = now.subtract(const Duration(minutes: 1)).toIso8601String();
final future = now.add(const Duration(minutes: 1)).toIso8601String();

Resource licence(String id, {String? due, bool? required}) =>
    Resource(id: id, type: 'licenses', attributes: {
      if (due != null) 'nextCheckIn': due,
      if (required != null) 'requireCheckIn': required,
    }, relationships: {});

Resource machine(String id, {String? licenceId, String? due, String? status}) =>
    Resource(id: id, type: 'machines', attributes: {
      'name': id,
      if (due != null) 'nextHeartbeat': due,
      if (status != null) 'heartbeatStatus': status,
    }, relationships: {
      if (licenceId != null)
        'license': {
          'data': {'type': 'licenses', 'id': licenceId}
        },
    });

void main() {
  test('licence check-ins count devices, heartbeat deadlines are separate', () {
    final machines = [
      machine('one', licenceId: 'late', due: past),
      machine('two', licenceId: 'late', due: future),
      machine('three', licenceId: 'current', status: 'DEAD'),
      machine('four', licenceId: 'disabled'),
      machine('five', licenceId: 'missing'),
      machine('six', licenceId: 'no-deadline'),
    ];
    final activity = DeviceActivity.fromResources(
        machines,
        [
          licence('late', due: past, required: true),
          licence('current', due: future, required: true),
          licence('disabled', due: past, required: false),
          licence('no-deadline', required: true),
        ],
        now);
    expect(activity.overdueLicenceDevices, {'one', 'two'});
    expect(activity.overdueHeartbeats, {'one', 'three'});
    expect(activity.missingLicenceLinks, 1);
    expect(activity.checkedAt, now);
  });

  test('missing deadlines do not make an unmonitored machine overdue', () {
    final unmonitored = machine('one', licenceId: 'l', status: 'NOT_STARTED');
    final activity = DeviceActivity.fromResources(
        [unmonitored, unmonitored], [licence('l')], now);
    expect(activity.machines.length, 1);
    expect(activity.overdueHeartbeats, isEmpty);
    expect(activity.overdueLicenceDevices, isEmpty);
  });

  KeygenClient pagedApi({bool forbidden = false}) => KeygenClient(
      baseUrl: 'https://keygen.example',
      httpClient: MockClient((req) async {
        if (forbidden) {
          return http.Response(
              jsonEncode({
                'errors': [
                  {'detail': 'Access denied'}
                ]
              }),
              403);
        }
        final machines = req.url.path.endsWith('/machines');
        final second = req.url.queryParameters['page[number]'] == '2';
        final resources = machines
            ? second
                ? [machine('Late Mac', licenceId: 'late', status: 'DEAD')]
                : [
                    for (var i = 0; i < 100; i++)
                      machine('Device $i', licenceId: 'ok')
                  ]
            : second
                ? [licence('late', due: '2000-01-01T00:00:00Z', required: true)]
                : [licence('ok')];
        return http.Response(
            jsonEncode({
              'data': [
                for (final r in resources)
                  {
                    'id': r.id,
                    'type': r.type,
                    'attributes': r.attributes,
                    'relationships': r.relationships,
                  }
              ],
              'links': {
                if (!second)
                  'next': '${req.url.path}?page[number]=2&page[size]=100'
              }
            }),
            200);
      }));

  test('health scan includes machines and licences after the first page',
      () async {
    final activity = await DeviceActivity.load(pagedApi());
    expect(activity.machines.length, 101);
    expect(activity.overdueHeartbeats, {'Late Mac'});
    expect(activity.overdueLicenceDevices, {'Late Mac'});
  });

  testWidgets('dashboard counters open the matching devices on a phone layout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: Session()..client = pagedApi(),
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(child: DeviceActivityPanel())))));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNWidgets(2));
    await tester.tap(find.text('Devices on overdue licences'));
    await tester.pumpAndSettle();
    expect(find.text('Late Mac'), findsOneWidget);
    expect(find.text('Device 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed activity scan reports unknown rather than zero',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: Session()..client = pagedApi(forbidden: true),
        child: const MaterialApp(home: Scaffold(body: DeviceActivityPanel()))));
    await tester.pumpAndSettle();
    expect(find.text('Device activity unavailable'), findsOneWidget);
    expect(find.text('Devices on overdue licences'), findsNothing);
    expect(find.text('0'), findsNothing);
  });
}
