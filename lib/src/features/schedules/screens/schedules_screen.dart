import 'package:core_ui/core_ui.dart';
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
    final config =
        ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final schedules = config.schedules;

    final active = schedules.where((s) => s.enabled).length;
    final strictActive = config.strictModeActiveAt(DateTime.now());

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: strictActive ? null : () => context.push(AppRoutes.newSchedule),
        icon: const Icon(Icons.add),
        label: const Text('Buat jadwal'),
      ),
      body: SafeArea(
        bottom: false,
        child: PageList(
          bottomPadding: 96,
          children: [
            if (strictActive)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.lock_clock_rounded),
                  title: Text('Mode Ketat aktif'),
                  subtitle: Text('Jadwal tidak dapat diubah sampai komitmen berakhir.'),
                ),
              ),
            ScreenHeader(
              eyebrow: schedules.isEmpty
                  ? 'Kunci sesuai waktu'
                  : '$active dari ${schedules.length} aktif',
              title: 'Jadwal',
            ),
            if (schedules.isEmpty)
              const AppEmptyState(
                icon: Icons.schedule_rounded,
                title: 'Belum ada jadwal',
                message: 'Kunci aplikasi pilihan pada jam tertentu, misalnya aplikasi sosial '
                    'pada hari kerja.',
              )
            else
              RowGroup(
                children: [
                  for (final schedule in schedules)
                    _ScheduleCard(
                      schedule: schedule,
                      onTap: strictActive ? null : () => context.push(
                        '${AppRoutes.editSchedule}/${schedule.id}',
                      ),
                      onToggle: strictActive ? null : (value) => ref
                          .read(configControllerProvider.notifier)
                          .upsertSchedule(schedule.copyWith(enabled: value)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onTap,
    required this.onToggle,
  });

  final LockSchedule schedule;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final count = schedule.packages.length;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        onTap: onTap,
        leading: const IconBadge(icon: Icons.schedule_rounded),
        title: Text(
          schedule.name,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ScheduleFormat.summary(schedule)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.apps_rounded,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text('$count aplikasi'),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: schedule.enabled
                          ? colors.primary
                          : colors.outlineVariant,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(schedule.enabled ? 'Aktif' : 'Nonaktif'),
                ],
              ),
            ],
          ),
        ),
        trailing: Switch(
          value: schedule.enabled,
          onChanged: onToggle,
        ),
      ),
    );
  }
}
