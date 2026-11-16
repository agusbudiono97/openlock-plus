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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: TweenAnimationBuilder<double>(
        // A tiny fade + upward settle makes tab changes feel deliberate.
        // The navigation shell itself remains the same child, preserving
        // each branch navigator and its scroll position.
        key: ValueKey(shell.currentIndex),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        child: shell,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 7 * (1 - value)),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.45),
              width: 0.7,
            ),
          ),
        ),
        child: NavigationBar(
          height: 72,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          indicatorColor: colors.primaryContainer,
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
      ),
    );
  }
}
