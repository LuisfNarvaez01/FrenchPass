import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/update_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/update_dialog.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories_rounded, label: 'Hoy',        path: '/home'),
    (icon: Icons.psychology_outlined,   activeIcon: Icons.psychology_rounded,   label: 'Quiz',       path: '/quiz'),
    (icon: Icons.grid_view_outlined,    activeIcon: Icons.grid_view_rounded,    label: 'Categorías', path: '/categories'),
    (icon: Icons.insights_outlined,     activeIcon: Icons.insights_rounded,     label: 'Progreso',   path: '/progress'),
    (icon: Icons.tune_outlined,         activeIcon: Icons.tune_rounded,         label: 'Ajustes',    path: '/settings'),
  ];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _updatePromptShown = false;

  @override
  void initState() {
    super.initState();
    // The check started in configureDependencies(); this only reacts once
    // it resolves, from a context that is guaranteed to sit under a
    // Navigator, so showDialog always has somewhere to mount.
    getIt<UpdateService>().available.addListener(_onUpdateAvailable);
    // In case it already resolved before this shell was built (e.g. the
    // learner was on a route rebuilt after the check landed).
    WidgetsBinding.instance.addPostFrameCallback((_) => _onUpdateAvailable());
  }

  @override
  void dispose() {
    getIt<UpdateService>().available.removeListener(_onUpdateAvailable);
    super.dispose();
  }

  void _onUpdateAvailable() {
    if (_updatePromptShown || !mounted) return;
    final info = getIt<UpdateService>().available.value;
    if (info == null) return;
    _updatePromptShown = true;
    showUpdateDialog(context, getIt<UpdateService>(), info);
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < MainShell._tabs.length; i++) {
      if (location.startsWith(MainShell._tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final selected = _selectedIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) {
            if (i == selected) return;
            context.go(MainShell._tabs[i].path);
          },
          destinations: [
            for (final tab in MainShell._tabs)
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
