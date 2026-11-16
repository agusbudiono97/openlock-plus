import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Primary destinations for all five existing app sections.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  // Keep the existing router branch mapping and all five destinations.
  static const _branches = [0, 1, 3, 2, 4];

  static const _destinations = <_Destination>[
    _Destination(Icons.apps_outlined, Icons.apps_rounded, 'Blokir'),
    _Destination(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Jadwal'),
    _Destination(Icons.lock_clock_outlined, Icons.lock_clock_rounded, 'Ketat'),
    _Destination(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Statistik'),
    _Destination(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _branches.indexOf(shell.currentIndex);
    final activeIndex = selected < 0 ? 0 : selected;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: TweenAnimationBuilder<double>(
        key: ValueKey(shell.currentIndex),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 210),
        curve: Curves.easeOutCubic,
        child: shell,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 5 * (1 - value)),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.055),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.32),
              width: 0.6,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 7, 7, 5),
            child: Row(
              children: List.generate(_destinations.length, (index) {
                final destination = _destinations[index];
                final isSelected = index == activeIndex;
                return Expanded(
                  child: _NavigationItem(
                    destination: destination,
                    selected: isSelected,
                    onTap: () {
                      final branch = _branches[index];
                      shell.goBranch(
                        branch,
                        initialLocation: branch == shell.currentIndex,
                      );
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
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? colors.secondaryContainer.withValues(alpha: 0.82)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
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
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
