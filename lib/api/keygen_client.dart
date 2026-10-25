import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});

  final String message;
  final int? status;
  final String? code;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// A generic JSON:API resource. Keygen has many resource types with
/// version-dependent attributes, so we keep attributes as a loose map.
class Resource {
  Resource({
    required this.id,
    required this.type,
    required this.attributes,
    required this.relationships,
  });

  factory Resource.fromJson(Map<String, dynamic> json) => Resource(
        id: json['id'] as String,
        type: json['type'] as String,
        attributes: Map<String, dynamic>.from(json['attributes'] as Map? ?? {}),
        relationships:
            Map<String, dynamic>.from(json['relationships'] as Map? ?? {}),
      );

  final String id;
  final String type;
  final Map<String, dynamic> attributes;
  final Map<String, dynamic> relationships;

  String? str(String key) => attributes[key]?.toString();
  int? intVal(String key) {
    final v = attributes[key];
    return v is num ? v.toInt() : int.tryParse('$v');
  }

  bool? boolVal(String key) =>
      attributes[key] is bool ? attributes[key] as bool : null;
  DateTime? date(String key) {
    final v = attributes[key];
    return v is String ? DateTime.tryParse(v)?.toLocal() : null;
  }

  Map<String, dynamic> get metadata =>
      Map<String, dynamic>.from(attributes['metadata'] as Map? ?? {});

  String? relId(String name) {
    final rel = relationships[name];
    if (rel is Map && rel['data'] is Map) {
      return (rel['data'] as Map)['id'] as String?;
    }
    return null;
  }
}

class ResourcePage {
  ResourcePage(this.items, {this.total, required this.hasMore});
  final List<Resource> items;
  final int? total;
  final bool hasMore;
}

class KeygenClient {
  KeygenClient({
    required this.baseUrl,
    this.account = '',
    this.token,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;

  /// Account id or slug. May be empty for single-tenant servers.
  final String account;
  String? token;
  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = account.isEmpty
        ? '$baseUrl/v1'
        : '$baseUrl/v1/accounts/${Uri.encodeComponent(account)}';
    final uri = Uri.parse('$base/$path');
    return (query == null || query.isEmpty)
        ? uri
        : uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? basicAuth,
  }) async {
    final req = http.Request(method, _uri(path, query));
    req.headers['Accept'] = 'application/vnd.api+json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/vnd.api+json';
      req.body = jsonEncode(body);
    }
    if (basicAuth != null) {
      req.headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode(basicAuth))}';
    } else if (token != null) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    http.Response res;
    try {
      res = await http.Response.fromStream(
          await _http.send(req).timeout(const Duration(seconds: 30)));
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } catch (e) {
      throw ApiException(
          'Could not reach the server. Check the address and your connection.');
    }

    Map<String, dynamic> json = {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        if (res.statusCode < 400) {
          throw ApiException(
              'That address did not return a Keygen API response.');
        }
      }
    }

    if (res.statusCode >= 400) {
      final errors = json['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        final e = errors.first as Map;
        final title = e['title'] ?? 'Error';
        final detail = e['detail'];
        final source = (e['source'] as Map?)?['pointer'];
        final msg = detail != null ? '$detail' : '$title';
        throw ApiException(
            source != null && detail != null ? '$msg ($source)' : msg,
            status: res.statusCode,
            code: e['code']?.toString());
      }
      throw ApiException(
          res.statusCode == 404
              ? 'Not found. Check the server address and account.'
              : 'Request failed (${res.statusCode}).',
          status: res.statusCode);
    }
    return json;
  }

  // ---- Auth ----

  Future<String> createToken(String email, String password) async {
    final json = await _send('POST', 'tokens', basicAuth: '$email:$password');
    final t = (json['data'] as Map?)?['attributes']?['token'];
    if (t is! String) throw ApiException('The server did not return a token.');
    return t;
  }

  Future<Resource> me() async {
    final json = await _send('GET', 'me');
    return Resource.fromJson(json['data'] as Map<String, dynamic>);
  }

  // ---- CRUD ----

  Future<ResourcePage> list(
    String path, {
    int page = 1,
    int size = 25,
    Map<String, String>? query,
  }) async {
    final json = await _send('GET', path, query: {
      'page[number]': '$page',
      'page[size]': '$size',
      ...?query,
    });
    final items = (json['data'] as List? ?? [])
        .map((e) => Resource.fromJson(e as Map<String, dynamic>))
        .toList();
    final links = json['links'] as Map?;
    int? total;
    final metaCount = (json['meta'] as Map?)?['count'];
    if (metaCount is int) total = metaCount;
    return ResourcePage(items, total: total, hasMore: links?['next'] != null);
  }

  /// Total number of items at [path]. Uses a page size of 1 so the number of
  /// pages equals the number of items when the server doesn't report a count.
  Future<int> count(String path) async {
    final json = await _send('GET', path,
        query: {'page[number]': '1', 'page[size]': '1'});
    final metaCount = (json['meta'] as Map?)?['count'];
    if (metaCount is int) return metaCount;
    final last = (json['links'] as Map?)?['last'];
    if (last is String) {
      final n =
          int.tryParse(Uri.parse(last).queryParameters['page[number]'] ?? '');
      if (n != null) return n;
    }
    return (json['data'] as List? ?? []).length;
  }

  Future<Resource> get(String path, String id) async {
    final json = await _send('GET', '$path/$id');
    return Resource.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Follow server pagination without sending credentials to a link's host.
  /// Relationship collections use cursor pagination on newer Keygen servers.
  Future<List<Resource>> listAll(String path) async {
    final items = <Resource>[];
    Map<String, String> query = {'page[number]': '1', 'page[size]': '100'};
    final seen = <String>{};
    while (true) {
      final json = await _send('GET', path, query: query);
      items.addAll((json['data'] as List? ?? [])
          .map((e) => Resource.fromJson(e as Map<String, dynamic>)));
      final next = (json['links'] as Map?)?['next'];
      final href = next is Map ? next['href'] : next;
      if (href == null) return items;
      if (href is! String || !seen.add(href)) {
        throw ApiException(
            'The server returned invalid pagination. Try again.');
      }
      query = Uri.parse(href).queryParameters;
      if (query.isEmpty) {
        throw ApiException(
            'The server returned invalid pagination. Try again.');
      }
    }
  }

  /// Attach/detach a named feature without deleting its definition or
  /// replacing any of the parent's other entitlement relationships.
  Future<void> setEntitlement(
      String parentPath, String parentId, String entitlementId,
      {required bool attached}) async {
    if (parentPath != 'licenses' && parentPath != 'policies') {
      throw ArgumentError.value(parentPath, 'parentPath');
    }
    await _send(attached ? 'POST' : 'DELETE',
        '$parentPath/${Uri.encodeComponent(parentId)}/entitlements',
        body: {
          'data': [
            {'type': 'entitlements', 'id': entitlementId}
          ]
        });
  }

  Future<Resource> create(
    String path,
    String type,
    Map<String, dynamic> attributes, {
    Map<String, (String type, String id)> relationships = const {},
  }) async {
    final json = await _send('POST', path, body: {
      'data': {
        'type': type,
        'attributes': attributes,
        if (relationships.isNotEmpty)
          'relationships': {
            for (final e in relationships.entries)
              e.key: {
                'data': {'type': e.value.$1, 'id': e.value.$2}
              }
          },
      }
    });
    return Resource.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Resource> update(String path, String type, String id,
      Map<String, dynamic> attributes) async {
    final json = await _send('PATCH', '$path/$id', body: {
      'data': {'type': type, 'id': id, 'attributes': attributes}
    });
    return Resource.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String path, String id) => _send('DELETE', '$path/$id');

  /// POST /{path}/{id}/actions/{action}. Returns the raw response document.
  Future<Map<String, dynamic>> action(String path, String id, String action,
      {Map<String, dynamic>? attributes}) {
    return _send('POST', '$path/$id/actions/$action',
        body: attributes == null ? null : {'meta': attributes});
  }

  Future<Resource> actionResource(String path, String id, String action) async {
    final json = await this.action(path, id, action);
    return Resource.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Checks out a cryptographically signed license file. Requires the
  /// license's policy to use a signing scheme.
  Future<String> checkoutLicenseFile(String licenseId) async {
    final json = await _send('GET', 'licenses/$licenseId/actions/check-out');
    final cert = (json['data'] as Map?)?['attributes']?['certificate'];
    if (cert is! String) {
      throw ApiException('The server did not return a license file.');
    }
    return cert;
  }
}
