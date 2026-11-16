import 'dart:io';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/core/widgets/screen_header.dart';
import 'package:openlock/src/features/intruder/providers/intruder_providers.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';

class IntruderLogScreen extends ConsumerWidget {
  const IntruderLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(intruderControllerProvider);
    final config = ref.watch(configControllerProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Riwayat tidak dapat dimuat',
          ),
          data: (records) => PageList(
            children: [
              ScreenHeader(
                eyebrow: 'PUSAT AKTIVITAS',
                title: 'Statistik',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Muat ulang',
                      onPressed: () => ref
                          .read(intruderControllerProvider.notifier)
                          .refresh(),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    if (records.isNotEmpty)
                      IconButton(
                        tooltip: 'Hapus semua',
                        onPressed: () => ref
                            .read(intruderControllerProvider.notifier)
                            .clearAll(),
                        icon: const Icon(Icons.delete_sweep_outlined),
                      ),
                  ],
                ),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _StatsTile(
                    label: 'Aplikasi dikunci',
                    value: '${config?.lockedPackages.length ?? 0}',
                    icon: Icons.lock_outline_rounded,
                  ),
                  _StatsTile(
                    label: 'Jadwal aktif',
                    value: '${config?.schedules.where((s) => s.enabled).length ?? 0}',
                    icon: Icons.schedule_rounded,
                  ),
                  _StatsTile(
                    label: 'Percobaan gagal',
                    value: '${records.length}',
                    icon: Icons.warning_amber_rounded,
                  ),
                  _StatsTile(
                    label: 'Foto tersimpan',
                    value: '${records.where((r) => r.photoPath != null).length}',
                    icon: Icons.photo_camera_back_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionLead('Riwayat percobaan gagal'),
              if (records.isEmpty)
                const AppEmptyState(
                  icon: Icons.verified_user_outlined,
                  title: 'Belum ada aktivitas penyusup',
                  message: 'Jika seseorang terlalu sering salah memasukkan PIN, foto '
                      'dan catatan percobaannya akan muncul di sini.',
                )
              else
                RowGroup(
                  separatorIndent: 84,
                  children: [
                    for (final record in records)
                      _IntruderRow(
                        record: record,
                        onDelete: () => ref
                            .read(intruderControllerProvider.notifier)
                            .delete(record.id),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntruderRow extends StatelessWidget {
  const _IntruderRow({required this.record, required this.onDelete});

  final IntruderRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final when = DateFormat.yMMMd().add_jm().format(record.timestamp);
    final photo = record.photoPath;
    final hasPhoto = photo != null && File(photo).existsSync();
    return AppListRow(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: SizedBox(
          width: 52,
          height: 52,
          child: hasPhoto
              ? Image.file(File(photo), fit: BoxFit.cover)
              : ColoredBox(
                  color: c.surfaceAlt,
                  child: Icon(
                    Icons.no_photography_outlined,
                    color: c.textSecondary,
                  ),
                ),
        ),
      ),
      title: record.packageName,
      subtitle: when,
      trailing: IconButton(
        tooltip: 'Hapus catatan',
        onPressed: onDelete,
        icon: const Icon(Icons.close_rounded),
      ),
    );
  }
}

class _StatsTile extends StatelessWidget {
  const _StatsTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 154,
      child: Container(
        constraints: const BoxConstraints(minHeight: 126),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .38),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.primary, size: 19),
            ),
            const SizedBox(height: 13),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
