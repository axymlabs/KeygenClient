import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/keygen_client.dart';
import '../resources/kinds.dart';
import '../state/session.dart';
import 'resource_form_page.dart';
import 'entitlements_page.dart';
import 'machine_activity.dart';
import 'share_license_page.dart';
import '../theme.dart';
import 'charts.dart';
import 'util.dart';
import 'widgets.dart';

/// Pops with `true` if the resource was changed or deleted so lists can refresh.
class ResourceDetailPage extends StatefulWidget {
  const ResourceDetailPage(
      {super.key, required this.kind, required this.resource});

  final ResourceKind kind;
  final Resource resource;

  @override
  State<ResourceDetailPage> createState() => _ResourceDetailPageState();
}

class _ResourceDetailPageState extends State<ResourceDetailPage> {
  late Resource _r = widget.resource;
  bool _changed = false;
  bool _busy = false;

  ResourceKind get kind => widget.kind;
  KeygenClient get _api => context.read<Session>().api;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final fresh = await _api.get(kind.path, _r.id);
      if (mounted) setState(() => _r = fresh);
    } on ApiException catch (_) {
      // Keep showing what we have.
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Resource>(
        MaterialPageRoute(
            builder: (_) => ResourceFormPage(kind: kind, existing: _r)));
    if (updated != null) {
      _changed = true;
      setState(() => _r = updated);
      _reload();
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
        context,
        '${kind.deleteLabel} ${kind.singular.toLowerCase()}?',
        kind.path == 'entitlements'
            ? '${kind.title(_r)} will be deleted for every licence and policy using it. This may remove access to the feature.'
            : kind.title(_r),
        action: kind.deleteLabel,
        destructive: true);
    if (!ok || !mounted) return;
    try {
      await _api.delete(kind.path, _r.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _runAction(ActionSpec a) async {
    if (a.confirm) {
      final ok = await confirm(context, '${a.label}?', kind.title(_r),
          action: a.label);
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final updated = await _api.actionResource(kind.path, _r.id, a.action);
      _changed = true;
      if (mounted) {
        setState(() => _r = updated);
        showSnack(context, '${a.label} done');
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _hero(BuildContext context, String? status) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final color = status == null ? cs.primary : statusColor(status, cs);
    final expiry = _r.date('expiry');
    final created = _r.date('created');
    final showRing =
        kind.path == 'licenses' && expiry != null && created != null;
    double progress = 0;
    var daysLeft = 0;
    if (showRing) {
      final total = expiry.difference(created).inSeconds;
      final used = DateTime.now().difference(created).inSeconds;
      progress = total <= 0 ? 1 : (1 - used / total).clamp(0, 1).toDouble();
      daysLeft = expiry.difference(DateTime.now()).inDays;
    }
    return Panel(
      glow: color,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Caps(kind.singular),
            const SizedBox(height: 8),
            Text(kind.title(_r), style: t.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (status != null) StatusPill(status),
                  if (kind.path != 'licenses')
                    Text(kind.subtitle(_r),
                        style: t.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  if (kind.path == 'licenses')
                    Text(
                        expiry == null
                            ? 'Never expires'
                            : '${expiry.isBefore(DateTime.now()) ? 'Expired' : 'Expires'} ${relativeDays(expiry)}',
                        style: t.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                ]),
          ]),
        ),
        if (showRing) ...[
          const SizedBox(width: 12),
          RingGauge(
            progress: progress,
            color: color,
            size: 92,
            center: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(daysLeft < 0 ? '0' : '$daysLeft',
                  style: AppTheme.mono(context,
                      size: 22, weight: FontWeight.w600)),
              Text('DAYS LEFT',
                  style: TextStyle(
                      fontSize: 8.5,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant)),
            ]),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isLicense = kind.path == 'licenses';
    final isMachine = kind.path == 'machines';
    final skip = {
      'metadata',
      if (isLicense) ...['key', 'status', 'lastCheckIn', 'nextCheckIn'],
      if (isMachine) ...[
        'heartbeatStatus',
        'requireHeartbeat',
        'lastHeartbeat',
        'nextHeartbeat',
        'heartbeatDuration',
        'lastCheckOut'
      ],
    };
    final attrs = _r.attributes.entries
        .where((e) =>
            !skip.contains(e.key) &&
            e.value != null &&
            e.value is! Map &&
            e.value is! List)
        .toList();
    final meta = _r.metadata;
    final actions =
        kind.actions.where((a) => a.visible?.call(_r) ?? true).toList();
    final status = isLicense
        ? _r.str('status')
        : isMachine
            ? _r.str('heartbeatStatus')
            : null;
    final licenseKey = isLicense ? _r.str('key') : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed ? true : null);
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: _edit),
            IconButton(
                icon: Icon(Icons.delete_outline, color: cs.error),
                tooltip: kind.deleteLabel,
                onPressed: _delete),
          ],
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2))
              : null,
        ),
        body: Stack(children: [
          const Positioned.fill(child: Glow()),
          Positioned.fill(
              child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                Reveal(child: _hero(context, status)),
                if (licenseKey != null) ...[
                  const SizedBox(height: 20),
                  Panel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Caps('Licence key'),
                              const SizedBox(height: 6),
                              SelectableText(licenseKey,
                                  style: AppTheme.mono(context, size: 14)),
                            ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy key',
                        onPressed: () =>
                            copyText(context, licenseKey, 'Key copied'),
                      ),
                    ]),
                  ),
                ],
                if (isLicense) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Share licence'),
                    style: FilledButton.styleFrom(
                        backgroundColor: cs.onSurface,
                        foregroundColor: cs.surface),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ShareLicensePage(license: _r))),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final a in actions)
                      ActionChip(
                        avatar: Icon(a.icon, size: 16),
                        label: Text(a.label),
                        onPressed: _busy ? null : () => _runAction(a),
                      ),
                  ]),
                ],
                if (isLicense || kind.path == 'policies') ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Manage entitlements'),
                    onPressed: _busy
                        ? null
                        : () async {
                            final changed = await Navigator.of(context)
                                .push<Object?>(MaterialPageRoute(
                                    builder: (_) => EntitlementsPage(
                                        parent: _r, kind: kind)));
                            if (changed != null && mounted) {
                              _changed = true;
                              await _reload();
                            }
                          },
                  ),
                ],
                if (isMachine) MachineActivity(key: ObjectKey(_r), machine: _r),
                const SectionHeader('Details'),
                RowsPanel([
                  if (isLicense) ...[
                    DataRow2(
                        'Last check-in',
                        _r.str('lastCheckIn') == null
                            ? 'Never'
                            : formatValue(
                                'lastCheckIn', _r.str('lastCheckIn'))),
                    if (_r.str('nextCheckIn') != null)
                      DataRow2('Next check-in due',
                          formatValue('nextCheckIn', _r.str('nextCheckIn'))),
                  ],
                  for (final e in attrs)
                    DataRow2(humanize(e.key), formatValue(e.key, e.value),
                        mono: e.value is num ||
                            (e.value is String && e.key != 'name')),
                  DataRow2('ID', _r.id,
                      mono: true,
                      onLongPress: () => copyText(context, _r.id, 'ID copied')),
                ]),
                if (meta.isNotEmpty) ...[
                  const SectionHeader('Metadata'),
                  RowsPanel([
                    for (final e in meta.entries)
                      DataRow2(e.key, '${e.value}', mono: true),
                  ]),
                ],
                for (final rel in kind.related)
                  _RelatedSection(parent: _r, parentKind: kind, spec: rel),
              ],
            ),
          )),
        ]),
      ),
    );
  }
}

class _RelatedSection extends StatefulWidget {
  const _RelatedSection(
      {required this.parent, required this.parentKind, required this.spec});
  final Resource parent;
  final ResourceKind parentKind;
  final RelatedSpec spec;

  @override
  State<_RelatedSection> createState() => _RelatedSectionState();
}

class _RelatedSectionState extends State<_RelatedSection> {
  late final Future<ResourcePage> _future = context.read<Session>().api.list(
      '${widget.parentKind.path}/${widget.parent.id}/${widget.spec.suffix}',
      size: 10);

  @override
  Widget build(BuildContext context) {
    final kind = kinds[widget.spec.kindPath]!;
    final t = Theme.of(context);
    return FutureBuilder<ResourcePage>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final items = snap.data!.items;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(widget.spec.label),
          if (items.isEmpty)
            Panel(
                child: Text('None',
                    style: TextStyle(color: t.colorScheme.onSurfaceVariant)))
          else
            RowsPanel([
              for (final r in items)
                ListTile(
                  title: Text(kind.title(r),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(kind.subtitle(r),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ResourceDetailPage(kind: kind, resource: r))),
                ),
            ]),
        ]);
      },
    );
  }
}
