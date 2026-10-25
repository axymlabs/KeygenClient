import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/keygen_client.dart';

/// Where a licence-file field gets its value from.
enum FieldSource {
  licenseKey('Licence key'),
  licenseId('Licence ID'),
  licenseName('Licence name'),
  expiry('Expiry date'),
  status('Status'),
  policyId('Policy ID'),
  maxMachines('Max machines'),
  serverUrl('Server URL'),
  account('Account'),
  metadata('Metadata value'),
  fixed('Fixed text');

  const FieldSource(this.label);
  final String label;

  bool get needsParam => this == metadata || this == fixed;
  String get paramLabel => this == metadata ? 'Metadata key' : 'Text';
}

class TemplateField {
  TemplateField({required this.label, required this.source, this.param = ''});

  /// The name this field is written under in the output (e.g. "key", "url").
  String label;
  FieldSource source;
  String param;

  Map<String, dynamic> toJson() =>
      {'label': label, 'source': source.name, 'param': param};

  factory TemplateField.fromJson(Map<String, dynamic> j) => TemplateField(
        label: j['label'] as String? ?? '',
        source: FieldSource.values.firstWhere((s) => s.name == j['source'],
            orElse: () => FieldSource.licenseKey),
        param: j['param'] as String? ?? '',
      );

  TemplateField copy() =>
      TemplateField(label: label, source: source, param: param);
}

enum OutputFormat {
  json('JSON'),
  lines('key=value'),
  plain('Plain'),
  base64('Base64 JSON');

  const OutputFormat(this.label);
  final String label;
}

class LicenseTemplate {
  LicenseTemplate({
    required this.id,
    required this.name,
    this.format = OutputFormat.json,
    this.extension = 'lic',
    List<TemplateField>? fields,
  }) : fields = fields ?? [];

  final String id;
  String name;
  OutputFormat format;
  String extension;
  List<TemplateField> fields;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'format': format.name,
        'extension': extension,
        'fields': fields.map((f) => f.toJson()).toList(),
      };

  factory LicenseTemplate.fromJson(Map<String, dynamic> j) => LicenseTemplate(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Untitled',
        format: OutputFormat.values.firstWhere((f) => f.name == j['format'],
            orElse: () => OutputFormat.json),
        extension: j['extension'] as String? ?? 'lic',
        fields: (j['fields'] as List? ?? [])
            .map((f) => TemplateField.fromJson(f as Map<String, dynamic>))
            .toList(),
      );

  LicenseTemplate copy() => LicenseTemplate(
        id: id,
        name: name,
        format: format,
        extension: extension,
        fields: fields.map((f) => f.copy()).toList(),
      );

  /// Values available to fields, taken from a licence and the connected server.
  static Map<FieldSource, dynamic> valuesFor(
          Resource license, KeygenClient c) =>
      {
        FieldSource.licenseKey: license.str('key'),
        FieldSource.licenseId: license.id,
        FieldSource.licenseName: license.str('name'),
        FieldSource.expiry: license.str('expiry'),
        FieldSource.status: license.str('status'),
        FieldSource.policyId: license.relId('policy'),
        FieldSource.maxMachines: license.attributes['maxMachines'],
        FieldSource.serverUrl: c.baseUrl,
        FieldSource.account: c.account,
      };

  String render(Resource license, KeygenClient c, {bool pretty = false}) =>
      renderWith(valuesFor(license, c), license.metadata, pretty: pretty);

  String renderWith(
      Map<FieldSource, dynamic> values, Map<String, dynamic> metadata,
      {bool pretty = false}) {
    final out = <String, dynamic>{};
    for (final f in fields) {
      final dynamic v = switch (f.source) {
        FieldSource.metadata => metadata[f.param],
        FieldSource.fixed => f.param,
        _ => values[f.source],
      };
      out[f.label.isEmpty ? f.source.name : f.label] = v;
    }
    switch (format) {
      case OutputFormat.json:
        return pretty
            ? const JsonEncoder.withIndent('  ').convert(out)
            : jsonEncode(out);
      case OutputFormat.base64:
        return base64Encode(utf8.encode(jsonEncode(out)));
      case OutputFormat.lines:
        return out.entries.map((e) => '${e.key}=${e.value ?? ''}').join('\n');
      case OutputFormat.plain:
        return out.values.map((v) => v ?? '').join('\n');
    }
  }
}

/// Persists the user's licence-file templates.
class TemplateStore extends ChangeNotifier {
  static const _k = 'templates';
  List<LicenseTemplate> templates = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k);
    if (raw != null) {
      try {
        templates = (jsonDecode(raw) as List)
            .map((e) => LicenseTemplate.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    if (templates.isEmpty) {
      templates = [
        LicenseTemplate(
          id: 'key-only',
          name: 'Key only',
          format: OutputFormat.plain,
          extension: 'key',
          fields: [TemplateField(label: 'key', source: FieldSource.licenseKey)],
        ),
        LicenseTemplate(
          id: 'url-key',
          name: 'Server & key',
          fields: [
            TemplateField(label: 'url', source: FieldSource.serverUrl),
            TemplateField(label: 'key', source: FieldSource.licenseKey),
          ],
        ),
      ];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _k, jsonEncode(templates.map((t) => t.toJson()).toList()));
    notifyListeners();
  }

  Future<void> upsert(LicenseTemplate t) {
    final i = templates.indexWhere((e) => e.id == t.id);
    i >= 0 ? templates[i] = t : templates.add(t);
    return _save();
  }

  Future<void> remove(String id) {
    templates.removeWhere((t) => t.id == id);
    return _save();
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
