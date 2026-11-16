import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/intruder/providers/intruder_providers.dart';
import 'package:openlock/src/features/schedules/widgets/schedule_format.dart';

/// Main overview. This screen is presentation-only: it reads the existing
/// protection state and routes to the existing feature screens.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final apps = ref.watch(appListProvider).valueOrNull;
    final events = ref.watch(intruderControllerProvider).valueOrNull ?? const [];
    final activeSchedules = config.schedules.where((s) => s.enabled).toList();
    final strictActive = config.strictModeActiveAt(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    final lockedCount = apps?.lockedCount ?? config.lockedPackages.length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, Fokus! 👋', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: scheme.onSurface, fontWeight: FontWeight.w800,
                          )),
                          const SizedBox(height: 4),
                          Text(strictActive ? 'Komitmenmu sedang berjalan' : 'Kamu sedang terlindungi',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                        ],
                      ),
                    ),
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
                      ),
                      child: Icon(Icons.shield_rounded, color: scheme.primary, size: 25),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _ProtectionCard(
                  active: strictActive,
                  lockedCount: lockedCount,
                  scheduleCount: activeSchedules.length,
                  onTap: () => context.push(AppRoutes.strictMode),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: _MetricCard(
                      icon: Icons.apps_rounded,
                      label: 'Aplikasi terkunci',
                      value: '$lockedCount',
                      tint: scheme.primary,
                    )),
                    const SizedBox(width: 9),
                    Expanded(child: _MetricCard(
                      icon: Icons.shield_outlined,
                      label: 'Percobaan diblokir',
                      value: '${events.length}',
                      tint: const Color(0xFFFF766D),
                    )),
                    const SizedBox(width: 9),
                    Expanded(child: _MetricCard(
                      icon: Icons.calendar_month_rounded,
                      label: 'Jadwal aktif',
                      value: '${activeSchedules.length}',
                      tint: const Color(0xFFFFC15B),
                    )),
                  ],
                ),
                const SizedBox(height: 26),
                _SectionHeading(
                  title: 'Jadwal perlindungan',
                  action: 'Semua jadwal',
                  onAction: () => context.go(AppRoutes.schedules),
                ),
                const SizedBox(height: 12),
                if (activeSchedules.isEmpty)
                  _EmptyPanel(
                    icon: Icons.calendar_today_rounded,
                    title: 'Belum ada jadwal aktif',
                    subtitle: 'Buat rutinitas agar aplikasi terkunci otomatis.',
                    action: 'Buat jadwal',
                    onTap: () => context.push(AppRoutes.newSchedule),
                  )
                else
                  ...activeSchedules.take(3).map((schedule) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SchedulePreview(
                      name: schedule.name,
                      time: ScheduleFormat.summary(schedule),
                      appCount: schedule.packages.length,
                    ),
                  )),
                const SizedBox(height: 16),
                _SectionHeading(
                  title: 'Aktivitas terbaru',
                  action: 'Lihat statistik',
                  onAction: () => context.go(AppRoutes.intruder),
                ),
                const SizedBox(height: 12),
                if (events.isEmpty)
                  const _EmptyPanel(
                    icon: Icons.verified_user_rounded,
                    title: 'Belum ada percobaan tercatat',
                    subtitle: 'Aktivitas keamanan akan muncul di sini.',
                  )
                else
                  ...events.take(3).map((event) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ActivityPreview(
                      title: event.packageName,
                      subtitle: event.timestamp.toLocal().toString().substring(0, 16),
                    ),
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({
    required this.active, required this.lockedCount,
    required this.scheduleCount, required this.onTap,
  });
  final bool active;
  final int lockedCount;
  final int scheduleCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF087E82), Color(0xFF07516A), Color(0xFF242D59)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    active ? 'MODE KETAT AKTIF' : 'PERLINDUNGAN OPENLOCK',
                    style: const TextStyle(color: Colors.white70, fontSize: 11,
                      fontWeight: FontWeight.w800, letterSpacing: 1.2),
                  )),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white70),
                ]),
                const SizedBox(height: 22),
                Text(
                  active ? 'Komitmen sedang berjalan' : 'Jaga fokus, kendalikan akses.',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                    height: 1.15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '$lockedCount aplikasi dipilih  •  $scheduleCount jadwal aktif',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: .18)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(active ? Icons.lock_rounded : Icons.lock_clock_rounded,
                      size: 17, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(active ? 'Lihat status Mode Ketat' : 'Atur Mode Ketat',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.label, required this.value, required this.tint});
  final IconData icon; final String label; final String value; final Color tint;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .38)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: tint, size: 21),
        const SizedBox(height: 13),
        Text(value, style: TextStyle(color: scheme.onSurface, fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onAction});
  final String title; final String? action; final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
    if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
  ]);
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({required this.name, required this.time, required this.appCount});
  final String name; final String time; final int appCount;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35)),
      ),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
          child: Icon(Icons.schedule_rounded, color: scheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(time, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ])),
        Text('$appCount app', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
      ]),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.subtitle, this.action, this.onTap});
  final IconData icon; final String title; final String subtitle; final String? action; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35)),
      ),
      child: Row(children: [
        Icon(icon, color: scheme.primary, size: 25),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
        ])),
      ]),
    );
  }
}

class _ActivityPreview extends StatelessWidget {
  const _ActivityPreview({required this.title, required this.subtitle});
  final String title; final String subtitle;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(Icons.shield_outlined, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10)),
      ]),
    );
  }
}
