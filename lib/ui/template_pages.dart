import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../state/templates.dart';
import '../theme.dart';
import 'util.dart';
import 'widgets.dart';

/// Lists the saved licence-file formats.
class TemplateListPage extends StatelessWidget {
  const TemplateListPage({super.key});

  Future<void> _edit(BuildContext context, LicenseTemplate? tpl) async {
    final result = await Navigator.of(context).push<LicenseTemplate>(
      MaterialPageRoute(
        builder: (_) => TemplateEditorPage(
          template: tpl?.copy() ??
              LicenseTemplate(
                id: TemplateStore.newId(),
                name: 'New format',
                fields: [
                  TemplateField(label: 'key', source: FieldSource.licenseKey)
                ],
              ),
        ),
      ),
    );
    if (result != null && context.mounted) {
      await context.read<TemplateStore>().upsert(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TemplateStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Licence file formats')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New format'),
      ),
      body: store.templates.isEmpty
          ? const EmptyView(Icons.qr_code_2, 'No formats yet',
              subtitle:
                  'A format decides which fields go into a licence file or QR code.')
          : ListView(padding: const EdgeInsets.only(bottom: 96), children: [
              for (final t in store.templates)
                Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_outline),
                  ),
                  confirmDismiss: (_) async {
                    final ok = await confirm(context, 'Delete “${t.name}”?',
                        'Licences are not affected.',
                        action: 'Delete', destructive: true);
                    if (ok && context.mounted) {
                      await context.read<TemplateStore>().remove(t.id);
                    }
                    return false;
                  },
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(t.name),
                    subtitle: Text(
                        '${t.format.label} · .${t.extension} · ${t.fields.map((f) => f.label).join(', ')}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _edit(context, t),
                  ),
                ),
            ]),
    );
  }
}

/// Edits one format. Pops with the edited [LicenseTemplate].
class TemplateEditorPage extends StatefulWidget {
  const TemplateEditorPage({super.key, required this.template});
  final LicenseTemplate template;

  @override
  State<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<TemplateEditorPage> {
  late final LicenseTemplate _t = widget.template;
  late final TextEditingController _name = TextEditingController(text: _t.name);
  late final TextEditingController _ext =
      TextEditingController(text: _t.extension);

  @override
  void dispose() {
    _name.dispose();
    _ext.dispose();
    super.dispose();
  }

  void _save() {
    _t.name = _name.text.trim().isEmpty ? 'Untitled' : _name.text.trim();
    _t.extension = _ext.text.trim().replaceAll('.', '');
    if (_t.extension.isEmpty) _t.extension = 'lic';
    Navigator.of(context).pop(_t);
  }

  String _preview() {
    final api = context.read<Session>().api;
    final sample = {
      FieldSource.licenseKey: 'XXXX-XXXX-XXXX-XXXX',
      FieldSource.licenseId: '00000000-0000-0000-0000-000000000000',
      FieldSource.licenseName: 'Example licence',
      FieldSource.expiry: '2030-01-01T00:00:00.000Z',
      FieldSource.status: 'ACTIVE',
      FieldSource.policyId: '11111111-1111-1111-1111-111111111111',
      FieldSource.maxMachines: 1,
      FieldSource.serverUrl: api.baseUrl,
      FieldSource.account: api.account,
    };
    return _t.renderWith(sample, const {}, pretty: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit format'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText: 'Shown when sharing a licence.')),
          const SizedBox(height: 16),
          Text('Output', style: t.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
              'JSON suits apps, key=value suits config files, Plain is just the values, Base64 hides the text inside a QR code.',
              style: TextStyle(
                  fontSize: 12, color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          SegmentedButton<OutputFormat>(
            segments: [
              for (final f in OutputFormat.values)
                ButtonSegment(value: f, label: Text(f.label)),
            ],
            selected: {_t.format},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _t.format = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ext,
            autocorrect: false,
            decoration: const InputDecoration(
                labelText: 'File extension',
                prefixText: '.',
                helperText: 'Used when sharing as a file'),
          ),
          const SizedBox(height: 24),
          Text('Fields', style: t.textTheme.titleSmall),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => setState(() {
              _t.fields.insert(to, _t.fields.removeAt(from));
            }),
            children: [
              for (final (i, f) in _t.fields.indexed)
                _FieldCard(
                  key: ObjectKey(f),
                  index: i,
                  field: f,
                  onChanged: () => setState(() {}),
                  onDelete: () => setState(() => _t.fields.remove(f)),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add field'),
              onPressed: () => setState(() => _t.fields.add(
                  TemplateField(label: 'field', source: FieldSource.fixed))),
            ),
          ),
          const SizedBox(height: 16),
          Text('Preview', style: t.textTheme.titleSmall),
          const SizedBox(height: 8),
          Panel(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(_preview(),
                    style: AppTheme.mono(context, size: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    super.key,
    required this.index,
    required this.field,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final TemplateField field;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_indicator),
            ),
          ),
          Expanded(
            child: Column(children: [
              TextFormField(
                initialValue: field.label,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'Name in file',
                    helperText: 'The key this value is written under',
                    isDense: true),
                onChanged: (v) {
                  field.label = v;
                  onChanged();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FieldSource>(
                initialValue: field.source,
                isDense: true,
                decoration: const InputDecoration(
                    labelText: 'Value',
                    helperText: 'Where the data comes from',
                    isDense: true),
                items: [
                  for (final s in FieldSource.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  field.source = v;
                  if (!v.needsParam) field.param = '';
                  onChanged();
                },
              ),
              if (field.source.needsParam) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(field.source),
                  initialValue: field.param,
                  autocorrect: false,
                  decoration: InputDecoration(
                      labelText: field.source.paramLabel,
                      helperText: field.source == FieldSource.metadata
                          ? 'Name of the metadata field to read'
                          : 'Written exactly as typed',
                      isDense: true),
                  onChanged: (v) {
                    field.param = v;
                    onChanged();
                  },
                ),
              ],
            ]),
          ),
          IconButton(
              icon: const Icon(Icons.delete_outline), onPressed: onDelete),
        ]),
      ),
    );
  }
}
