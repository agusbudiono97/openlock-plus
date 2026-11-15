import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Four primary sections; schedules remain reachable from the Blocking tab.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const _branches = [0, 3, 2, 4];

  @override
  Widget build(BuildContext context) {
    final selected = _branches.indexOf(shell.currentIndex);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) {
          final branch = _branches[index];
          shell.goBranch(
            branch,
            initialLocation: branch == shell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: 'Pemblokiran',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_clock_outlined),
            selectedIcon: Icon(Icons.lock_clock_rounded),
            label: 'Mode Ketat',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Statistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
