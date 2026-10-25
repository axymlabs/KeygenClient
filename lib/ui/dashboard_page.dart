import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/keygen_client.dart';
import '../resources/kinds.dart';
import '../state/session.dart';
import '../theme.dart';
import 'resource_detail_page.dart';
import 'resource_list_page.dart';
import 'charts.dart';
import 'device_activity_panel.dart';
import 'util.dart';
import 'widgets.dart';

class _DashData {
  _DashData(this.counts, this.licenses);
  final Map<String, int> counts;
  final List<Resource> licenses;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onOpenTab});

  /// Tab indices: 1 licences, 2 policies, 3 products.
  final void Function(int) onOpenTab;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashData> _load() async {
    final api = context.read<Session>().api;
    const paths = ['licenses', 'policies', 'products', 'machines', 'users'];
    final results = await Future.wait([
      ...paths.map(api.count),
      api.list('licenses', size: 100),
    ]);
    return _DashData(
      {for (var i = 0; i < paths.length; i++) paths[i]: results[i] as int},
      (results.last as ResourcePage).items,
    );
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final cs = Theme.of(context).colorScheme;
    final host = Uri.tryParse(s.serverUrl)?.host ?? s.serverUrl;
    return LargeTitleScroll(
      title: 'Overview',
      onRefresh: _refresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<_DashData>(
              future: _future,
              builder: (context, snap) {
                final status = Row(children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: snap.hasError
                          ? cs.error
                          : snap.hasData
                              ? const Color(0xFF34C759)
                              : cs.outline,
                      shape: BoxShape.circle,
                      boxShadow: snap.hasData
                          ? [
                              const BoxShadow(
                                  color: Color(0x6634C759), blurRadius: 8)
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.account.isEmpty ? host : '$host / ${s.account}',
                    style: AppTheme.mono(context,
                        size: 12, color: cs.onSurfaceVariant),
                  ),
                ]);
                if (snap.connectionState != ConnectionState.done) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        status,
                        const Padding(
                            padding: EdgeInsets.only(top: 120),
                            child: Center(
                                child: CircularProgressIndicator.adaptive())),
                      ]);
                }
                if (snap.hasError) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        status,
                        SizedBox(
                            height: 360,
                            child:
                                ErrorView('${snap.error}', onRetry: _refresh)),
                      ]);
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      status,
                      const SizedBox(height: 16),
                      ..._content(context, snap.data!)
                    ]);
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context, _DashData d) {
    final cs = Theme.of(context).colorScheme;
    final stats = [
      ('licenses', 'Licences', Icons.vpn_key_rounded, 1),
      ('policies', 'Policies', Icons.policy_rounded, 2),
      ('products', 'Products', Icons.inventory_2_rounded, 3),
      ('machines', 'Machines', Icons.computer_rounded, null),
      ('users', 'Users', Icons.person_rounded, null),
    ];

    final statusCounts = <String, int>{};
    for (final l in d.licenses) {
      final s = (l.str('status') ?? 'UNKNOWN').toUpperCase();
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }
    final soon = DateTime.now().add(const Duration(days: 30));
    final expiring = d.licenses.where((l) {
      final e = l.date('expiry');
      return e != null && e.isAfter(DateTime.now()) && e.isBefore(soon);
    }).toList()
      ..sort((a, b) => a.date('expiry')!.compareTo(b.date('expiry')!));

    var i = 0;
    Widget r(Widget w) => Reveal(index: i++, child: w);

    return [
      r(_Hero(d, statusCounts)),
      const SizedBox(height: 12),
      r(_Attention(statusCounts, onTap: () => widget.onOpenTab(1))),
      r(const SectionHeader('Device activity')),
      r(const DeviceActivityPanel()),
      r(const SectionHeader('Inventory')),
      r(SizedBox(
        height: 124,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: stats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, n) {
            final s = stats[n];
            return SizedBox(
              width: 132,
              child: Panel(
                onTap: s.$4 == null
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            ResourceListPage(kind: kinds[s.$1]!, pushed: true)))
                    : () => widget.onOpenTab(s.$4!),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9)),
                        child: Icon(s.$3, size: 17, color: cs.primary),
                      ),
                      const Spacer(),
                      Text('${d.counts[s.$1]}',
                          style: AppTheme.mono(context,
                              size: 24, weight: FontWeight.w600)),
                      Text(s.$2,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ]),
              ),
            );
          },
        ),
      )),
      if (d.licenses.isNotEmpty) ...[
        r(const SectionHeader('Licence status')),
        r(_StatusPanel(statusCounts)),
        r(const SectionHeader('New licences · last 14 days')),
        r(_ActivityPanel(d.licenses)),
        r(const SectionHeader('Expiry outlook · next 6 months')),
        r(_ExpiryPanel(d.licenses)),
      ],
      r(SectionHeader('Expiring within 30 days',
          trailing: expiring.isEmpty ? null : Caps('${expiring.length}'))),
      r(expiring.isEmpty
          ? const _Quiet('Nothing is about to expire.')
          : RowsPanel([
              for (final l in expiring.take(5))
                _licenseRow(context, l, expiry: true)
            ])),
      r(const SectionHeader('Recent licences')),
      r(d.licenses.isEmpty
          ? const _Quiet('No licences yet.')
          : RowsPanel(
              [for (final l in d.licenses.take(5)) _licenseRow(context, l)])),
    ];
  }

  Widget _licenseRow(BuildContext context, Resource l, {bool expiry = false}) {
    final k = kinds['licenses']!;
    final cs = Theme.of(context).colorScheme;
    final e = l.date('expiry');
    return ListTile(
      title: Text(k.title(l), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        expiry && e != null ? DateFormat.yMMMd().format(e) : k.subtitle(l),
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      trailing: l.str('status') == null ? null : StatusPill(l.str('status')!),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ResourceDetailPage(kind: k, resource: l))),
    );
  }
}

/// Headline number with a 30-day growth curve.
class _Hero extends StatelessWidget {
  const _Hero(this.d, this.statusCounts);
  final _DashData d;
  final Map<String, int> statusCounts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = d.counts['licenses'] ?? 0;
    final active =
        (statusCounts['ACTIVE'] ?? 0) + (statusCounts['EXPIRING'] ?? 0);
    final sampled = total > d.licenses.length;

    // Cumulative licence count per day over the last 30 days.
    final today = DateTime.now();
    final startDay = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 29));
    final perDay = List<int>.filled(30, 0);
    for (final l in d.licenses) {
      final c = l.date('created');
      if (c == null) continue;
      final idx = DateTime(c.year, c.month, c.day).difference(startDay).inDays;
      if (idx >= 0 && idx < 30) perDay[idx]++;
    }
    final added = perDay.fold(0, (a, b) => a + b);
    var running = total - added;
    final series = [for (final n in perDay) (running += n).toDouble()];

    return Panel(
      glow: cs.primary,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Caps('Active licences'),
          const Spacer(),
          if (added > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.trending_up_rounded, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Text('+$added in 30 days',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.primary)),
              ]),
            ),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$active',
              style: AppTheme.mono(context, size: 56, weight: FontWeight.w600)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('of $total${sampled ? '+' : ''}',
                style: AppTheme.mono(context,
                    size: 15, color: cs.onSurfaceVariant)),
          ),
        ]),
        const SizedBox(height: 12),
        if (series.length > 1) LineChart(values: series, height: 88),
      ]),
    );
  }
}

/// Things that need a human: expired, expiring and suspended licences.
class _Attention extends StatelessWidget {
  const _Attention(this.counts, {required this.onTap});
  final Map<String, int> counts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      ('EXPIRED', 'Expired', Icons.event_busy_rounded),
      ('EXPIRING', 'Expiring', Icons.schedule_rounded),
      ('SUSPENDED', 'Suspended', Icons.pause_circle_rounded),
    ].where((e) => (counts[e.$1] ?? 0) > 0).toList();

    if (items.isEmpty) {
      return const Panel(
        child: Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF34C759)),
          SizedBox(width: 12),
          Expanded(child: Text('No licence status alerts.')),
        ]),
      );
    }
    return Row(children: [
      for (final (n, e) in items.indexed) ...[
        if (n > 0) const SizedBox(width: 10),
        Expanded(
          child: Panel(
            onTap: onTap,
            glow: statusColor(e.$1, cs),
            radius: 16,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(e.$3, size: 18, color: statusColor(e.$1, cs)),
              const SizedBox(height: 10),
              Text('${counts[e.$1]}',
                  style: AppTheme.mono(context,
                      size: 22, weight: FontWeight.w600)),
              Text(e.$2,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Panel(
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel(this.counts);
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = counts.values.fold(0, (a, b) => a + b);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          DonutChart(
            segments: [
              for (final e in entries)
                DonutSegment(e.value.toDouble(), statusColor(e.key, cs))
            ],
            centerValue: '$total',
            centerLabel: 'Licences',
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: statusColor(e.key, cs),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(humanize(e.key),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14))),
                    Text('${e.value}',
                        style: AppTheme.mono(context,
                            size: 14, weight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        ]),
        if (total >= 100)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Based on the most recent 100 licences',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ),
      ]),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel(this.licenses);
  final List<Resource> licenses;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 13));
    final buckets = List<double>.filled(14, 0);
    for (final l in licenses) {
      final c = l.date('created');
      if (c == null) continue;
      final i = DateTime(c.year, c.month, c.day).difference(start).inDays;
      if (i >= 0 && i < 14) buckets[i]++;
    }
    final total = buckets.fold<double>(0, (a, b) => a + b).toInt();
    final labels = [
      for (var i = 0; i < 14; i++)
        DateFormat.d().format(start.add(Duration(days: i)))
    ];
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$total',
              style: AppTheme.mono(context, size: 28, weight: FontWeight.w600)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('created',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ]),
        const SizedBox(height: 16),
        BarChart(values: buckets, labels: labels),
      ]),
    );
  }
}

class _ExpiryPanel extends StatelessWidget {
  const _ExpiryPanel(this.licenses);
  final List<Resource> licenses;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final buckets = List<double>.filled(6, 0);
    for (final l in licenses) {
      final e = l.date('expiry');
      if (e == null || e.isBefore(now)) continue;
      final i = (e.year * 12 + e.month) - (now.year * 12 + now.month);
      if (i >= 0 && i < 6) buckets[i]++;
    }
    final total = buckets.fold<double>(0, (a, b) => a + b).toInt();
    final labels = [
      for (var i = 0; i < 6; i++)
        DateFormat.MMM().format(DateTime(now.year, now.month + i))
    ];
    final cs = Theme.of(context).colorScheme;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$total',
              style: AppTheme.mono(context, size: 28, weight: FontWeight.w600)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child:
                Text('expiring', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ]),
        const SizedBox(height: 16),
        BarChart(
            values: buckets, labels: labels, color: const Color(0xFFFFB020)),
      ]),
    );
  }
}
