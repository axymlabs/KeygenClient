import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../api/keygen_client.dart';
import '../state/session.dart';
import '../state/templates.dart';
import 'template_pages.dart';
import '../theme.dart';
import 'util.dart';
import 'widgets.dart';

const _signedId = '__signed__';

/// Shows a licence as a QR code and lets the user share it as a file,
/// using one of the user's licence-file formats.
class ShareLicensePage extends StatefulWidget {
  const ShareLicensePage({super.key, required this.license});
  final Resource license;

  @override
  State<ShareLicensePage> createState() => _ShareLicensePageState();
}

class _ShareLicensePageState extends State<ShareLicensePage> {
  String? _selected;
  String? _signed;
  String? _signedError;
  bool _loadingSigned = false;

  /// Extension typed by the user; null means use the format's default.
  String? _extOverride;
  String? _extFor;

  Resource get license => widget.license;

  Future<void> _loadSigned() async {
    if (_signed != null || _loadingSigned) return;
    setState(() {
      _loadingSigned = true;
      _signedError = null;
    });
    try {
      final cert =
          await context.read<Session>().api.checkoutLicenseFile(license.id);
      if (mounted) setState(() => _signed = cert);
    } on ApiException catch (e) {
      if (mounted) setState(() => _signedError = e.message);
    } finally {
      if (mounted) setState(() => _loadingSigned = false);
    }
  }

  String? _cleanExt(String? v) {
    final e = v?.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return e == null || e.isEmpty ? null : e;
  }

  String _fileName(String ext) {
    final base = (license.str('name') ?? license.id.substring(0, 8))
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return 'licence-$base.$ext';
  }

  Future<void> _shareFile(
      String content, String ext, BuildContext btnContext) async {
    final box = btnContext.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_fileName(ext)}');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TemplateStore>();
    final api = context.read<Session>().api;
    final templates = store.templates;
    final signed = _selected == _signedId;
    final template = signed || templates.isEmpty
        ? null
        : templates.firstWhere((t) => t.id == _selected,
            orElse: () => templates.first);

    String? qrData;
    String? fileText;
    String ext = 'lic';
    if (signed) {
      qrData = _signed;
      fileText = _signed;
      ext = 'lic';
    } else if (template != null) {
      qrData = template.render(license, api);
      fileText = template.render(license, api, pretty: true);
      ext = template.extension.isEmpty ? 'lic' : template.extension;
    }

    // Reset the override when switching format so each keeps its own default.
    final formatKey = signed ? _signedId : template?.id;
    if (_extFor != formatKey) {
      _extFor = formatKey;
      _extOverride = null;
    }
    final fileExt = _cleanExt(_extOverride) ?? ext;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share licence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Edit formats',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TemplateListPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final tpl in templates)
              ChoiceChip(
                label: Text(tpl.name),
                selected: !signed && tpl.id == template?.id,
                onSelected: (_) => setState(() => _selected = tpl.id),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Signed file'),
              selected: signed,
              onSelected: (_) {
                setState(() => _selected = _signedId);
                _loadSigned();
              },
            ),
          ]),
          const SizedBox(height: 24),
          if (signed && _loadingSigned)
            const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator.adaptive()))
          else if (signed && _signedError != null)
            ErrorView(
                '$_signedError\n\nSigned files need a policy with a signing scheme.',
                onRetry: _loadSigned)
          else if (qrData == null || qrData.isEmpty)
            const EmptyView(Icons.qr_code_2, 'No format selected',
                subtitle: 'Create a licence file format with the button above.')
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.28),
                        blurRadius: 48,
                        spreadRadius: -4),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  size: 248,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Color(0xFF0B141E)),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0B141E)),
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  errorStateBuilder: (_, __) => const SizedBox(
                    width: 260,
                    height: 260,
                    child: Center(
                      child: Text(
                          'Too much data for a QR code.\nShare it as a file instead.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Panel(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(fileText ?? '',
                    style: AppTheme.mono(context, size: 12)),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in {ext, 'lic', 'json', 'txt', 'key'})
                ChoiceChip(
                  label: Text('.$e'),
                  selected: fileExt == e,
                  onSelected: (_) => setState(() => _extOverride = e),
                ),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('ext-$formatKey'),
              initialValue: fileExt,
              decoration: const InputDecoration(
                  labelText: 'File type', prefixText: '.'),
              autocorrect: false,
              onChanged: (v) => setState(() => _extOverride = v),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Builder(
                  builder: (btnContext) => FilledButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share file'),
                    onPressed: () => _shareFile(fileText!, fileExt, btnContext),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                  onPressed: () =>
                      copyText(context, fileText!, 'Copied to clipboard'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
