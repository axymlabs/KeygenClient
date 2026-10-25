import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/keygen_client.dart';
import '../resources/kinds.dart';
import '../state/session.dart';
import 'resource_detail_page.dart';
import 'util.dart';
import 'widgets.dart';

/// Observes server-reported activity. Viewing a machine must never ping its
/// heartbeat or check in its licence on behalf of the licensed device.
class MachineActivity extends StatefulWidget {
  const MachineActivity({super.key, required this.machine});
  final Resource machine;
  @override
  State<MachineActivity> createState() => _MachineActivityState();
}

class _MachineActivityState extends State<MachineActivity> {
  Resource? _license;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    final id = widget.machine.relId('license');
    if (id == null) {
      setState(() {
        _error = 'No licence was reported for this machine.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final license = await context.read<Session>().api.get('licenses', id);
      if (mounted) setState(() => _license = license);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _time(Resource r, String key) =>
      r.str(key) == null ? 'Not reported' : formatValue(key, r.str(key));

  @override
  Widget build(BuildContext context) {
    final r = widget.machine;
    final license = _license;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Machine heartbeat'),
      RowsPanel([
        DataRow2(
            'Status',
            r.str('heartbeatStatus') == null
                ? 'Not reported'
                : humanize(r.str('heartbeatStatus')!)),
        DataRow2(
            'Heartbeat required',
            r.boolVal('requireHeartbeat') == null
                ? 'Not reported'
                : formatValue(
                    'requireHeartbeat', r.boolVal('requireHeartbeat'))),
        DataRow2('Last heartbeat', _time(r, 'lastHeartbeat')),
        DataRow2('Next heartbeat due', _time(r, 'nextHeartbeat')),
        if (r.intVal('heartbeatDuration') != null)
          DataRow2(
              'Heartbeat window', '${r.intVal('heartbeatDuration')} seconds'),
        if (r.str('lastCheckOut') != null)
          DataRow2('Last machine checkout', _time(r, 'lastCheckOut')),
      ]),
      const SectionHeader('Licence check-ins'),
      if (_loading)
        const LinearProgressIndicator()
      else if (_error != null)
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_error!),
          TextButton(onPressed: _loadLicense, child: const Text('Try again')),
        ]))
      else if (license != null) ...[
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
                'Check-ins belong to the licence shared by its machines. These times do not identify which machine checked in.')),
        RowsPanel([
          DataRow2(
              'Check-in required',
              license.boolVal('requireCheckIn') == null
                  ? 'Not reported'
                  : formatValue(
                      'requireCheckIn', license.boolVal('requireCheckIn'))),
          DataRow2('Last check-in', _time(license, 'lastCheckIn')),
          DataRow2('Next check-in due', _time(license, 'nextCheckIn')),
          DataRow2('Last validation', _time(license, 'lastValidated')),
          ListTile(
              title: const Text('Open licence'),
              subtitle: Text(kinds['licenses']!.title(license)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ResourceDetailPage(
                        kind: kinds['licenses']!, resource: license)));
                if (mounted) _loadLicense();
              }),
        ]),
      ],
    ]);
  }
}
