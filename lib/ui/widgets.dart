import 'package:flutter/material.dart';

import '../theme.dart';
import 'util.dart';

/// Small uppercase, tracked label used above sections and for field names.
class Caps extends StatelessWidget {
  const Caps(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

/// Soft, translucent panel with a lit top edge.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.glow,
    this.radius = 18,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Optional colour that tints the panel from its top-left corner.
  final Color? glow;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = BorderRadius.circular(radius);
    final top = dark ? Colors.white.withValues(alpha: 0.10) : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, cs.outlineVariant.withValues(alpha: dark ? 0.55 : 0.6)],
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 6))
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius - 1),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius - 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  glow == null
                      ? cs.surfaceContainer
                      : Color.alphaBlend(
                          glow!.withValues(alpha: 0.16), cs.surfaceContainer),
                  cs.surfaceContainerLow,
                ],
              ),
            ),
            child: InkWell(
                onTap: onTap, child: Padding(padding: padding, child: child)),
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts its child in, after [delay].
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 450 + index * 70),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, (1 - t) * 14), child: child),
        ),
        child: child,
      );
}

/// Radial wash of brand colour behind the top of a screen.
class Glow extends StatelessWidget {
  const Glow({super.key, this.color, this.height = 360});
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.7, -1.1),
              radius: 1.1,
              colors: [
                c.withValues(alpha: dark ? 0.16 : 0.12),
                c.withValues(alpha: 0)
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section heading with an optional trailing widget.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: Row(children: [
          Caps(title),
          const Spacer(),
          if (trailing != null) trailing!
        ]),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(status.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: c)),
      ]),
    );
  }
}

/// Rounded-square icon tile used as list leading.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40, this.tint});
  final IconData icon;
  final double size;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint == null
            ? cs.surfaceContainerHigh
            : tint!.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
            color: tint == null
                ? cs.outlineVariant
                : tint!.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, size: size * 0.5, color: tint ?? cs.onSurface),
    );
  }
}

/// Label / value row for detail panels.
class DataRow2 extends StatelessWidget {
  const DataRow2(this.label, this.value,
      {super.key, this.mono = false, this.trailing, this.onLongPress});
  final String label;
  final String value;
  final bool mono;
  final Widget? trailing;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: mono
                    ? AppTheme.mono(context, size: 13)
                    : const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

/// Stacks rows with hairline dividers inside a [Panel].
class RowsPanel extends StatelessWidget {
  const RowsPanel(this.rows, {super.key});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: cs.outlineVariant),
          rows[i],
        ],
      ]),
    );
  }
}

/// Scaffold with an Apple-style large collapsing title.
class LargeTitleScroll extends StatelessWidget {
  const LargeTitleScroll({
    super.key,
    required this.title,
    required this.slivers,
    this.actions,
    this.onRefresh,
    this.controller,
    this.floatingActionButton,
    this.showBack = false,
  });

  final String title;
  final List<Widget> slivers;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final Widget? floatingActionButton;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar.large(
          backgroundColor: WidgetStateColor.resolveWith((st) => st
                  .contains(WidgetState.scrolledUnder)
              ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.94)
              : Colors.transparent),
          title: Text(title),
          actions: actions,
          automaticallyImplyLeading: showBack,
        ),
        ...slivers,
      ],
    );
    return Scaffold(
      extendBody: true,
      floatingActionButton: floatingActionButton,
      body: Stack(children: [
        const Positioned.fill(child: Glow()),
        Positioned.fill(
            child: onRefresh == null
                ? scroll
                : RefreshIndicator(onRefresh: onRefresh!, child: scroll)),
      ]),
    );
  }
}
