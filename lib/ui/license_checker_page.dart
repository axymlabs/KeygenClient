import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../api/keygen_client.dart';
import '../resources/kinds.dart';
import '../state/session.dart';
import 'resource_detail_page.dart';
import 'util.dart';
import 'widgets.dart';

final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false);

/// What a scanned code appears to identify.
class LicenseRef {
  const LicenseRef({this.id, this.key});
  final String? id;
  final String? key;

  /// Reads a licence id and/or key out of QR content: a licence-file format
  /// (JSON, base64 JSON, key=value lines), a signed licence file, or a bare
  /// key.
  static LicenseRef parse(String raw) {
    final text = raw.trim();
    final signed = RegExp(
            r'-----BEGIN LICENSE FILE-----(.*?)-----END LICENSE FILE-----',
            dotAll: true)
        .firstMatch(text);
    if (signed != null) {
      final cert = _decode(signed.group(1)!.replaceAll(RegExp(r'\s'), ''));
      final enc = cert is Map ? cert['enc'] : null;
      final payload = enc is String ? _decode(enc) : null;
      if (payload is Map) return _fromMap(payload);
      return const LicenseRef();
    }
    final decoded = _json(text) ?? _decode(text);
    if (decoded is Map) return _fromMap(decoded);

    if (text.contains('=') && text.contains('\n')) {
      final map = <String, dynamic>{};
      for (final line in text.split('\n')) {
        final i = line.indexOf('=');
        if (i > 0) map[line.substring(0, i).trim()] = line.substring(i + 1);
      }
      if (map.isNotEmpty) return _fromMap(map);
    }
    return _uuid.hasMatch(text) ? LicenseRef(id: text) : LicenseRef(key: text);
  }

  static dynamic _json(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  static dynamic _decode(String s) {
    try {
      return jsonDecode(utf8.decode(base64.decode(base64.normalize(s))));
    } catch (_) {
      return null;
    }
  }

  static LicenseRef _fromMap(Map m) {
    // Also handle a raw Keygen document: {data: {id, attributes: {key}}}.
    final data = m['data'];
    if (data is Map) {
      final attrs = data['attributes'];
      return LicenseRef(
          id: data['id']?.toString(),
          key: attrs is Map ? attrs['key']?.toString() : null);
    }
    String? pick(List<String> names) {
      for (final e in m.entries) {
        if (names.contains(e.key.toString().toLowerCase()) &&
            e.value != null &&
            '${e.value}'.isNotEmpty) {
          return '${e.value}';
        }
      }
      return null;
    }

    final id = pick(['id', 'licenseid', 'license_id']);
    return LicenseRef(
      id: id != null && _uuid.hasMatch(id) ? id : null,
      key: pick(['key', 'licensekey', 'license_key', 'license']),
    );
  }
}

/// Scans a licence QR code (or takes a pasted key) and shows the licence it
/// belongs to.
class LicenseCheckerPage extends StatefulWidget {
  const LicenseCheckerPage({super.key});

  @override
  State<LicenseCheckerPage> createState() => _LicenseCheckerPageState();
}

class _LicenseCheckerPageState extends State<LicenseCheckerPage> {
  final _scanner = MobileScannerController(
      formats: const [BarcodeFormat.qrCode], autoStart: true);
  final _manual = TextEditingController();

  bool _busy = false;
  String? _error;
  Resource? _license;
  Resource? _policy;

  @override
  void dispose() {
    _scanner.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _check(String raw) async {
    if (_busy || raw.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<Session>().api;
    try {
      final ref = LicenseRef.parse(raw);
      Resource? found;
      if (ref.id != null) {
        try {
          found = await api.get('licenses', ref.id!);
        } on ApiException catch (e) {
          if (e.status != 404 || ref.key == null) rethrow;
        }
      }
      if (found == null && ref.key != null) {
        found = await api.findLicenseByKey(ref.key!);
      }
      if (found == null) {
        throw ApiException(ref.id == null && ref.key == null
            ? 'This code doesn\'t look like a licence.'
            : 'No licence on this server matches that code.');
      }
      final policyId = found.relId('policy');
      Resource? policy;
      if (policyId != null) {
        try {
          policy = await api.get('policies', policyId);
        } on ApiException {
          // The licence is still worth showing without its policy.
        }
      }
      await _scanner.stop();
      if (mounted) {
        setState(() {
          _license = found;
          _policy = policy;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _license = null;
      _policy = null;
      _error = null;
      _manual.clear();
    });
    await _scanner.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Licence checker')),
      body: _license == null ? _scanView(context) : _resultView(context),
    );
  }

  Widget _scanView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(
              controller: _scanner,
              onDetect: (capture) {
                final v = capture.barcodes
                    .map((b) => b.rawValue)
                    .whereType<String>()
                    .firstOrNull;
                if (v != null) _check(v);
              },
              errorBuilder: (_, e) => EmptyView(
                  Icons.no_photography_outlined, 'Camera unavailable',
                  subtitle: e.errorCode ==
                          MobileScannerErrorCode.permissionDenied
                      ? 'Allow camera access in Settings, or paste a key below.'
                      : 'Paste a licence key below instead.'),
            ),
            if (_busy)
              const ColoredBox(
                  color: Colors.black54,
                  child: Center(child: CircularProgressIndicator.adaptive())),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text('Point the camera at a licence QR code',
            style: TextStyle(color: cs.onSurfaceVariant)),
      ),
      if (_error != null) ...[
        const SizedBox(height: 16),
        Text(_error!,
            textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
      ],
      const SectionHeader('Or enter a key'),
      TextField(
        controller: _manual,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: 'Licence key or ID',
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Check',
            onPressed: () => _check(_manual.text),
          ),
        ),
        onSubmitted: _check,
      ),
    ]);
  }

  Widget _resultView(BuildContext context) {
    final l = _license!;
    final status = l.str('status');
    final expiry = l.date('expiry');
    final max = l.attributes['maxMachines'];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(
          child: Text(l.str('name') ?? 'Unnamed licence',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        if (status != null) StatusPill(status),
      ]),
      const SizedBox(height: 16),
      RowsPanel([
        if (_policy != null)
          DataRow2('Policy', _policy!.str('name') ?? _policy!.id),
        DataRow2('Key', l.str('key') ?? '—',
            mono: true,
            onLongPress: l.str('key') == null
                ? null
                : () => copyText(context, l.str('key')!, 'Key copied')),
        DataRow2(
            'Expires',
            expiry == null
                ? 'Never'
                : '${formatValue('expiry', l.str('expiry'))} · ${relativeDays(expiry)}'),
        if (max != null) DataRow2('Max machines', '$max'),
        if (l.str('lastValidated') != null)
          DataRow2('Last validated',
              formatValue('lastValidated', l.str('lastValidated'))),
        DataRow2('ID', l.id, mono: true),
      ]),
      const SizedBox(height: 24),
      FilledButton.icon(
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open licence'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                ResourceDetailPage(kind: kinds['licenses']!, resource: l))),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan another'),
        onPressed: _reset,
      ),
    ]);
  }
}
