import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../resources/kinds.dart';
import '../api/keygen_client.dart';
import '../state/device_activity.dart';
import '../state/session.dart';
import 'resource_detail_page.dart';
import 'widgets.dart';
import 'heartbeat_chart.dart';

class DeviceActivityPanel extends StatefulWidget {
  const DeviceActivityPanel({super.key});

  @override
  State<DeviceActivityPanel> createState() => _DeviceActivityPanelState();
}

class _DeviceActivityPanelState extends State<DeviceActivityPanel> {
  late Future<DeviceActivity> _future;

  @override
  void initState() {
    super.initState();
    _future = DeviceActivity.load(context.read<Session>().api);
  }

  void _refresh() => setState(() {
        _future = DeviceActivity.load(context.read<Session>().api);
      });

  void _open(DeviceActivity activity, bool heartbeat,
      {List<Resource>? devices, String? heading}) {
    final ids =
        heartbeat ? activity.overdueHeartbeats : activity.overdueLicenceDevices;
    final items =
        devices ?? activity.machines.where((m) => ids.contains(m.id)).toList();
    final kind = kinds['machines']!;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
              appBar: AppBar(
                  title: Text(heading ??
                      (heartbeat
                          ? 'Overdue heartbeats'
                          : 'Overdue licence check-ins'))),
              body: ListView(padding: const EdgeInsets.all(16), children: [
                Text(devices != null
                    ? 'Devices grouped by their latest server-reported heartbeat state.'
                    : heartbeat
                        ? 'Machines whose heartbeat deadline has passed or whose server status is dead.'
                        : 'Devices attached to licences with an overdue check-in. A check-in applies to the whole licence.'),
                const SizedBox(height: 12),
                Text(
                    'As of ${DateFormat.yMMMd().add_jm().format(activity.checkedAt)}'),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Panel(child: Text('No matching devices.'))
                else
                  RowsPanel([
                    for (final m in items)
                      ListTile(
                          title: Text(kind.title(m)),
                          subtitle: Text(kind.subtitle(m)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => ResourceDetailPage(
                                      kind: kind, resource: m)))),
                  ]),
              ]),
            )));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DeviceActivity>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Panel(
                child: Row(children: [
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Expanded(child: Text('Checking device activity…')),
            ]));
          }
          if (snap.hasError) {
            return Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Device activity unavailable'),
                  const SizedBox(height: 6),
                  Text('${snap.error}'),
                  TextButton(
                      onPressed: _refresh, child: const Text('Try again')),
                ]));
          }
          final data = snap.data!;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeartbeatChart(
                    activity: data,
                    onOpen: (devices, title) =>
                        _open(data, true, devices: devices, heading: title)),
                const SizedBox(height: 12),
                RowsPanel([
                  ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Devices on overdue licences'),
                      subtitle: const Text('Licence check-in deadline passed'),
                      trailing: Text('${data.overdueLicenceDevices.length}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      onTap: () => _open(data, false)),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Checked ${data.machines.length} devices at ${DateFormat.jm().format(data.checkedAt)}. Pull to refresh.'),
                            if (data.missingLicenceLinks > 0)
                              Text(
                                  '${data.missingLicenceLinks} devices have no readable licence; their check-in status is unknown.'),
                          ])),
                ]),
              ]);
        },
      );
}
