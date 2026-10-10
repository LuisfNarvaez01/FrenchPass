import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories_rounded, label: 'Hoy',        path: '/home'),
    (icon: Icons.psychology_outlined,   activeIcon: Icons.psychology_rounded,   label: 'Quiz',       path: '/quiz'),
    (icon: Icons.grid_view_outlined,    activeIcon: Icons.grid_view_rounded,    label: 'Categorías', path: '/categories'),
    (icon: Icons.insights_outlined,     activeIcon: Icons.insights_rounded,     label: 'Progreso',   path: '/progress'),
    (icon: Icons.tune_outlined,         activeIcon: Icons.tune_rounded,         label: 'Ajustes',    path: '/settings'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final selected = _selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) {
            if (i == selected) return;
            context.go(_tabs[i].path);
          },
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.activeIcon),
                label: tab.label,
                tooltip: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}
