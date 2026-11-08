import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keygen_app/api/demo.dart';
import 'package:keygen_app/api/keygen_client.dart';
import 'package:keygen_app/resources/kinds.dart';
import 'package:keygen_app/state/session.dart';
import 'package:keygen_app/ui/entitlements_page.dart';
import 'package:keygen_app/ui/machine_activity.dart';
import 'package:provider/provider.dart';

KeygenClient sampleClient() => KeygenClient(
    baseUrl: 'https://demo.keygen.example',
    account: 'sample',
    httpClient: demoHttpClient());

Resource resource(String type, String id, Map<String, dynamic> attributes,
        [Map<String, dynamic> relationships = const {}]) =>
    Resource(
        id: id,
        type: type,
        attributes: attributes,
        relationships: relationships);

void main() {
  test('assignment uses additive POST and targeted DELETE JSON:API bodies',
      () async {
    final requests = <http.Request>[];
    final api = KeygenClient(
        baseUrl: 'https://keygen.example',
        account: 'acme',
        token: 'test-token',
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response('', 204);
        }));
    await api.setEntitlement('policies', 'p', 'e', attached: true);
    await api.setEntitlement('licenses', 'l', 'e', attached: false);
    expect(requests.map((r) => r.method), ['POST', 'DELETE']);
    expect(requests.map((r) => r.url.path), [
      '/v1/accounts/acme/policies/p/entitlements',
      '/v1/accounts/acme/licenses/l/entitlements',
    ]);
    for (final req in requests) {
      expect(jsonDecode(req.body), {
        'data': [
          {'type': 'entitlements', 'id': 'e'}
        ]
      });
      expect(req.headers['authorization'], 'Bearer test-token');
    }
  });

  test('relationship listing follows cursors on the configured server only',
      () async {
    final requests = <Uri>[];
    final api = KeygenClient(
        baseUrl: 'https://keygen.example',
        account: 'acme',
        httpClient: MockClient((req) async {
          requests.add(req.url);
          if (!req.url.queryParameters.containsKey('page[number]') &&
              !req.url.queryParameters.containsKey('page[cursor]')) {
            return http.Response(
                jsonEncode({
                  'errors': [
                    {
                      'detail':
                          'page must be an object containing a cursor or number and optional size'
                    }
                  ]
                }),
                400);
          }
          final page =
              req.url.queryParameters['page[cursor]'] == 'second' ? 2 : 1;
          return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'e$page',
                    'type': 'entitlements',
                    'attributes': {'code': 'E$page'}
                  }
                ],
                'links': {
                  if (page == 1)
                    'next':
                        'https://untrusted.example/entitlements?page[cursor]=second&page[size]=100'
                }
              }),
              200);
        }));
    expect((await api.listAll('entitlements')).map((r) => r.id), ['e1', 'e2']);
    expect(requests.every((u) => u.host == 'keygen.example'), isTrue);
    expect(requests.last.queryParameters['page[cursor]'], 'second');
    expect(requests.first.queryParameters['page[number]'], '1');
  });

  test('invalid repeating pagination fails rather than showing a partial list',
      () async {
    final api = KeygenClient(
        baseUrl: 'https://keygen.example',
        httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'data': [],
              'links': {'next': '/entitlements?page[cursor]=same'}
            }),
            200)));
    await expectLater(
        api.listAll('entitlements'), throwsA(isA<ApiException>()));
  });

  test('demo CRUD and inheritance match effective entitlement semantics',
      () async {
    final api = sampleClient();
    final policy = (await api.listAll('policies')).first;
    final license = (await api.listAll('licenses'))
        .firstWhere((r) => r.relId('policy') == policy.id);
    final feature = await api.create('entitlements', 'entitlements',
        {'name': 'Audit export', 'code': 'AUDIT_EXPORT'});
    final edited = await api.update('entitlements', 'entitlements', feature.id,
        {'name': 'Audit report export'});
    expect(edited.str('code'), 'AUDIT_EXPORT');
    await api.setEntitlement('policies', policy.id, feature.id, attached: true);
    final effective = await api.listAll('licenses/${license.id}/entitlements');
    expect(effective.map((r) => r.id), contains(feature.id));
    await expectLater(
        api.setEntitlement('licenses', license.id, feature.id, attached: false),
        throwsA(isA<ApiException>()));
    await api.setEntitlement('policies', policy.id, feature.id,
        attached: false);
    expect(
        (await api.listAll('licenses/${license.id}/entitlements'))
            .map((r) => r.id),
        isNot(contains(feature.id)));
    // Detach preserves the definition, and direct licence grants work too.
    expect((await api.get('entitlements', feature.id)).str('name'),
        'Audit report export');
    await api.setEntitlement('licenses', license.id, feature.id,
        attached: true);
    await api.delete('entitlements', feature.id);
    expect(
        (await api.listAll('licenses/${license.id}/entitlements'))
            .map((r) => r.id),
        isNot(contains(feature.id)));
  });

  testWidgets(
      'inherited grants cannot detach from a licence; extra grants attach',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = sampleClient();
    final policy = (await api.listAll('policies')).first;
    final license = (await api.listAll('licenses'))
        .firstWhere((r) => r.relId('policy') == policy.id);
    final session = Session()..client = api;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp(
            home:
                EntitlementsPage(parent: license, kind: kinds['licenses']!))));
    await tester.pumpAndSettle();
    expect(find.text('PDF export'), findsOneWidget);
    expect(find.byTooltip('Manage on the policy'), findsOneWidget);
    await tester.tap(find.text('Attach entitlement'));
    await tester.pumpAndSettle();
    expect(find.text('PDF export'), findsNothing);
    await tester.tap(find.text('Team workspace'));
    // The parent intentionally remains busy while confirmation is open.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(TextButton, 'Attach'));
    await tester.pumpAndSettle();
    expect(find.text('Team workspace'), findsOneWidget);
    final effective = await api.listAll('licenses/${license.id}/entitlements');
    expect(effective.map((r) => r.str('code')), contains('TEAM_WORKSPACE'));
    final row = find.ancestor(
        of: find.text('Team workspace'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(
        of: row, matching: find.byTooltip('Detach entitlement')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Detach'));
    await tester.pumpAndSettle();
    expect(find.text('Team workspace'), findsNothing);
    expect((await api.listAll('entitlements')).map((r) => r.str('code')),
        contains('TEAM_WORKSPACE'));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unreadable policy grants show an error and block assignment',
      (tester) async {
    final api = KeygenClient(
        baseUrl: 'https://keygen.example',
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/policies/p/entitlements')) {
            return http.Response(
                jsonEncode({
                  'errors': [
                    {'detail': 'Permission denied for policy entitlements.'}
                  ]
                }),
                403);
          }
          return http.Response(
              jsonEncode({
                'data': req.url.path.endsWith('/licenses/l')
                    ? {
                        'id': 'l',
                        'type': 'licenses',
                        'relationships': {
                          'policy': {
                            'data': {'type': 'policies', 'id': 'p'}
                          }
                        }
                      }
                    : <Object>[]
              }),
              200);
        }));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: Session()..client = api,
        child: MaterialApp(
            home: EntitlementsPage(
                parent: resource('licenses', 'l', {}),
                kind: kinds['licenses']!))));
    await tester.pumpAndSettle();
    expect(find.text('Permission denied for policy entitlements.'),
        findsOneWidget);
    expect(find.text('Attach entitlement'), findsNothing);
    expect(find.text('No entitlements attached.'), findsNothing);
  });

  for (final width in [390.0, 900.0]) {
    testWidgets('machine activity is read-only and lays out at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final requests = <http.Request>[];
      final api = KeygenClient(
          baseUrl: 'https://keygen.example',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(
                jsonEncode({
                  'data': {
                    'id': 'license',
                    'type': 'licenses',
                    'attributes': {
                      'requireCheckIn': true,
                      'lastCheckIn': '2026-10-25T10:00:00Z',
                      'nextCheckIn': '2026-10-26T10:00:00Z'
                    }
                  }
                }),
                200);
          }));
      final machine = resource('machines', 'machine', {
        'heartbeatStatus': 'ALIVE',
        'requireHeartbeat': true,
        'lastHeartbeat': '2026-10-25T10:05:00Z',
        'nextHeartbeat': '2026-10-25T10:15:00Z'
      }, {
        'license': {
          'data': {'type': 'licenses', 'id': 'license'}
        }
      });
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: Session()..client = api,
          child: MaterialApp(
              home: Scaffold(
                  body: ListView(
                      children: [MachineActivity(machine: machine)])))));
      await tester.pumpAndSettle();
      expect(find.text('Last heartbeat'), findsOneWidget);
      expect(find.text('Last check-in'), findsOneWidget);
      expect(
          find.textContaining('do not identify which machine'), findsOneWidget);
      expect(requests.length, 1);
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/v1/licenses/license');
      expect(tester.takeException(), isNull);
    });
  }
}
