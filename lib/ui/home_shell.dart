import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../resources/kinds.dart';
import '../brand.dart';
import 'dashboard_page.dart';
import 'more_page.dart';
import 'resource_list_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(onOpenTab: _go),
      ResourceListPage(kind: kinds['licenses']!),
      ResourceListPage(kind: kinds['policies']!),
      ResourceListPage(kind: kinds['products']!),
      const MorePage(),
    ];
    const dests = [
      (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      (Icons.vpn_key_outlined, Icons.vpn_key, 'Licences'),
      (Icons.policy_outlined, Icons.policy, 'Policies'),
      (Icons.inventory_2_outlined, Icons.inventory_2, 'Products'),
      (Icons.more_horiz, Icons.more_horiz, 'More'),
    ];
    final body = IndexedStack(index: _index, children: pages);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            leading: const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 24),
              child:
                  Tooltip(message: AppBrand.name, child: BrandMark(size: 40)),
            ),
            selectedIndex: _index,
            onDestinationSelected: _go,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in dests)
                NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.72),
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _go,
              destinations: [
                for (final d in dests)
                  NavigationDestination(
                      icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
