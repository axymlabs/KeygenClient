import 'package:flutter_test/flutter_test.dart';
import 'package:keygen_app/state/templates.dart';

void main() {
  test('template renders selected fields', () {
    final t = LicenseTemplate(id: 'a', name: 'n', fields: [
      TemplateField(label: 'url', source: FieldSource.serverUrl),
      TemplateField(label: 'key', source: FieldSource.licenseKey),
    ]);
    final out = t.renderWith(
        {FieldSource.serverUrl: 'https://x.io', FieldSource.licenseKey: 'K'}, const {});
    expect(out, '{"url":"https://x.io","key":"K"}');
  });
}
