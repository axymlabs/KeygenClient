import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/keygen_client.dart';
import '../resources/kinds.dart';
import '../state/session.dart';
import 'util.dart';

/// Create or edit any resource, driven by the kind's [FieldSpec]s.
/// Pops with the saved [Resource].
class ResourceFormPage extends StatefulWidget {
  const ResourceFormPage({super.key, required this.kind, this.existing});

  final ResourceKind kind;
  final Resource? existing;

  @override
  State<ResourceFormPage> createState() => _ResourceFormPageState();
}

class _ResourceFormPageState extends State<ResourceFormPage> {
  final _form = GlobalKey<FormState>();
  final _ctrls = <String, TextEditingController>{};
  final _values = <String, dynamic>{};
  final _meta = <(TextEditingController, TextEditingController)>[];
  bool _saving = false;
  String? _error;

  ResourceKind get kind => widget.kind;
  Resource? get existing => widget.existing;
  bool get editing => existing != null;

  Iterable<FieldSpec> get _fields =>
      kind.fields.where((f) => !(editing && f.createOnly));

  @override
  void initState() {
    super.initState();
    final r = existing;
    for (final f in _fields) {
      switch (f.type) {
        case FieldType.text:
        case FieldType.multiline:
        case FieldType.password:
          _ctrls[f.key] = TextEditingController(text: r?.str(f.key) ?? '');
        case FieldType.integer:
          _ctrls[f.key] =
              TextEditingController(text: r?.intVal(f.key)?.toString() ?? '');
        case FieldType.durationDays:
          final s = r?.intVal(f.key);
          _ctrls[f.key] = TextEditingController(
              text: s == null
                  ? ''
                  : (s / 86400).toStringAsFixed(s % 86400 == 0 ? 0 : 2));
        case FieldType.boolean:
          _values[f.key] = r?.boolVal(f.key) ?? false;
        case FieldType.choice:
          _values[f.key] = r?.str(f.key);
        case FieldType.dateTime:
          _values[f.key] = r?.date(f.key);
        case FieldType.metadata:
          for (final e in (r?.metadata ?? {}).entries) {
            _meta.add((
              TextEditingController(text: e.key),
              TextEditingController(text: '${e.value}')
            ));
          }
        case FieldType.relation:
          _values[f.key] = null;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final (k, v) in _meta) {
      k.dispose();
      v.dispose();
    }
    super.dispose();
  }

  dynamic _parseMetaValue(String v) {
    if (v == 'true') return true;
    if (v == 'false') return false;
    return num.tryParse(v) ?? v;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final attrs = <String, dynamic>{};
    final rels = <String, (String, String)>{};

    for (final f in _fields) {
      final text = _ctrls[f.key]?.text.trim() ?? '';
      final had = existing?.attributes[f.key] != null;
      switch (f.type) {
        case FieldType.text:
        case FieldType.multiline:
        case FieldType.password:
          if (text.isNotEmpty) {
            attrs[f.key] = text;
          } else if (editing && had) {
            attrs[f.key] = null;
          }
        case FieldType.integer:
          if (text.isNotEmpty) {
            attrs[f.key] = int.parse(text);
          } else if (editing && had) {
            attrs[f.key] = null;
          }
        case FieldType.durationDays:
          if (text.isNotEmpty) {
            attrs[f.key] = (double.parse(text) * 86400).round();
          } else if (editing && had) {
            attrs[f.key] = null;
          }
        case FieldType.boolean:
          attrs[f.key] = _values[f.key] as bool;
        case FieldType.choice:
          final v = _values[f.key] as String?;
          if (v != null) attrs[f.key] = v;
        case FieldType.dateTime:
          final d = _values[f.key] as DateTime?;
          if (d != null) {
            attrs[f.key] = d.toUtc().toIso8601String();
          } else if (editing && had) {
            attrs[f.key] = null;
          }
        case FieldType.metadata:
          final m = {
            for (final (k, v) in _meta)
              if (k.text.trim().isNotEmpty)
                k.text.trim(): _parseMetaValue(v.text.trim())
          };
          if (m.isNotEmpty || (editing && existing!.metadata.isNotEmpty)) {
            attrs[f.key] = m;
          }
        case FieldType.relation:
          final rel = _values[f.key] as Resource?;
          if (rel != null) rels[f.key] = (rel.type, rel.id);
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final api = context.read<Session>().api;
    try {
      final saved = editing
          ? await api.update(kind.path, existing!.type, existing!.id, attrs)
          : await api.create(kind.path, kind.path, attrs, relationships: rels);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(FieldSpec f) async {
    final now = DateTime.now();
    final current = _values[f.key] as DateTime?;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(current ?? DateTime(2000, 1, 1, 23, 59)));
    if (!mounted) return;
    final t = time ?? const TimeOfDay(hour: 23, minute: 59);
    setState(() => _values[f.key] =
        DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  Future<void> _pickRelation(FieldSpec f) async {
    final picked = await showModalBottomSheet<Resource>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RelationPicker(kind: kinds[f.relationPath]!),
    );
    if (picked != null) setState(() => _values[f.key] = picked);
  }

  Widget _field(FieldSpec f) {
    final label = f.required ? '${f.label} *' : f.label;
    String? required(String? v) =>
        f.required && (v == null || v.trim().isEmpty) ? 'Required' : null;

    switch (f.type) {
      case FieldType.text:
      case FieldType.multiline:
      case FieldType.password:
        return TextFormField(
          controller: _ctrls[f.key],
          obscureText: f.type == FieldType.password,
          maxLines: f.type == FieldType.multiline ? 4 : 1,
          autocorrect: false,
          decoration: InputDecoration(labelText: label, helperText: f.helper),
          validator: required,
        );
      case FieldType.integer:
      case FieldType.durationDays:
        final isInt = f.type == FieldType.integer;
        return TextFormField(
          controller: _ctrls[f.key],
          keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
          decoration: InputDecoration(labelText: label, helperText: f.helper),
          validator: (v) {
            final r = required(v);
            if (r != null) return r;
            if (v == null || v.trim().isEmpty) return null;
            return (isInt
                        ? int.tryParse(v.trim())
                        : double.tryParse(v.trim())) ==
                    null
                ? 'Enter a number'
                : null;
          },
        );
      case FieldType.boolean:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          subtitle: f.helper == null ? null : Text(f.helper!),
          value: _values[f.key] as bool,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case FieldType.choice:
        return DropdownButtonFormField<String?>(
          initialValue: _values[f.key] as String?,
          decoration: InputDecoration(labelText: label, helperText: f.helper),
          items: [
            const DropdownMenuItem(value: null, child: Text('Default')),
            for (final c in f.choices)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case FieldType.dateTime:
        final d = _values[f.key] as DateTime?;
        return InkWell(
          onTap: () => _pickDate(f),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              helperText: f.helper,
              suffixIcon: d == null
                  ? const Icon(Icons.event)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _values[f.key] = null)),
            ),
            child: Text(
                d == null ? 'None' : DateFormat.yMMMd().add_jm().format(d)),
          ),
        );
      case FieldType.relation:
        final rel = _values[f.key] as Resource?;
        final rk = kinds[f.relationPath]!;
        return FormField<Resource>(
          validator: (_) => f.required && rel == null
              ? 'Choose a ${rk.singular.toLowerCase()}'
              : null,
          builder: (state) => InkWell(
            onTap: () async {
              await _pickRelation(f);
              state.didChange(_values[f.key] as Resource?);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                helperText: f.helper,
                errorText: state.errorText,
                suffixIcon: rel == null || f.required
                    ? const Icon(Icons.arrow_drop_down)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _values[f.key] = null)),
              ),
              child: Text(rel == null ? 'Choose…' : rk.title(rel)),
            ),
          ),
        );
      case FieldType.metadata:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.label, style: Theme.of(context).textTheme.titleSmall),
          if (f.helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(f.helper!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 8),
          for (final (i, row) in _meta.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: row.$1,
                        autocorrect: false,
                        decoration: const InputDecoration(
                            labelText: 'Key', isDense: true))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: row.$2,
                        autocorrect: false,
                        decoration: const InputDecoration(
                            labelText: 'Value', isDense: true))),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() => _meta.removeAt(i)),
                ),
              ]),
            ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add field'),
            onPressed: () => setState(() =>
                _meta.add((TextEditingController(), TextEditingController()))),
          ),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing
            ? 'Edit ${kind.singular.toLowerCase()}'
            : 'New ${kind.singular.toLowerCase()}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(editing ? 'Save' : 'Create'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            for (final f in _fields) ...[
              _field(f),
              const SizedBox(height: 16),
            ],
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
    );
  }
}

class _RelationPicker extends StatefulWidget {
  const _RelationPicker({required this.kind});
  final ResourceKind kind;

  @override
  State<_RelationPicker> createState() => _RelationPickerState();
}

class _RelationPickerState extends State<_RelationPicker> {
  late final Future<ResourcePage> _future =
      context.read<Session>().api.list(widget.kind.path, size: 100);

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: FutureBuilder<ResourcePage>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView('${snap.error}');
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final items = snap.data!.items;
          if (items.isEmpty) {
            return EmptyView(k.icon, 'No ${k.plural.toLowerCase()} yet',
                subtitle: 'Create one first, then come back.');
          }
          return ListView(children: [
            for (final r in items)
              ListTile(
                leading: Icon(k.icon),
                title: Text(k.title(r)),
                subtitle: Text(k.subtitle(r)),
                onTap: () => Navigator.of(context).pop(r),
              ),
          ]);
        },
      ),
    );
  }
}
