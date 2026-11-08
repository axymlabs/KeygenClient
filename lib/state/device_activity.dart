import '../api/keygen_client.dart';

enum HeartbeatGroup { onTime, overdue, notStarted, unmonitored, unknown }

/// A snapshot of the machines visible to this token, joined to their licences.
/// A licence check-in cannot identify which particular device checked in.
class DeviceActivity {
  DeviceActivity._(this.machines, this.overdueHeartbeats,
      this.overdueLicenceDevices, this.missingLicenceLinks, this.checkedAt);

  factory DeviceActivity.fromResources(
      List<Resource> machines, List<Resource> licences, DateTime now) {
    final overdueLicences = licences
        .where((r) {
          final due = r.date('nextCheckIn');
          return r.boolVal('requireCheckIn') != false &&
              due != null &&
              !due.isAfter(now);
        })
        .map((r) => r.id)
        .toSet();
    final heartbeats = <String>{};
    final checkIns = <String>{};
    var missingLinks = 0;
    final unique = {for (final r in machines) r.id: r}.values.toList();
    final knownLicences = licences.map((r) => r.id).toSet();
    for (final r in unique) {
      final due = r.date('nextHeartbeat');
      if (r.str('heartbeatStatus') == 'DEAD' ||
          (due != null && !due.isAfter(now))) {
        heartbeats.add(r.id);
      }
      final licenceId = r.relId('license');
      if (licenceId == null || !knownLicences.contains(licenceId)) {
        missingLinks++;
      } else if (overdueLicences.contains(licenceId)) {
        checkIns.add(r.id);
      }
    }
    return DeviceActivity._(unique, heartbeats, checkIns, missingLinks, now);
  }

  static Future<DeviceActivity> load(KeygenClient api) async {
    final resources = await Future.wait([
      api.listAll('machines'),
      api.listAll('licenses'),
    ]);
    return DeviceActivity.fromResources(
        resources[0], resources[1], DateTime.now());
  }

  final List<Resource> machines;
  final Set<String> overdueHeartbeats;
  final Set<String> overdueLicenceDevices;
  final int missingLicenceLinks;
  final DateTime checkedAt;

  HeartbeatGroup heartbeatGroup(Resource machine) {
    if (overdueHeartbeats.contains(machine.id)) return HeartbeatGroup.overdue;
    final status = machine.str('heartbeatStatus');
    if (machine.date('nextHeartbeat') != null ||
        status == 'ALIVE' ||
        status == 'RESURRECTED') {
      return HeartbeatGroup.onTime;
    }
    if (machine.boolVal('requireHeartbeat') == false &&
        machine.date('lastHeartbeat') == null &&
        (status == null || status == 'NOT_STARTED')) {
      return HeartbeatGroup.unmonitored;
    }
    if (status == 'NOT_STARTED') return HeartbeatGroup.notStarted;
    return HeartbeatGroup.unknown;
  }
}
