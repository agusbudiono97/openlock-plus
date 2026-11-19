import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/router/app_router.dart';

/// Four compact primary destinations; profile remains available from the
/// home header, while DNS Guard remains reachable from its existing route.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  static const _destinations = <_Destination>[
    _Destination(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Beranda', 0),
    _Destination(Icons.apps_outlined, Icons.apps_rounded, 'Aplikasi', 1),
    _Destination(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Jadwal', 2),
    _Destination(Icons.insights_outlined, Icons.insights_rounded, 'Aktivitas', 3),
  ];

  @override
  Widget build(BuildContext context) {
    final current = shell.currentIndex;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF0C0D14),
          border: Border(top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0x18FFFFFF)
                : const Color(0xFFE2E8F0), width: .7)),
          boxShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 22, offset: Offset(0, -6))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
            child: Row(children: [
              for (final destination in _destinations)
                Expanded(child: _NavigationItem(
                  destination: destination,
                  selected: current == destination.branch,
                  onTap: () => shell.goBranch(
                    destination.branch,
                    initialLocation: destination.branch == current,
                  ),
                )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label, this.branch);
  final IconData icon, selectedIcon;
  final String label;
  final int branch;
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({required this.destination, required this.selected, required this.onTap});
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? (isDark ? const Color(0xFFFFB259) : const Color(0xFFC65F1C))
        : (isDark ? const Color(0xFF777B91) : const Color(0xFF64748B));
    return Semantics(
      button: true, selected: selected, label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? (isDark ? const Color(0x1AFF9E42) : const Color(0x1AFF8A3D))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
                child: Icon(selected ? destination.selectedIcon : destination.icon, key: ValueKey(selected), color: color, size: 21),
              ),
              const SizedBox(height: 3),
              Text(destination.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 9, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}
