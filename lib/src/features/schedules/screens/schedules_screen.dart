import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/core/widgets/screen_header.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/schedules/models/lock_schedule.dart';
import 'package:openlock/src/features/schedules/widgets/schedule_format.dart';

class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final schedules = config.schedules;
    final active = schedules.where((s) => s.enabled).length;
    final strictActive = config.strictModeActiveAt(DateTime.now());
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: strictActive ? null : () => context.push(AppRoutes.newSchedule),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat jadwal'),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
              children: [
                const ScreenHeader(eyebrow: 'OTOMATISASI AKSES', title: 'Jadwal'),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary.withValues(alpha: .18), scheme.surfaceContainerLow],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: .4)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.calendar_month_rounded, color: scheme.primary, size: 25),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$active jadwal aktif', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${schedules.length} jadwal tersimpan • kunci aplikasi otomatis',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    ])),
                  ]),
                ),
                if (strictActive) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(children: [
                      Icon(Icons.lock_clock_rounded),
                      SizedBox(width: 10),
                      Expanded(child: Text('Mode Ketat aktif. Jadwal tidak dapat diubah sampai komitmen berakhir.')),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text('Rutinitas kamu', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                    Text('${schedules.length} total', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                if (schedules.isEmpty)
                  _ScheduleEmpty(onCreate: strictActive ? null : () => context.push(AppRoutes.newSchedule))
                else
                  ...schedules.map((schedule) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ScheduleCard(
                      schedule: schedule,
                      onTap: strictActive ? null : () => context.push('${AppRoutes.editSchedule}/${schedule.id}'),
                      onToggle: strictActive ? null : (value) => ref.read(configControllerProvider.notifier)
                        .upsertSchedule(schedule.copyWith(enabled: value)),
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.onTap, required this.onToggle});
  final LockSchedule schedule;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.schedule_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(schedule.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(ScheduleFormat.summary(schedule),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ])),
              Switch(value: schedule.enabled, onChanged: onToggle),
            ]),
            const SizedBox(height: 15),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .35)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.apps_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('${schedule.packages.length} aplikasi', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: schedule.enabled ? scheme.primary.withValues(alpha: .12) : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(schedule.enabled ? 'AKTIF' : 'NONAKTIF',
                  style: TextStyle(color: schedule.enabled ? scheme.primary : scheme.onSurfaceVariant,
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
              ),
              const SizedBox(width: 5),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ScheduleEmpty extends StatelessWidget {
  const _ScheduleEmpty({required this.onCreate});
  final VoidCallback? onCreate;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .4)),
      ),
      child: Column(children: [
        Icon(Icons.calendar_today_rounded, size: 36, color: scheme.primary),
        const SizedBox(height: 12),
        Text('Belum ada jadwal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text('Atur waktu agar aplikasi pilihan terkunci secara otomatis.',
          textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text('Buat jadwal')),
      ]),
    );
  }
}
