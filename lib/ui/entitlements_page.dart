import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/keygen_client.dart';
import '../resources/kinds.dart';
import '../state/session.dart';
import 'resource_detail_page.dart';
import 'util.dart';
import 'widgets.dart';

/// Manage the parent's assignments, independently of entitlement definitions.
class EntitlementsPage extends StatefulWidget {
  const EntitlementsPage({super.key, required this.parent, required this.kind});
  final Resource parent;
  final ResourceKind kind;

  @override
  State<EntitlementsPage> createState() => _EntitlementsPageState();
}

class _EntitlementsPageState extends State<EntitlementsPage> {
  List<Resource> _items = [];
  Set<String> _inherited = {};
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;

  KeygenClient get _api => context.read<Session>().api;
  bool get _license => widget.kind.path == 'licenses';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Re-read the parent: a licence may have moved to another policy.
      final parent = await _api.get(widget.kind.path, widget.parent.id);
      final items =
          await _api.listAll('${widget.kind.path}/${parent.id}/entitlements');
      final inherited = <String>{};
      if (_license) {
        final policyId = parent.relId('policy');
        if (policyId == null) {
          throw ApiException(
              'The licence policy could not be identified. Refresh to try again.');
        }
        inherited.addAll((await _api.listAll('policies/$policyId/entitlements'))
            .map((e) => e.id));
      }
      if (mounted) {
        setState(() {
          _items = items;
          _inherited = inherited;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _attach() async {
    setState(() => _busy = true);
    try {
      final all = await _api.listAll('entitlements');
      if (!mounted) return;
      final assigned = {..._items.map((e) => e.id), ..._inherited};
      final available = all.where((e) => !assigned.contains(e.id)).toList();
      final picked = await Navigator.of(context).push<Resource>(
          MaterialPageRoute(
              builder: (_) => _EntitlementPicker(items: available)));
      if (picked == null || !mounted) return;
      final ok = await confirm(
          context,
          'Attach entitlement?',
          '${kinds['entitlements']!.title(picked)} will be granted to '
              '${_license ? 'this licence' : 'all licences using this policy'} '
              'on future validations.',
          action: 'Attach');
      if (!ok || !mounted) return;
      await _api.setEntitlement(widget.kind.path, widget.parent.id, picked.id,
          attached: true);
      _changed = true;
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _detach(Resource item) async {
    if (_inherited.contains(item.id)) return;
    final ok = await confirm(
        context,
        'Detach entitlement?',
        '${kinds['entitlements']!.title(item)} will be removed from '
            '${_license ? 'this licence' : 'all licences using this policy'} '
            'on future validations. The entitlement definition will be kept.',
        action: 'Detach',
        destructive: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.setEntitlement(widget.kind.path, widget.parent.id, item.id,
          attached: false);
      _changed = true;
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Resource item) async {
    final changed = await Navigator.of(context).push<Object?>(MaterialPageRoute(
        builder: (_) =>
            ResourceDetailPage(kind: kinds['entitlements']!, resource: item)));
    if (changed != null && mounted) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = kinds['entitlements']!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) {
          Navigator.of(context).pop(_changed ? true : null);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Entitlements'), actions: [
          IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _busy || _loading ? null : _load),
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _error != null
                ? ErrorView(_error!, onRetry: _load)
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(widget.kind.title(widget.parent),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(_license
                        ? 'Policy entitlements are inherited. Manage those on the policy; attach extra features directly to this licence.'
                        : 'Entitlements on this policy are inherited by every licence using it.'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: _busy ? null : _attach,
                        icon: const Icon(Icons.add),
                        label: const Text('Attach entitlement')),
                    if (_busy) const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    if (_items.isEmpty)
                      const Panel(child: Text('No entitlements attached.'))
                    else
                      RowsPanel([
                        for (final item in _items)
                          ListTile(
                            title: Text(kind.title(item)),
                            subtitle: Text('${kind.subtitle(item)}\n'
                                '${_inherited.contains(item.id) ? 'Inherited from policy' : 'Attached to ${widget.kind.singular.toLowerCase()}'}'),
                            isThreeLine: true,
                            onTap: _busy ? null : () => _open(item),
                            trailing: _inherited.contains(item.id)
                                ? const Tooltip(
                                    message: 'Manage on the policy',
                                    child: Icon(Icons.policy_outlined))
                                : IconButton(
                                    tooltip: 'Detach entitlement',
                                    icon: const Icon(Icons.link_off),
                                    onPressed:
                                        _busy ? null : () => _detach(item)),
                          ),
                      ]),
                  ]),
      ),
    );
  }
}

class _EntitlementPicker extends StatefulWidget {
  const _EntitlementPicker({required this.items});
  final List<Resource> items;
  @override
  State<_EntitlementPicker> createState() => _EntitlementPickerState();
}

class _EntitlementPickerState extends State<_EntitlementPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final kind = kinds['entitlements']!;
    final shown = widget.items.where((e) =>
        '${kind.title(e)} ${kind.subtitle(e)}'.toLowerCase().contains(_query));
    return Scaffold(
      appBar: AppBar(title: const Text('Choose entitlement')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                  hintText: 'Search entitlements',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (s) => setState(() => _query = s.trim().toLowerCase()),
            )),
        Expanded(
            child: shown.isEmpty
                ? const EmptyView(
                    Icons.verified_outlined, 'No available entitlements',
                    subtitle:
                        'Create entitlement definitions from More → Entitlements. Already granted features are excluded.')
                : ListView(children: [
                    for (final item in shown)
                      ListTile(
                          title: Text(kind.title(item)),
                          subtitle: Text(kind.subtitle(item)),
                          onTap: () => Navigator.pop(context, item)),
                  ])),
      ]),
    );
  }
}
