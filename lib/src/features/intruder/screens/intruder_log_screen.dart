import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/intruder/providers/intruder_providers.dart';

class IntruderLogScreen extends ConsumerStatefulWidget {
  const IntruderLogScreen({super.key});

  @override
  ConsumerState<IntruderLogScreen> createState() => _IntruderLogScreenState();
}

class _IntruderLogScreenState extends ConsumerState<IntruderLogScreen> {
  String _filter = 'Semua';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(intruderControllerProvider);
    final config = ref.watch(configControllerProvider).valueOrNull;
    final colors = _ActivityColors(isDark);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(colors: colors),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.amber),
                ),
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Riwayat aktivitas tidak dapat dimuat.',
                      style: TextStyle(color: colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (records) {
                  final todayCount = records
                      .where((r) => DateUtils.isSameDay(r.timestamp, DateTime.now()))
                      .length;
                  final photoCount =
                      records.where((r) => r.photoPath != null).length;
                  final filteredRecords = records.where((record) {
                    switch (_filter) {
                      case 'Hari ini':
                        return DateUtils.isSameDay(
                          record.timestamp,
                          DateTime.now(),
                        );
                      case 'Foto tersimpan':
                        return record.photoPath != null;
                      default:
                        return true;
                    }
                  }).toList();

                  return RefreshIndicator(
                    color: colors.amber,
                    onRefresh: () => ref
                        .read(intruderControllerProvider.notifier)
                        .refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                      children: [
                        _PageHeading(
                          colors: colors,
                          onRefresh: () => ref
                              .read(intruderControllerProvider.notifier)
                              .refresh(),
                        ),
                        const SizedBox(height: 16),
                        _DetectionBanner(colors: colors),
                        const SizedBox(height: 16),
                        _StatsGrid(
                          colors: colors,
                          lockedCount: config?.lockedPackages.length ?? 0,
                          scheduleCount: config?.schedules
                                  .where((schedule) => schedule.enabled)
                                  .length ??
                              0,
                          failedCount: records.length,
                          todayCount: todayCount,
                          photoCount: photoCount,
                        ),
                        const SizedBox(height: 22),
                        _HistoryHeading(
                          colors: colors,
                          count: filteredRecords.length,
                          filter: _filter,
                          hasRecords: records.isNotEmpty,
                          onFilterChanged: (value) =>
                              setState(() => _filter = value),
                          onClearAll: () async {
                            final shouldClear = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Hapus semua riwayat?'),
                                content: const Text(
                                  'Catatan percobaan gagal akan dihapus dari perangkat.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Batal'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                            if (shouldClear == true && mounted) {
                              await ref
                                  .read(intruderControllerProvider.notifier)
                                  .clearAll();
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        if (filteredRecords.isEmpty)
                          _EmptyHistoryCard(
                            colors: colors,
                            hasAnyRecords: records.isNotEmpty,
                            onCameraInfo: _showCameraInfo,
                          )
                        else
                          _RecordsCard(
                            colors: colors,
                            records: filteredRecords,
                            onDelete: (record) => ref
                                .read(intruderControllerProvider.notifier)
                                .delete(record.id),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCameraInfo() {
    final colors = _ActivityColors(
      Theme.of(context).brightness == Brightness.dark,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          'Deteksi kamera OpenLock',
          style: TextStyle(color: colors.text),
        ),
        content: Text(
          'OpenLock mencatat percobaan membuka paksa aplikasi. Sistem akan mencoba mengambil foto kamera depan jika izin kamera tersedia dan perangkat mendukung proses tersebut. Tombol ini hanya menampilkan informasi; tidak memicu pengambilan foto uji.',
          style: TextStyle(color: colors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Mengerti', style: TextStyle(color: colors.amber)),
          ),
        ],
      ),
    );
  }
}

class _ActivityColors {
  _ActivityColors(this.isDark);

  final bool isDark;

  Color get background =>
      isDark ? const Color(0xFF100E19) : const Color(0xFFF7F9FC);
  Color get card => isDark ? const Color(0xFF1D1A29) : Colors.white;
  Color get cardAlt => isDark ? const Color(0xFF242031) : const Color(0xFFF8FAFC);
  Color get border =>
      isDark ? const Color(0xFF302B40) : const Color(0xFFE2E8F0);
  Color get text =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
  Color get textSecondary =>
      isDark ? const Color(0xFFB5B1C5) : const Color(0xFF475569);
  Color get amber => const Color(0xFFF59E0B);
  Color get purple => const Color(0xFF7565FF);
  Color get green => const Color(0xFF10B981);
  Color get cyan => const Color(0xFF06B6D4);
  Color get red => const Color(0xFFFB7185);
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.colors});

  final _ActivityColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: const Color(0xFF12101C),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.amber.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: colors.amber.withValues(alpha: .32),
              ),
            ),
            child: Icon(Icons.lock_rounded, color: colors.amber, size: 21),
          ),
          const SizedBox(width: 11),
          const Text(
            'Aktivitas',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
            ),
          ),
          const Spacer(),
          Material(
            color: colors.amber,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.go(AppRoutes.settings),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF241608),
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.colors, required this.onRefresh});

  final _ActivityColors colors;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'PUSAT AKTIVITAS',
                    style: TextStyle(
                      color: colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Statistik & Keamanan',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onRefresh,
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.sync_rounded,
                color: colors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetectionBanner extends StatelessWidget {
  const _DetectionBanner({required this.colors});

  final _ActivityColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.isDark
            ? const Color(0xFF211D2C)
            : const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.amber.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
            color: colors.amber.withValues(alpha: colors.isDark ? .06 : .07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.amber,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: colors.amber.withValues(alpha: .22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sistem Deteksi Siaga',
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.amber.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.amber.withValues(alpha: .35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'SIAGA',
                            style: TextStyle(
                              color: colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'OpenLock mencatat percobaan membuka paksa dan mencoba mengambil foto jika izin kamera tersedia.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.colors,
    required this.lockedCount,
    required this.scheduleCount,
    required this.failedCount,
    required this.todayCount,
    required this.photoCount,
  });

  final _ActivityColors colors;
  final int lockedCount;
  final int scheduleCount;
  final int failedCount;
  final int todayCount;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                colors: colors,
                icon: Icons.lock_outline_rounded,
                iconColor: colors.amber,
                title: 'Aplikasi Dikunci',
                value: '$lockedCount',
                status: 'Auto-Lock aktif',
                statusColor: colors.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                colors: colors,
                icon: Icons.access_time_rounded,
                iconColor: colors.purple,
                title: 'Jadwal Aktif',
                value: '$scheduleCount',
                status: 'Format 24 jam',
                statusColor: colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                colors: colors,
                icon: Icons.shield_outlined,
                iconColor: colors.red,
                title: 'Percobaan Gagal',
                value: '$failedCount',
                status: todayCount == 0 ? 'Hari ini aman' : '$todayCount hari ini',
                statusColor: colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                colors: colors,
                icon: Icons.photo_camera_outlined,
                iconColor: colors.cyan,
                title: 'Foto Tersimpan',
                value: '$photoCount',
                status: 'Tersimpan di perangkat',
                statusColor: colors.cyan,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.colors,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.status,
    required this.statusColor,
  });

  final _ActivityColors colors;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 162),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? .12 : .035),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              color: colors.text,
              fontSize: 34,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryHeading extends StatelessWidget {
  const _HistoryHeading({
    required this.colors,
    required this.count,
    required this.filter,
    required this.hasRecords,
    required this.onFilterChanged,
    required this.onClearAll,
  });

  final _ActivityColors colors;
  final int count;
  final String filter;
  final bool hasRecords;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Riwayat Percobaan Gagal',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 7, right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.isDark
                ? const Color(0xFF302B40)
                : const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Filter riwayat',
          onSelected: (value) {
            if (value == 'Hapus semua') {
              onClearAll();
            } else {
              onFilterChanged(value);
            }
          },
          color: colors.card,
          itemBuilder: (context) => [
            for (final value in ['Semua', 'Hari ini', 'Foto tersimpan'])
              PopupMenuItem(
                value: value,
                child: Row(
                  children: [
                    if (filter == value)
                      Icon(Icons.check_rounded, size: 17, color: colors.amber)
                    else
                      const SizedBox(width: 17),
                    const SizedBox(width: 8),
                    Text(value, style: TextStyle(color: colors.text)),
                  ],
                ),
              ),
            if (hasRecords) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'Hapus semua',
                child: Text(
                  'Hapus semua riwayat',
                  style: TextStyle(color: colors.red),
                ),
              ),
            ],
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 15, color: colors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  'Filter',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({
    required this.colors,
    required this.hasAnyRecords,
    required this.onCameraInfo,
  });

  final _ActivityColors colors;
  final bool hasAnyRecords;
  final VoidCallback onCameraInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? .12 : .035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.isDark
                          ? const Color(0xFF51465F).withValues(alpha: .65)
                          : const Color(0xFFD9E2EF),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  width: 102,
                  height: 102,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.amber.withValues(alpha: .055),
                    border: Border.all(
                      color: colors.amber.withValues(alpha: .25),
                    ),
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.amber,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: colors.amber.withValues(alpha: .3),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            hasAnyRecords
                ? 'Tidak ada aktivitas pada filter ini'
                : 'Belum ada aktivitas penyusup',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasAnyRecords
                ? 'Coba pilih filter riwayat yang lain untuk melihat catatan aktivitas.'
                : 'Jika seseorang mencoba membuka paksa aplikasi terkunci, catatan percobaan dan foto (jika berhasil diambil) akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
          if (!hasAnyRecords) ...[
            const SizedBox(height: 23),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onCameraInfo,
                icon: const Icon(Icons.remove_red_eye_outlined, size: 19),
                label: const Text(
                  'Uji Coba Deteksi Kamera',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.amber,
                  foregroundColor: const Color(0xFF241608),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({
    required this.colors,
    required this.records,
    required this.onDelete,
  });

  final _ActivityColors colors;
  final List<IntruderRecord> records;
  final ValueChanged<IntruderRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < records.length; index++) ...[
            _IntruderRow(
              colors: colors,
              record: records[index],
              onDelete: () => onDelete(records[index]),
            ),
            if (index != records.length - 1)
              Divider(height: 1, indent: 16, endIndent: 16, color: colors.border),
          ],
        ],
      ),
    );
  }
}

class _IntruderRow extends StatelessWidget {
  const _IntruderRow({
    required this.colors,
    required this.record,
    required this.onDelete,
  });

  final _ActivityColors colors;
  final IntruderRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final path = record.photoPath;
    final hasPhoto = path != null && File(path).existsSync();
    final when = DateFormat('dd MMM yyyy • HH:mm').format(record.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: hasPhoto
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : ColoredBox(
                      color: colors.cardAlt,
                      child: Icon(
                        Icons.no_photography_outlined,
                        color: colors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.packageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  when,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (hasPhoto)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Foto tersimpan',
                      style: TextStyle(color: colors.green, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus catatan',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
