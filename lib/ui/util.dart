import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

String humanize(String key) {
  final spaced = key.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  final s = spaced.replaceAll('_', ' ').toLowerCase();
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

String formatValue(String key, dynamic v) {
  if (v is bool) return v ? 'Yes' : 'No';
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null && v.contains('T')) {
      return DateFormat.yMMMd().add_jm().format(d.toLocal());
    }
  }
  if (v is num && key == 'duration') return '${(v / 86400).round()} days';
  return '$v';
}

Color statusColor(String? status, ColorScheme cs) {
  switch (status?.toUpperCase()) {
    case 'ACTIVE':
    case 'ALIVE':
    case 'RESURRECTED':
      return const Color(0xFF34C759);
    case 'EXPIRING':
      return const Color(0xFFFFB020);
    case 'EXPIRED':
    case 'DEAD':
      return const Color(0xFFFF5C5C);
    case 'SUSPENDED':
      return const Color(0xFFFF9F0A);
    case 'BANNED':
      return const Color(0xFFD64545);
    default:
      return cs.onSurfaceVariant;
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

Future<bool> confirm(BuildContext context, String title, String body,
    {String action = 'Confirm', bool destructive = false}) async {
  final res = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return res ?? false;
}

Future<void> copyText(BuildContext context, String text,
    [String label = 'Copied']) async {
  await Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.lightImpact();
  if (context.mounted) showSnack(context, label);
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                  onPressed: onRetry, child: const Text('Try again')),
            ],
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.icon, this.title,
      {super.key, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: t.colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: t.textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

/// "in 12 days", "3 days ago", "today".
String relativeDays(DateTime d) {
  final days = DateTime(d.year, d.month, d.day)
      .difference(DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day))
      .inDays;
  if (days == 0) return 'today';
  final n = days.abs();
  final unit =
      n >= 60 ? '${(n / 30).round()} months' : (n == 1 ? '1 day' : '$n days');
  return days > 0 ? 'in $unit' : '$unit ago';
}
