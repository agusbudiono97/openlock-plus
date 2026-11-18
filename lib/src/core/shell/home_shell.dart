import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/router/app_router.dart';

/// Five primary destinations: overview, DNS Guard, schedules, activity and profile.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const _destinations = <_Destination>[
    _Destination(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Beranda'),
    _Destination(Icons.shield_outlined, Icons.shield_rounded, 'DNS Guard'),
    _Destination(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Jadwal'),
    _Destination(Icons.insights_outlined, Icons.insights_rounded, 'Statistik'),
    _Destination(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = shell.currentIndex.clamp(0, _destinations.length - 1);
    final isDnsGuardRoute = GoRouterState.of(context).uri.path == AppRoutes.dnsGuard;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      // Keep the indexed branch stack out of a full-screen opacity/transform
      // animation. Compositing the entire subtree on every tab change can
      // cause frame drops on devices with many live list rows and icons.
      // The destination item retains its lightweight local selection motion.
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: .10),
              blurRadius: 22,
              offset: const Offset(0, -6),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .28),
              width: .6,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 6),
            child: Row(
              children: List.generate(_destinations.length, (index) {
                final selected = index == 1
                    ? isDnsGuardRoute
                    : index == activeIndex;
                return Expanded(
                  child: _NavigationItem(
                    destination: _destinations[index],
                    selected: selected,
                    onTap: () {
                      if (index == 1) {
                        context.push(AppRoutes.dnsGuard);
                      } else {
                        shell.goBranch(
                          index,
                          initialLocation: index == shell.currentIndex,
                        );
                      }
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.secondary : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? colors.secondary.withValues(alpha: .13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    key: ValueKey(selected),
                    size: 22,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  child: Text(destination.label, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
