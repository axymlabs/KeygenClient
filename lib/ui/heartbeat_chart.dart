import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/keygen_client.dart';
import '../state/device_activity.dart';
import '../theme.dart';
import 'widgets.dart';

extension HeartbeatPresentation on HeartbeatGroup {
  String get label => switch (this) {
        HeartbeatGroup.onTime => 'On time',
        HeartbeatGroup.overdue => 'Overdue',
        HeartbeatGroup.notStarted => 'Not started',
        HeartbeatGroup.unmonitored => 'Not monitored',
        HeartbeatGroup.unknown => 'Unknown',
      };
  Color get color => switch (this) {
        HeartbeatGroup.onTime => const Color(0xFF54E3BB),
        HeartbeatGroup.overdue => const Color(0xFFFF6B7A),
        HeartbeatGroup.notStarted => const Color(0xFFFFC168),
        HeartbeatGroup.unmonitored => const Color(0xFF7C94AB),
        HeartbeatGroup.unknown => const Color(0xFFAB9CE5),
      };
  String get explanation => switch (this) {
        HeartbeatGroup.onTime =>
          'Reporting alive or still within the heartbeat window.',
        HeartbeatGroup.overdue =>
          'Past the heartbeat deadline or reported dead by the server.',
        HeartbeatGroup.notStarted =>
          'The server reports that these devices have not started their heartbeat.',
        HeartbeatGroup.unmonitored =>
          'Heartbeat is optional and no monitor has been started.',
        HeartbeatGroup.unknown =>
          'The server has not supplied enough heartbeat information.',
      };
}

class HeartbeatChart extends StatefulWidget {
  const HeartbeatChart(
      {super.key, required this.activity, required this.onOpen});
  final DeviceActivity activity;
  final void Function(List<Resource> devices, String title) onOpen;

  @override
  State<HeartbeatChart> createState() => _HeartbeatChartState();
}

class _HeartbeatChartState extends State<HeartbeatChart> {
  HeartbeatGroup? _selected;
  HeartbeatGroup? _hovered;

  Map<HeartbeatGroup, List<Resource>> get _groups => {
        for (final group in HeartbeatGroup.values)
          group: widget.activity.machines
              .where((m) => widget.activity.heartbeatGroup(m) == group)
              .toList(),
      };

  HeartbeatGroup? _hit(Offset position, Size size) {
    final delta = position - size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 18;
    if ((delta.distance - radius).abs() > 22) return null;
    final fraction =
        (math.atan2(delta.dy, delta.dx) + math.pi / 2 + math.pi * 2) %
            (math.pi * 2) /
            (math.pi * 2);
    final total = widget.activity.machines.length;
    var start = 0.0;
    for (final entry in _groups.entries) {
      final end = start + (total == 0 ? 0 : entry.value.length / total);
      if (entry.value.isNotEmpty && fraction >= start && fraction < end) {
        return entry.key;
      }
      start = end;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final groups = _groups;
    final active = _hovered ?? _selected;
    final total = widget.activity.machines.length;
    final devices = active == null ? widget.activity.machines : groups[active]!;
    final attention = groups[HeartbeatGroup.overdue]!.length +
        groups[HeartbeatGroup.notStarted]!.length;
    return Panel(
      glow: active?.color ?? cs.primary,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.monitor_heart_outlined, size: 20),
          const SizedBox(width: 9),
          Expanded(
              child: Text('Heartbeat health',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600))),
          if (attention > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                  color: HeartbeatGroup.overdue.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$attention to check',
                  style: TextStyle(fontSize: 11, color: cs.onSurface)),
            ),
        ]),
        const SizedBox(height: 4),
        Text(
            'Latest server snapshot · ${DateFormat.jm().format(widget.activity.checkedAt)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        Center(
            child: SizedBox(
          width: 224,
          height: 224,
          child: LayoutBuilder(builder: (context, constraints) {
            final size = constraints.biggest;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (e) {
                final hit = _hit(e.localPosition, size);
                if (hit != _hovered) setState(() => _hovered = hit);
              },
              onExit: (_) => setState(() => _hovered = null),
              child: GestureDetector(
                key: const ValueKey('heartbeat-ring'),
                onTapUp: (e) {
                  final hit = _hit(e.localPosition, size);
                  if (hit != null) {
                    setState(() => _selected = _selected == hit ? null : hit);
                  }
                },
                child: Semantics(
                  image: true,
                  label:
                      'Heartbeat status of $total devices. Select a status below to filter.',
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 750),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, child) => CustomPaint(
                      painter: _HeartbeatRing(
                          groups.map((k, v) => MapEntry(k, v.length)),
                          active,
                          cs.outlineVariant,
                          progress),
                      child: child,
                    ),
                    child: Center(
                        child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Column(
                          key: ValueKey(active),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${devices.length}',
                                style: AppTheme.mono(context,
                                    size: 44, weight: FontWeight.w600)),
                            Text(active?.label ?? 'Devices',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                            if (active != null && total > 0)
                              Text(
                                  '${(devices.length / total * 100).round()}% of devices',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant)),
                          ]),
                    )),
                  ),
                ),
              ),
            );
          }),
        )),
        Text(
            total == 0
                ? 'No devices yet'
                : 'Tap a segment or status to explore',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final group in HeartbeatGroup.values)
            Semantics(
              selected: _selected == group,
              child: Tooltip(
                  message: group.explanation,
                  child: ChoiceChip(
                    key: ValueKey('heartbeat-${group.name}'),
                    avatar: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: group.color, shape: BoxShape.circle)),
                    showCheckmark: false,
                    label: Text('${group.label}  ${groups[group]!.length}'),
                    selected: _selected == group,
                    selectedColor: group.color.withValues(alpha: .18),
                    onSelected: (_) => setState(() {
                      _hovered = null;
                      _selected = _selected == group ? null : group;
                    }),
                  )),
            ),
        ]),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
              active?.explanation ??
                  'Heartbeats show whether each device is still reporting. Licence check-ins are tracked separately below.',
              key: ValueKey(active),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: devices.isEmpty
              ? null
              : () => widget.onOpen(
                  devices,
                  active == null
                      ? 'All devices'
                      : '${active.label} heartbeats'),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text(active == null
              ? 'View all devices'
              : 'View ${devices.length} ${devices.length == 1 ? 'device' : 'devices'}'),
        ),
      ]),
    );
  }
}

class _HeartbeatRing extends CustomPainter {
  _HeartbeatRing(this.counts, this.selected, this.track, this.progress);
  final Map<HeartbeatGroup, int> counts;
  final HeartbeatGroup? selected;
  final Color track;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;
    canvas.drawCircle(
        center, radius, paint..color = track.withValues(alpha: .5));
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;
    final multi = counts.values.where((n) => n > 0).length > 1;
    var start = -math.pi / 2;
    for (final entry in counts.entries) {
      if (entry.value == 0) continue;
      final angle = entry.value / total * math.pi * 2;
      // Small segments retain a visible, accurate share without overlapping caps.
      final gap = multi ? math.min(.09, angle * .35) : 0.0;
      final sweep = (angle - gap) * progress;
      final chosen = selected == entry.key;
      paint
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = chosen ? 26 : 18;
      if (chosen) {
        canvas.drawArc(
            rect,
            start + gap / 2,
            sweep,
            false,
            paint
              ..color = entry.key.color.withValues(alpha: .32)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      }
      canvas.drawArc(
          rect,
          start + gap / 2,
          sweep,
          false,
          paint
            ..maskFilter = null
            ..color = entry.key.color
                .withValues(alpha: selected == null || chosen ? 1 : .28));
      start += angle;
    }
  }

  @override
  bool shouldRepaint(covariant _HeartbeatRing old) =>
      old.selected != selected ||
      old.track != track ||
      old.progress != progress ||
      counts.entries.any((e) => old.counts[e.key] != e.value);
}
