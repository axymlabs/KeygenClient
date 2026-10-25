import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An in-memory Keygen server with sample data, for exploring the app
/// without a real server.
http.Client demoHttpClient() {
  final db = _DemoDb();
  return MockClient((req) async {
    final segs =
        req.url.pathSegments.skipWhile((s) => s != 'accounts').skip(2).toList();
    final path = segs.isEmpty ? req.url.pathSegments.skip(1).toList() : segs;
    http.Response ok(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status,
            headers: {'content-type': 'application/vnd.api+json'});

    if (path.isEmpty) return ok({'data': null});
    if (path.first == 'me') return ok({'data': db.me});

    final kind = path.first;
    final items = db.tables[kind];
    if (items == null) {
      return ok({
        'errors': [
          {'title': 'Not found', 'detail': 'Unknown resource'}
        ]
      }, 404);
    }

    if (req.method == 'GET' && path.length == 1) {
      final q = req.url.queryParameters;
      final size = int.tryParse(q['page[size]'] ?? '') ?? 25;
      final page = int.tryParse(q['page[number]'] ?? '') ?? 1;
      final start = (page - 1) * size;
      final slice = items.skip(start).take(size).toList();
      return ok({
        'data': slice,
        'meta': {'count': items.length},
        'links': {if (start + size < items.length) 'next': 'next'},
      });
    }
    final id = path[1];
    final item = items.firstWhere((e) => e['id'] == id, orElse: () => const {});
    if (path.length == 3 && req.method == 'GET') {
      // Related collection: filter the child table by the parent relationship.
      final child = db.tables[path[2]] ?? [];
      final parentRel = {
        'licenses': 'policy',
        'policies': 'product',
        'users': 'user'
      }[path[2]];
      final rel = kind == 'licenses'
          ? 'license'
          : (kind == 'policies'
              ? 'policy'
              : (kind == 'products' ? 'product' : 'user'));
      final related = child
          .where((c) {
            final r = (c['relationships'] as Map?)?[parentRel ?? rel] ??
                (c['relationships'] as Map?)?[rel];
            return r is Map && (r['data'] as Map?)?['id'] == id;
          })
          .take(10)
          .toList();
      return ok({'data': related, 'links': {}});
    }
    if (item.isEmpty) {
      return ok({
        'errors': [
          {'title': 'Not found', 'detail': 'No such record'}
        ]
      }, 404);
    }
    if (req.method == 'DELETE') {
      items.removeWhere((e) => e['id'] == id);
      return http.Response('', 204);
    }
    if (req.method == 'PATCH') {
      final attrs =
          ((jsonDecode(req.body) as Map)['data'] as Map)['attributes'] as Map;
      (item['attributes'] as Map).addAll(attrs.cast<String, dynamic>());
    }
    if (path.length == 4 && path[3] == 'check-out' && req.method == 'GET') {
      return ok({
        'data': {
          'attributes': {
            'certificate':
                '-----BEGIN LICENSE FILE-----\ndemo\n-----END LICENSE FILE-----'
          }
        }
      });
    }
    if (req.method == 'POST' && path.length == 4) {
      final action = path[3];
      final a = item['attributes'] as Map;
      if (action == 'suspend') a['status'] = 'SUSPENDED';
      if (action == 'reinstate') a['status'] = 'ACTIVE';
      if (action == 'check-in') {
        a['lastCheckIn'] = DateTime.now().toUtc().toIso8601String();
      }
    }
    return ok({'data': item});
  });
}

class _DemoDb {
  _DemoDb() {
    final rnd = math.Random(7);
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    String id(String p, int n) =>
        '$p-0000-4000-8000-${n.toString().padLeft(12, '0')}';
    Map<String, dynamic> res(String type, String id, Map<String, dynamic> a,
            [Map<String, dynamic>? rels]) =>
        {'id': id, 'type': type, 'attributes': a, 'relationships': rels ?? {}};
    Map<String, dynamic> rel(String type, String id) => {
          'data': {'type': type, 'id': id}
        };

    final products = [
      res('products', id('p1', 1), {
        'name': 'Northwind Studio',
        'url': 'https://northwind.example',
        'distributionStrategy': 'LICENSED'
      }),
      res('products', id('p1', 2), {
        'name': 'Atlas CLI',
        'url': 'https://atlas.example',
        'distributionStrategy': 'OPEN'
      }),
      res('products', id('p1', 3),
          {'name': 'Relay Server', 'distributionStrategy': 'CLOSED'}),
    ];
    final policies = [
      res('policies', id('p2', 1), {
        'name': 'Pro · yearly',
        'duration': 365 * 86400,
        'maxMachines': 3,
        'floating': true,
        'strict': false,
        'scheme': 'ED25519_SIGN'
      }, {
        'product': rel('products', id('p1', 1))
      }),
      res('policies', id('p2', 2), {
        'name': 'Trial · 14 days',
        'duration': 14 * 86400,
        'maxMachines': 1,
        'floating': false
      }, {
        'product': rel('products', id('p1', 1))
      }),
      res('policies', id('p2', 3), {
        'name': 'Team · monthly',
        'duration': 30 * 86400,
        'maxMachines': 10,
        'floating': true
      }, {
        'product': rel('products', id('p1', 2))
      }),
      res('policies', id('p2', 4), {
        'name': 'Enterprise · perpetual',
        'maxMachines': 50,
        'floating': true,
        'protected': true
      }, {
        'product': rel('products', id('p1', 3))
      }),
    ];
    const first = [
      'Ava',
      'Noah',
      'Mia',
      'Liam',
      'Zoe',
      'Ethan',
      'Ivy',
      'Leo',
      'Nina',
      'Omar',
      'Priya',
      'Sam'
    ];
    const last = [
      'Chen',
      'Okafor',
      'Silva',
      'Nguyen',
      'Berg',
      'Khan',
      'Rossi',
      'Tanaka',
      'Moreau',
      'Singh',
      'Cole',
      'Park'
    ];
    final users = [
      for (var i = 0; i < 12; i++)
        res('users', id('u1', i + 1), {
          'firstName': first[i],
          'lastName': last[i],
          'email': '${first[i].toLowerCase()}@${[
            'acme',
            'globex',
            'initech',
            'umbrella'
          ][i % 4]}.example',
          'status': i == 9 ? 'BANNED' : 'ACTIVE',
        }),
    ];
    const hex = '0123456789ABCDEF';
    String chunk() => List.generate(4, (_) => hex[rnd.nextInt(16)]).join();
    final licenses = <Map<String, dynamic>>[];
    for (var i = 0; i < 64; i++) {
      final p = policies[rnd.nextInt(policies.length)];
      final created =
          now.subtract(Duration(days: rnd.nextInt(60), hours: rnd.nextInt(24)));
      final dur = p['attributes']['duration'] as int?;
      DateTime? expiry =
          dur == null ? null : created.add(Duration(seconds: dur));
      if (i % 11 == 0) expiry = now.add(Duration(days: 2 + rnd.nextInt(26)));
      if (i % 13 == 0) {
        expiry = now.subtract(Duration(days: 1 + rnd.nextInt(20)));
      }
      if (i % 5 == 0) expiry = now.add(Duration(days: 30 + rnd.nextInt(150)));
      var status = 'ACTIVE';
      if (expiry != null && expiry.isBefore(now)) {
        status = 'EXPIRED';
      } else if (expiry != null && expiry.difference(now).inDays < 30) {
        status = 'EXPIRING';
      }
      if (i % 17 == 3) status = 'SUSPENDED';
      if (i % 29 == 7) status = 'INACTIVE';
      final u = users[rnd.nextInt(users.length)];
      licenses.add(res('licenses', id('l1', i + 1), {
        'name':
            '${u['attributes']['firstName']} ${u['attributes']['lastName']}',
        'key': '${chunk()}-${chunk()}-${chunk()}-${chunk()}',
        'status': status,
        'expiry': expiry == null ? null : iso(expiry),
        'created': iso(created),
        'maxMachines': p['attributes']['maxMachines'],
        'metadata': {
          'plan': p['attributes']['name'],
          'seats': 1 + rnd.nextInt(5)
        },
      }, {
        'policy': rel('policies', p['id'] as String),
        'user': rel('users', u['id'] as String)
      }));
    }
    licenses.sort((a, b) => (b['attributes']['created'] as String)
        .compareTo(a['attributes']['created'] as String));
    final machines = [
      for (var i = 0; i < 24; i++)
        res('machines', id('m1', i + 1), {
          'name': '${[
            'MacBook Pro',
            'Studio Mac',
            'build-runner',
            'Surface Laptop',
            'ubuntu-edge'
          ][i % 5]} ${i + 1}',
          'platform': ['macOS', 'macOS', 'Linux', 'Windows', 'Linux'][i % 5],
          'ip': '10.0.${i % 6}.${20 + i}',
          'hostname': 'host-${i + 1}.local',
        }, {
          'license': rel('licenses', licenses[i]['id'] as String)
        }),
    ];
    tables = {
      'products': products,
      'policies': policies,
      'licenses': licenses,
      'users': users,
      'machines': machines,
    };
    me = res('users', id('u1', 99),
        {'email': 'demo@keygen.example', 'firstName': 'Demo', 'role': 'admin'});
  }

  late final Map<String, List<Map<String, dynamic>>> tables;
  late final Map<String, dynamic> me;
}
