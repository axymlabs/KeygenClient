import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/keygen_client.dart';
import '../resources/kinds.dart';
import '../state/session.dart';
import 'resource_detail_page.dart';
import 'resource_form_page.dart';
import '../theme.dart';
import 'util.dart';
import 'widgets.dart';

class ResourceListPage extends StatefulWidget {
  const ResourceListPage({super.key, required this.kind, this.pushed = false});

  final ResourceKind kind;

  /// True when shown as its own route (adds a back button automatically).
  final bool pushed;

  @override
  State<ResourceListPage> createState() => _ResourceListPageState();
}

class _ResourceListPageState extends State<ResourceListPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _items = <Resource>[];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;
  String _query = '';

  ResourceKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page =
          await context.read<Session>().api.list(kind.path, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(page.items);
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    _items.clear();
    _page = 0;
    _hasMore = true;
    await _loadMore();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Resource>(
        MaterialPageRoute(builder: (_) => ResourceFormPage(kind: kind)));
    if (created != null && mounted) {
      await _refresh();
      if (!mounted) return;
      _open(created);
    }
  }

  Future<void> _open(Resource r) async {
    final result = await Navigator.of(context).push<Object?>(MaterialPageRoute(
        builder: (_) => ResourceDetailPage(kind: kind, resource: r)));
    if (result != null) _refresh(); // changed or deleted
  }

  Future<bool> _confirmDelete(Resource r) async {
    final ok = await confirm(
        context,
        '${kind.deleteLabel} ${kind.singular.toLowerCase()}?',
        kind.path == 'entitlements'
            ? '${kind.title(r)} will be deleted for every licence and policy using it. This may remove access to the feature.'
            : kind.title(r),
        action: kind.deleteLabel,
        destructive: true);
    if (!ok || !mounted) return false;
    try {
      await context.read<Session>().api.delete(kind.path, r.id);
      return true;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
      return false;
    }
  }

  Widget _row(BuildContext context, List<Resource> shown, int i) {
    final cs = Theme.of(context).colorScheme;
    if (i >= shown.length) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _error != null
              ? TextButton(onPressed: _loadMore, child: Text('$_error  Retry'))
              : const CircularProgressIndicator.adaptive(),
        ),
      );
    }
    final r = shown[i];
    final status = kind.path == 'licenses'
        ? r.str('status')
        : kind.path == 'machines'
            ? r.str('heartbeatStatus')
            : null;
    final statusColorValue = status == null ? null : statusColor(status, cs);
    final statusChip =
        status == null ? null : _ListStatus(status, color: statusColorValue!);
    final stackStatus =
        statusChip != null && MediaQuery.textScalerOf(context).scale(12) > 18;
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cs.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        final done = await _confirmDelete(r);
        if (done) setState(() => _items.removeWhere((e) => e.id == r.id));
        return false; // list already updated manually
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: IconTile(kind.icon, tint: statusColorValue),
        title: Text(kind.title(r),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: stackStatus
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _subtitle(context, r),
                  const SizedBox(height: 4),
                  statusChip,
                ],
              )
            : _subtitle(context, r),
        trailing: stackStatus
            ? null
            : statusChip ??
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: () => _open(r),
      ),
    );
  }

  Widget _subtitle(BuildContext context, Resource resource) {
    final cs = Theme.of(context).colorScheme;
    if (kind.path != 'licenses') {
      return Text(kind.subtitle(resource),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              AppTheme.mono(context, size: 11.5, color: cs.onSurfaceVariant));
    }

    final key = resource.str('key') ?? '';
    final keyTail = key.isEmpty
        ? ''
        : '…${key.length > 4 ? key.substring(key.length - 4) : key}';
    final expiry = resource.date('expiry')?.toLocal();
    final expiryLabel = expiry == null
        ? 'No expiry'
        : expiry.isBefore(DateTime.now())
            ? 'Expired ${relativeDays(expiry)}'
            : 'Expires ${relativeDays(expiry)}';
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      children: [
        if (keyTail.isNotEmpty)
          Text(keyTail,
              maxLines: 1,
              style: AppTheme.mono(context,
                  size: 11.5, color: cs.onSurfaceVariant)),
        Text(expiryLabel,
            maxLines: 1,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }

  /// Height of the bottom navigation bar this page sits behind, or 0 when the
  /// page is pushed or the layout uses a side rail.
  double _navClearance(BuildContext context) {
    if (widget.pushed || MediaQuery.sizeOf(context).width >= 720) return 0;
    final inset = MediaQueryData.fromView(View.of(context)).padding.bottom;
    return 64 + inset;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _query.toLowerCase();
    final shown = q.isEmpty
        ? _items
        : _items
            .where((r) => '${kind.title(r)} ${kind.subtitle(r)}'
                .toLowerCase()
                .contains(q))
            .toList();

    Widget fill(Widget child) =>
        SliverFillRemaining(hasScrollBody: false, child: child);

    final List<Widget> body;
    if (_items.isEmpty && _loading) {
      body = [fill(const Center(child: CircularProgressIndicator.adaptive()))];
    } else if (_items.isEmpty && _error != null) {
      body = [fill(ErrorView(_error!, onRetry: _refresh))];
    } else if (shown.isEmpty) {
      body = [
        fill(EmptyView(
          kind.icon,
          q.isEmpty ? 'No ${kind.plural.toLowerCase()} yet' : 'No matches',
          subtitle: q.isEmpty && kind.canCreate
              ? 'Tap “New ${kind.singular.toLowerCase()}” to add one.'
              : null,
        ))
      ];
    } else {
      final extra = _hasMore || _error != null ? 1 : 0;
      body = [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < shown.length + extra; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                  _row(context, shown, i),
                ],
              ]),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ];
    }

    return LargeTitleScroll(
      title: kind.plural,
      showBack: widget.pushed,
      controller: _scroll,
      onRefresh: _refresh,
      floatingActionButton: kind.canCreate
          ? Padding(
              // Tab pages sit behind the bottom navigation bar; lift the
              // button clear of it.
              padding: EdgeInsets.only(bottom: _navClearance(context)),
              child: FloatingActionButton.extended(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: Text('New ${kind.singular.toLowerCase()}'),
              ),
            )
          : null,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search ${kind.plural.toLowerCase()}',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                isDense: true,
              ),
            ),
          ),
        ),
        ...body,
      ],
    );
  }
}

class _ListStatus extends StatelessWidget {
  const _ListStatus(this.status, {required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = status.toLowerCase();
    final label = value.isEmpty
        ? value
        : '${value[0].toUpperCase()}${value.substring(1)}';
    final icon = switch (status.toUpperCase()) {
      'ACTIVE' || 'ALIVE' || 'RESURRECTED' => Icons.check_circle_outline,
      'EXPIRING' => Icons.schedule_outlined,
      'EXPIRED' || 'DEAD' => Icons.event_busy_outlined,
      'SUSPENDED' => Icons.pause_circle_outline,
      _ => Icons.info_outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
