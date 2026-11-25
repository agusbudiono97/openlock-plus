import 'dart:async';
import 'dart:io';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/core/widgets/screen_header.dart';

class StrictModeScreen extends ConsumerStatefulWidget {
  const StrictModeScreen({super.key});

  @override
  ConsumerState<StrictModeScreen> createState() => _StrictModeScreenState();
}

class _StrictModeScreenState extends ConsumerState<StrictModeScreen> {
  final _amount = TextEditingController(text: '1');
  final _appSearch = TextEditingController();
  String _appQuery = '';
  final Set<String> _selected = {};
  String _unit = 'jam';
  bool _indefinite = false;
  DateTime? _exactEnd;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
  }

  // The one-second repaint is needed only while the active countdown is
  // visible. Avoid rebuilding the entire app picker every second while the
  // user is configuring a commitment.
  void _syncClock(bool active) {
    if (active && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!active && _clock != null) {
      _clock?.cancel();
      _clock = null;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _amount.dispose();
    _appSearch.dispose();
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


  String _appFilter = 'Semua';

  void _setQuickDuration(int minutes) {
    final current = _deadline();
    final base = current != null && current.isAfter(DateTime.now()) ? current : DateTime.now();
    setState(() {
      _indefinite = false;
      _exactEnd = base.add(Duration(minutes: minutes));
    });
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
    final configAsync = ref.watch(configControllerProvider);
    if (configAsync.isLoading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (configAsync.hasError) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Text('Pengaturan perlindungan gagal dimuat. Tutup lalu buka kembali OpenLock.'),
          ),
        ),
      );
    }
    final config = configAsync.value ?? LockConfig.empty;
    final active = config.strictModeActiveAt(DateTime.now());
    _syncClock(active);
    final apps = ref.watch(installedAppsProvider);
    final colors = SuiteColors.of(context);
    final scheme = Theme.of(context).colorScheme;

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
                          leading: _StrictAppIcon(app: app),
                          trailing: Icon(Icons.check_circle_rounded, color: scheme.primary),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const amber = Color(0xFFF59E0B);
    const amberLight = Color(0xFFFBBF24);
    const danger = Color(0xFFF43F5E);
    final pageBg = scheme.surface;
    final cardBg = isDark ? const Color(0xFF1A1C26) : scheme.surfaceContainerLow;
    final textPrimary = scheme.onSurface;
    final textMuted = scheme.onSurfaceVariant;
    final borderColor = scheme.outlineVariant.withOpacity(isDark ? 0.22 : 0.55);
    final deadline = _deadline();
    final remaining = deadline?.difference(DateTime.now());
    final durationLabel = _indefinite
        ? '∞'
        : remaining == null
            ? '—'
            : remaining.inDays > 0
                ? remaining.inDays.toString() + 'h ' + (remaining.inHours % 24).toString().padLeft(2, '0') + ':' + (remaining.inMinutes % 60).toString().padLeft(2, '0')
                : remaining.inHours.toString().padLeft(2, '0') + ':' + (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final targetLabel = _indefinite
        ? 'Tidak ada waktu berakhir'
        : deadline == null
            ? 'Atur durasi perlindungan'
            : deadline.day.toString().padLeft(2, '0') + '/' + deadline.month.toString().padLeft(2, '0') + ' • ' + deadline.hour.toString().padLeft(2, '0') + ':' + deadline.minute.toString().padLeft(2, '0');
    final selectedCount = _selected.length;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mode Ketat', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Bangun kebiasaan lebih baik', style: TextStyle(color: textMuted, fontSize: 11)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: amber.withOpacity(0.42)),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: amber),
                SizedBox(width: 6),
                Text('STRICT', style: TextStyle(color: amber, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [amber, Color(0xFFFB7185)]),
              boxShadow: [BoxShadow(color: amber.withOpacity(0.24), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.lock_rounded, size: 20, color: Color(0xFF171717)),
                label: Text(
                  'Aktifkan Mode Ketat (' + selectedCount.toString() + ' Aplikasi)',
                  style: const TextStyle(color: Color(0xFF171717), fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      CircleAvatar(radius: 3, backgroundColor: amber),
                      SizedBox(width: 7),
                      Text('ZONA VAULT OTONOM', style: TextStyle(color: amberLight, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.shield_moon_rounded, color: amber, size: 14),
                      const SizedBox(width: 4),
                      Text('Perlindungan OpenLock', style: TextStyle(color: textMuted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Durasi Kunci', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                              const Icon(Icons.timer_outlined, color: amber, size: 17),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(durationLabel, style: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                          ),
                          const SizedBox(height: 2),
                          Text(_indefinite ? 'Tanpa batas' : 'Durasi komitmen', style: TextStyle(color: textMuted, fontSize: 10.5)),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              Expanded(child: _QuickDurationButton(label: '+30 mnt', onTap: () => _setQuickDuration(30), cardColor: pageBg, textColor: textPrimary, borderColor: borderColor)),
                              const SizedBox(width: 7),
                              Expanded(child: _QuickDurationButton(label: '+1 jam', onTap: () => _setQuickDuration(60), cardColor: pageBg, textColor: textPrimary, borderColor: borderColor)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                            decoration: BoxDecoration(color: pageBg, borderRadius: BorderRadius.circular(9)),
                            child: Row(
                              children: [
                                const Icon(Icons.event_outlined, color: amber, size: 14),
                                const SizedBox(width: 6),
                                Expanded(child: Text(targetLabel, style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: amber.withOpacity(isDark ? 0.10 : 0.13),
                              border: Border.all(color: amber.withOpacity(0.55), width: 1.5),
                              boxShadow: [BoxShadow(color: amber.withOpacity(0.16), blurRadius: 16, spreadRadius: 2)],
                            ),
                            child: const Icon(Icons.lock_rounded, color: amber, size: 26),
                          ),
                          const SizedBox(height: 10),
                          Text('STATUS TARGET', style: TextStyle(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                          const SizedBox(height: 3),
                          Text(selectedCount == 0 ? 'Siap diatur' : selectedCount.toString() + ' Aplikasi', textAlign: TextAlign.center, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Menunggu aktivasi', textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: amber.withOpacity(0.10), shape: BoxShape.circle),
                      child: const Icon(Icons.all_inclusive_rounded, color: amberLight, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tanpa Batas Waktu', style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('Perlindungan tidak berakhir otomatis', style: TextStyle(color: textMuted, fontSize: 10.5)),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _indefinite,
                      activeColor: amber,
                      onChanged: (value) => setState(() {
                        _indefinite = value;
                        if (value) _exactEnd = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!_indefinite)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Atur durasi perlindungan', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _amount,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText: 'Durasi',
                                filled: true,
                                fillColor: pageBg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
                              ),
                              onChanged: (_) => setState(() => _exactEnd = null),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _unit,
                              style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: pageBg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 15),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
                              ),
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
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickExactEnd,
                          icon: const Icon(Icons.calendar_month_rounded, size: 18),
                          label: Text(
                            _exactEnd == null
                                ? 'Pilih tanggal dan jam berakhir'
                                : 'Berakhir ' + _exactEnd!.day.toString() + '/' + _exactEnd!.month.toString() + '/' + _exactEnd!.year.toString() + ' • ' + _exactEnd!.hour.toString().padLeft(2, '0') + ':' + _exactEnd!.minute.toString().padLeft(2, '0'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(foregroundColor: amber, side: BorderSide(color: amber.withOpacity(0.45)), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF24151B) : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: danger.withOpacity(0.28)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: danger.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.error_outline_rounded, color: danger, size: 18),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text('Peringatan Proteksi Keras', style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800))),
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: danger, borderRadius: BorderRadius.circular(6)),
                                child: const Text('KETAT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text('Mode Ketat tidak dapat diakhiri lebih awal dari dalam aplikasi. Pastikan aplikasi dan durasi yang dipilih sudah benar sebelum mengaktifkan perlindungan.', style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B), fontSize: 10.5, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Aplikasi Terkunci', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: amber.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                        child: Text(selectedCount.toString() + ' Dipilih', style: const TextStyle(color: amber, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => apps.whenData((items) => setState(() {
                      final allSelected = items.isNotEmpty && items.every((app) => _selected.contains(app.packageName));
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(items.map((app) => app.packageName));
                      }
                    })),
                    child: const Text('Pilih Semua', style: TextStyle(color: amber, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _AppFilterChip(label: 'Semua', selected: _appFilter == 'Semua', onTap: () => setState(() => _appFilter = 'Semua'), amber: amber, muted: textMuted, borderColor: borderColor, isDark: isDark),
                  _AppFilterChip(label: 'Dipilih', selected: _appFilter == 'Dipilih', onTap: () => setState(() => _appFilter = 'Dipilih'), amber: amber, muted: textMuted, borderColor: borderColor, isDark: isDark),
                  _AppFilterChip(label: 'Belum dipilih', selected: _appFilter == 'Belum dipilih', onTap: () => setState(() => _appFilter = 'Belum dipilih'), amber: amber, muted: textMuted, borderColor: borderColor, isDark: isDark),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _appSearch,
                onChanged: (value) => setState(() => _appQuery = value.trim().toLowerCase()),
                textInputAction: TextInputAction.search,
                style: TextStyle(color: textPrimary, fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Cari aplikasi...',
                  hintStyle: TextStyle(color: textMuted, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded, color: textMuted, size: 19),
                  suffixIcon: _appQuery.isEmpty ? null : IconButton(
                    tooltip: 'Hapus pencarian',
                    onPressed: () {
                      _appSearch.clear();
                      setState(() => _appQuery = '');
                    },
                    icon: Icon(Icons.close_rounded, color: textMuted),
                  ),
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: amber)),
                ),
              ),
              const SizedBox(height: 12),
              apps.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (_, __) => const AppEmptyState(compact: true, icon: Icons.error_outline_rounded, title: 'Tidak dapat memuat daftar aplikasi'),
                data: (items) {
                  final query = _appQuery;
                  final filtered = items.where((app) {
                    final matchesSearch = app.label.toLowerCase().contains(query) || app.packageName.toLowerCase().contains(query);
                    final selected = _selected.contains(app.packageName);
                    final matchesFilter = _appFilter == 'Semua' || (_appFilter == 'Dipilih' ? selected : !selected);
                    return matchesSearch && matchesFilter;
                  }).toList();
                  if (filtered.isEmpty) {
                    return AppEmptyState(compact: true, icon: Icons.search_off_rounded, title: query.isEmpty ? 'Tidak ada aplikasi pada filter ini' : 'Aplikasi tidak ditemukan', message: 'Ubah filter atau kata pencarian.');
                  }
                  return Column(
                    children: [
                      for (final app in filtered)
                        _BentoAppRow(
                          app: app,
                          selected: _selected.contains(app.packageName),
                          cardColor: cardBg,
                          textColor: textPrimary,
                          mutedColor: textMuted,
                          borderColor: borderColor,
                          amber: amber,
                          onTap: () => setState(() {
                            if (!_selected.add(app.packageName)) _selected.remove(app.packageName);
                          }),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text('Sebelum aktif, OpenLock akan memeriksa izin yang diperlukan untuk menjalankan perlindungan.', textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 10.5, height: 1.4)),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}


const double _strictAppIconSize = 40;

/// Reuses the same native launcher-icon cache as the main app list.
class _StrictAppIcon extends ConsumerWidget {
  const _StrictAppIcon({required this.app});

  final InstalledApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loader = ref.watch(appIconLoaderProvider);
    if (loader.isResolved(app)) {
      return _icon(context, loader.resolvedPath(app));
    }
    return FutureBuilder<String?>(
      future: loader.pathFor(app),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _fallback(context);
        if (snapshot.connectionState == ConnectionState.done) {
          return _icon(context, snapshot.data);
        }
        return _placeholder(context);
      },
    );
  }

  Widget _icon(BuildContext context, String? path) {
    if (path == null) return _fallback(context);
    final px = (_strictAppIconSize * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path),
        width: _strictAppIconSize,
        height: _strictAppIconSize,
        cacheWidth: px,
        cacheHeight: px,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) => SizedBox.square(
        dimension: _strictAppIconSize,
        child: Icon(Icons.android, color: SuiteColors.of(context).textSecondary),
      );

  Widget _placeholder(BuildContext context) => SizedBox.square(
        dimension: _strictAppIconSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SuiteColors.of(context).surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
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


class _QuickDurationButton extends StatelessWidget {
  const _QuickDurationButton({required this.label, required this.onTap, required this.cardColor, required this.textColor, required this.borderColor});
  final String label;
  final VoidCallback onTap;
  final Color cardColor;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
          child: Center(child: Text(label, style: TextStyle(color: textColor, fontSize: 10.5, fontWeight: FontWeight.w800))),
        ),
      ),
    ),
  );
}

class _AppFilterChip extends StatelessWidget {
  const _AppFilterChip({required this.label, required this.selected, required this.onTap, required this.amber, required this.muted, required this.borderColor, required this.isDark});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color amber;
  final Color muted;
  final Color borderColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? amber.withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.035) : Colors.black.withOpacity(0.025)),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? amber.withOpacity(0.5) : borderColor)),
        child: Text(label, style: TextStyle(color: selected ? amber : muted, fontSize: 11.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
      ),
    ),
  );
}

class _BentoAppRow extends StatelessWidget {
  const _BentoAppRow({required this.app, required this.selected, required this.cardColor, required this.textColor, required this.mutedColor, required this.borderColor, required this.amber, required this.onTap});
  final InstalledApp app;
  final bool selected;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;
  final Color amber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? amber.withOpacity(0.42) : borderColor)),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            SizedBox(width: 42, height: 42, child: _StrictAppIcon(app: app)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(app.packageName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mutedColor, fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? amber : Colors.transparent, border: Border.all(color: selected ? amber : mutedColor.withOpacity(0.45), width: 1.5)),
              child: Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 17, color: selected ? const Color(0xFF171717) : mutedColor),
            ),
          ],
        ),
      ),
    ),
  );
}
