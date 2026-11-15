import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/widgets/screen_header.dart';

class StrictModeScreen extends ConsumerStatefulWidget {
  const StrictModeScreen({super.key});

  @override
  ConsumerState<StrictModeScreen> createState() => _StrictModeScreenState();
}

class _StrictModeScreenState extends ConsumerState<StrictModeScreen> {
  final _amount = TextEditingController(text: '1');
  final Set<String> _selected = {};
  String _unit = 'jam';
  bool _indefinite = false;
  DateTime? _exactEnd;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _amount.dispose();
    super.dispose();
  }

  DateTime? _deadline() {
    if (_indefinite) return null;
    if (_exactEnd != null) return _exactEnd;
    final value = int.tryParse(_amount.text);
    if (value == null || value < 1) return null;
    final now = DateTime.now();
    switch (_unit) {
      case 'menit':
        return now.add(Duration(minutes: value));
      case 'jam':
        return now.add(Duration(hours: value));
      case 'hari':
        return now.add(Duration(days: value));
      case 'bulan':
        final targetMonth = now.month - 1 + value;
        final year = now.year + targetMonth ~/ 12;
        final month = targetMonth % 12 + 1;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, now.day > lastDay ? lastDay : now.day, now.hour, now.minute);
      default:
        return null;
    }
  }

  Future<void> _pickExactEnd() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      // DatePicker compares calendar dates, not timestamps. Use today's
      // midnight as firstDate and clamp the initial date to that boundary.
      initialDate: _exactEnd != null && !_exactEnd!.isBefore(DateTime(now.year, now.month, now.day))
          ? _exactEnd!
          : now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_exactEnd ?? now),
    );
    if (time == null || !mounted) return;
    final selectedEnd = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!selectedEnd.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waktu berakhir harus di masa depan.')),
      );
      return;
    }
    setState(() {
      _exactEnd = selectedEnd;
      _indefinite = false;
    });
  }

  Future<void> _start() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu aplikasi untuk diblokir.')),
      );
      return;
    }
    final end = _deadline();
    if (!_indefinite && (end == null || !end.isAfter(DateTime.now()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan durasi atau waktu berakhir yang valid.')),
      );
      return;
    }
    final bridge = ref.read(enforcementBridgeProvider);
    var permissions = await bridge.getPermissionStates();
    if (!permissions.canEnforce) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktifkan Akses penggunaan dan Tampil di atas aplikasi lain pada menu Izin sebelum memulai.')),
        );
      }
      return;
    }

    // Strict Mode also protects OpenLock itself. Activate Android's standard
    // device-admin uninstall barrier and the accessibility screen recogniser
    // before starting, so the user is not led to believe those layers are on
    // when Android has not granted them.
    final adminActive = await bridge.isDeviceAdminActive();
    if (!adminActive) {
      // The Android admin confirmation is an external system activity. The
      // MethodChannel request only launches it; it cannot report the user's
      // choice synchronously. Ask the user to return and tap Start again.
      await bridge.requestDeviceAdmin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfirmasi Administrator perangkat. Setelah kembali ke OpenLock, tekan Aktifkan Mode Ketat sekali lagi.')),
        );
      }
      return;
    }

    permissions = await bridge.getPermissionStates();
    if (!permissions.screenGuardAccess) {
      // Accessibility is enabled in Android Settings, outside this app. Do
      // not immediately re-check (the settings page has not been visited yet).
      await bridge.requestScreenGuardAccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktifkan layanan Aksesibilitas OpenLock. Setelah kembali ke aplikasi, tekan Aktifkan Mode Ketat sekali lagi.')),
        );
      }
      return;
    }

    try {
      // Start the foreground monitor before committing the timer. If Android
      // rejects the service start, Strict Mode must not be saved as active
      // while no enforcement process is running.
      await bridge.startService();
      await ref.read(configControllerProvider.notifier).setStrictMode(
        enabled: true,
        packages: Set.of(_selected),
        endsAtMillis: end?.millisecondsSinceEpoch,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mode Ketat belum berhasil diaktifkan: $error'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final active = config.strictModeActiveAt(DateTime.now());
    final apps = ref.watch(installedAppsProvider);
    final colors = SuiteColors.of(context);

    if (active) {
      final endAt = config.strictModeEndsAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              config.strictModeEndsAtMillis!,
            ).toLocal();
      final remaining = endAt?.difference(DateTime.now());
      final endLabel = endAt == null
          ? 'Tanpa batas waktu'
          : '${endAt.day.toString().padLeft(2, '0')}/${endAt.month.toString().padLeft(2, '0')}/${endAt.year} • ${endAt.hour.toString().padLeft(2, '0')}:${endAt.minute.toString().padLeft(2, '0')}';
      final countdown = remaining == null
          ? '∞'
          : remaining.isNegative
              ? '00:00:00'
              : remaining.inDays > 0
                  ? '${remaining.inDays}h ${(remaining.inHours % 24).toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'
                  : '${remaining.inHours.toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: PageList(
            children: [
              const ScreenHeader(
                eyebrow: 'Komitmen dan fokus',
                title: 'Mode Ketat',
              ),
              VaultCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Icon(Icons.shield_rounded, color: colors.textPrimary, size: 26),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PERLINDUNGAN AKTIF', style: AppTextStyles.caption.copyWith(color: colors.textSecondary, letterSpacing: 1)),
                              const SizedBox(height: 3),
                              Text('Kamu sedang dalam Mode Ketat', style: AppTextStyles.labelStrong.copyWith(color: colors.textPrimary)),
                            ],
                          ),
                        ),
                        Icon(Icons.check_circle_rounded, color: colors.textPrimary),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: Text(
                        countdown,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.numberMedium.copyWith(
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: Text(
                        endAt == null ? 'TANPA BATAS WAKTU' : 'WAKTU TERSISA',
                        style: AppTextStyles.caption.copyWith(color: colors.textSecondary, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Divider(color: colors.hairline),
                    Row(
                      children: [
                        Expanded(child: _ActiveMetric(label: 'Aplikasi dikunci', value: '${config.strictModePackages.length}')),
                        Expanded(child: _ActiveMetric(label: 'Berakhir', value: endLabel)),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionLead('Aplikasi yang dilindungi'),
              apps.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const AppEmptyState(
                  compact: true,
                  icon: Icons.error_outline_rounded,
                  title: 'Daftar aplikasi tidak dapat dimuat',
                ),
                data: (items) {
                  final selected = items.where((app) => config.strictModePackages.contains(app.packageName)).toList();
                  if (selected.isEmpty) {
                    return const AppEmptyState(
                      compact: true,
                      icon: Icons.apps_rounded,
                      title: 'Tidak ada aplikasi terdaftar',
                    );
                  }
                  return RowGroup(
                    children: [
                      for (final app in selected)
                        AppListRow(
                          title: app.label,
                          subtitle: 'Dikunci sampai komitmen berakhir',
                          leading: const IconBadge(icon: Icons.lock_rounded),
                          trailing: Icon(Icons.check_circle_rounded, color: colors.positive),
                        ),
                    ],
                  );
                },
              ),
              VaultCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pengaturan sedang dikunci', style: AppTextStyles.labelStrong.copyWith(color: colors.textPrimary)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Daftar aplikasi dan pengaturan perlindungan tidak dapat diubah sampai komitmen berakhir.',
                            style: AppTextStyles.label.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Android tetap memiliki kendali sistem yang tidak dapat dikunci mutlak oleh aplikasi biasa.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageList(
          children: [
            const ScreenHeader(
              eyebrow: 'Bangun kebiasaan lebih baik',
              title: 'Mode Ketat',
            ),
            VaultCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBadge(icon: Icons.shield_outlined),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Buat komitmen fokus',
                          style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Pilih aplikasi yang ingin dibatasi, lalu tentukan berapa lama perlindungan berjalan. Mode Ketat tidak bisa diakhiri lebih awal dari dalam aplikasi.',
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanpa batas waktu'),
                    subtitle: const Text('Perlindungan tidak berakhir otomatis'),
                    value: _indefinite,
                    onChanged: (value) => setState(() {
                      _indefinite = value;
                      if (value) _exactEnd = null;
                    }),
                  ),
                  if (!_indefinite) ...[
                    Text('Durasi perlindungan', style: AppTextStyles.labelStrong.copyWith(color: colors.textPrimary)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Masukkan durasi',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() => _exactEnd = null),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _unit,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'menit', child: Text('Menit')),
                              DropdownMenuItem(value: 'jam', child: Text('Jam')),
                              DropdownMenuItem(value: 'hari', child: Text('Hari')),
                              DropdownMenuItem(value: 'bulan', child: Text('Bulan')),
                            ],
                            onChanged: (value) => setState(() {
                              _unit = value ?? 'jam';
                              _exactEnd = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _pickExactEnd,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_exactEnd == null ? 'Pilih tanggal dan jam berakhir' : 'Berakhir: ${_exactEnd!.day}/${_exactEnd!.month}/${_exactEnd!.year} • ${_exactEnd!.hour.toString().padLeft(2, '0')}:${_exactEnd!.minute.toString().padLeft(2, '0')}'),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: SectionLead('Aplikasi yang diblokir'),
                ),
                Text('${_selected.length} dipilih', style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
              ],
            ),
            apps.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const AppEmptyState(
                compact: true,
                icon: Icons.error_outline_rounded,
                title: 'Tidak dapat memuat daftar aplikasi',
              ),
              data: (items) => RowGroup(
                children: [
                  for (final app in items)
                    AppListRow(
                      title: app.label,
                      subtitle: app.packageName,
                      leading: const IconBadge(icon: Icons.apps_rounded),
                      onTap: () => setState(() {
                        if (!_selected.add(app.packageName)) {
                          _selected.remove(app.packageName);
                        }
                      }),
                      trailing: Checkbox(
                        value: _selected.contains(app.packageName),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(app.packageName);
                          } else {
                            _selected.remove(app.packageName);
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
            VaultButton(
              label: 'Aktifkan Mode Ketat',
              onPressed: _start,
            ),
            Text(
              'Sebelum aktif, OpenLock akan meminta izin yang diperlukan untuk menjalankan perlindungan.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveMetric extends StatelessWidget {
  const _ActiveMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = SuiteColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.labelStrong.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }
}
