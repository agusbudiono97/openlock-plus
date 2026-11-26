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

  String _unitLabel() {
    switch (_unit) {
      case 'menit':
        return 'Menit';
      case 'hari':
        return 'Hari';
      case 'bulan':
        return 'Bulan';
      default:
        return 'Jam';
    }
  }

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

      final isDark = Theme.of(context).brightness == Brightness.dark;
      const violet = Color(0xFF9B5CFF), pink = Color(0xFFFF6B9D), amber = Color(0xFFFFA726);
      final background = isDark ? const Color(0xFF070611) : const Color(0xFFF7F4FC);
      final panel = isDark ? const Color(0xFF0D0B1B) : Colors.white;
      final panelAlt = isDark ? const Color(0xFF151126) : const Color(0xFFF0EAF9);
      final primaryText = isDark ? const Color(0xFFF7F4FF) : const Color(0xFF211A30);
      final secondaryText = isDark ? const Color(0xFFADB0C8) : const Color(0xFF716B82);
      final outline = isDark ? const Color(0xFF30264B) : const Color(0xFFE4D9F2);

      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background, surfaceTintColor: Colors.transparent, elevation: 0,
          leading: IconButton(tooltip: 'Kembali', icon: Icon(Icons.arrow_back_rounded, color: primaryText), onPressed: () => Navigator.of(context).maybePop()),
          titleSpacing: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mode Ketat', style: TextStyle(color: primaryText, fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Komitmen dan fokus', style: TextStyle(color: secondaryText, fontSize: 11.5)),
          ]),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16, top: 9, bottom: 9), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(color: amber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: amber.withValues(alpha: 0.7)), boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.12), blurRadius: 12)]),
              child: const Row(children: [CircleAvatar(radius: 3, backgroundColor: amber), SizedBox(width: 7), Text('STRICT', style: TextStyle(color: amber, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8))]),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: violet.withValues(alpha: isDark ? 0.42 : 0.28)),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: isDark
                    ? const [Color(0xFF100C20), Color(0xFF090817), Color(0xFF171020)]
                    : const [Colors.white, Color(0xFFF8F1FF), Color(0xFFFFF5F0)]),
                  boxShadow: [BoxShadow(color: violet.withValues(alpha: isDark ? 0.10 : 0.08), blurRadius: 28), BoxShadow(color: amber.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(8, 10))],
                ),
                child: Column(children: [
                  Row(children: [
                    Container(width: 58, height: 58, decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), gradient: const LinearGradient(colors: [Color(0xFF5C3B9E), Color(0xFF251A42)]), border: Border.all(color: amber.withValues(alpha: 0.5)), boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.2), blurRadius: 18)]), child: const Icon(Icons.verified_user_rounded, color: amber, size: 32)),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('PERLINDUNGAN AKTIF', style: TextStyle(color: amber, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
                      const SizedBox(height: 5),
                      Text('Kamu sedang dalam Mode Ketat', style: TextStyle(color: primaryText, fontSize: 14.5, fontWeight: FontWeight.w700)),
                    ])),
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: amber.withValues(alpha: 0.14), shape: BoxShape.circle, boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.22), blurRadius: 16)]), child: const Icon(Icons.check_rounded, color: amber, size: 27)),
                  ]),
                  const SizedBox(height: 24),
                  LayoutBuilder(builder: (context, constraints) {
                    final timer = Container(
                      padding: const EdgeInsets.fromLTRB(14, 17, 14, 14),
                      decoration: BoxDecoration(color: panelAlt.withValues(alpha: isDark ? 0.42 : 0.78), borderRadius: BorderRadius.circular(20), border: Border.all(color: violet.withValues(alpha: 0.22))),
                      child: Column(children: [
                        Text(endAt == null ? 'PERLINDUNGAN PERMANEN' : 'WAKTU TERSISA', style: const TextStyle(color: violet, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                        const SizedBox(height: 13),
                        FittedBox(fit: BoxFit.scaleDown, child: ShaderMask(shaderCallback: (bounds) => const LinearGradient(colors: [violet, Color(0xFFFF83B8), amber]).createShader(bounds), child: Text(countdown, style: const TextStyle(color: Colors.white, fontSize: 39, fontWeight: FontWeight.w800, letterSpacing: -1.1, fontFeatures: [FontFeature.tabularFigures()])))),
                        const SizedBox(height: 14),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(13), border: Border.all(color: outline)), child: const Row(children: [Icon(Icons.hourglass_bottom_rounded, color: amber, size: 18), SizedBox(width: 8), Expanded(child: Text('Tetap fokus, raih versi terbaik.', style: TextStyle(color: Color(0xFFADB0C8), fontSize: 10.5, fontWeight: FontWeight.w600)))])),
                      ]),
                    );
                    final ring = Column(children: [
                      Text('KOMITMEN BERAKHIR', style: TextStyle(color: secondaryText, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      Container(width: 148, height: 148, padding: const EdgeInsets.all(7), decoration: BoxDecoration(shape: BoxShape.circle, gradient: const SweepGradient(colors: [violet, pink, amber, violet]), boxShadow: [BoxShadow(color: violet.withValues(alpha: 0.25), blurRadius: 22), BoxShadow(color: pink.withValues(alpha: 0.13), blurRadius: 30, offset: const Offset(0, 7))]), child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? const Color(0xFF100C20) : const Color(0xFFFFFAFF), border: Border.all(color: outline)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 34, height: 34, decoration: BoxDecoration(color: amber.withValues(alpha: 0.12), shape: BoxShape.circle), child: const Icon(Icons.event_available_rounded, color: amber, size: 19)),
                        const SizedBox(height: 7),
                        Text(endAt == null ? 'Status' : 'Tanggal berakhir', style: TextStyle(color: secondaryText, fontSize: 10.5)),
                        const SizedBox(height: 2),
                        Text(endAt == null ? '∞' : '\${endAt.hour.toString().padLeft(2, '0')}:\${endAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: amber, fontSize: 23, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                        Text(endAt == null ? 'Tanpa batas' : '\${endAt.day.toString().padLeft(2, '0')}/\${endAt.month.toString().padLeft(2, '0')}/\${endAt.year}', style: TextStyle(color: secondaryText, fontSize: 10)),
                      ]))),
                    ]);
                    if (constraints.maxWidth < 350) return Column(children: [timer, const SizedBox(height: 20), ring]);
                    return Row(children: [Expanded(flex: 11, child: timer), const SizedBox(width: 12), Expanded(flex: 9, child: ring)]);
                  }),
                  const SizedBox(height: 18),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13), decoration: BoxDecoration(color: panelAlt.withValues(alpha: isDark ? 0.48 : 0.8), borderRadius: BorderRadius.circular(17), border: Border.all(color: outline)), child: Row(children: [
                    Expanded(child: _ActiveMetric(label: 'Aplikasi dikunci', value: '\${config.strictModePackages.length}')),
                    Container(width: 1, height: 38, color: outline), const SizedBox(width: 12),
                    Expanded(flex: 2, child: _ActiveMetric(label: 'Berakhir pada', value: endLabel)),
                  ])),
                ]),
              ),
              const SizedBox(height: 26),
              Text('Aplikasi yang dilindungi', style: TextStyle(color: primaryText, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              apps.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                error: (_, __) => const AppEmptyState(compact: true, icon: Icons.error_outline_rounded, title: 'Daftar aplikasi tidak dapat dimuat'),
                data: (items) {
                  final selected = items.where((app) => config.strictModePackages.contains(app.packageName)).toList();
                  if (selected.isEmpty) return const AppEmptyState(compact: true, icon: Icons.apps_rounded, title: 'Tidak ada aplikasi terdaftar');
                  return Column(children: [for (final app in selected) Container(
                    margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(19), border: Border.all(color: outline), boxShadow: [BoxShadow(color: violet.withValues(alpha: isDark ? 0.07 : 0.035), blurRadius: 16)]),
                    child: Row(children: [
                      SizedBox(width: 48, height: 48, child: _StrictAppIcon(app: app)), const SizedBox(width: 13),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: primaryText, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4), Text('Dikunci sampai komitmen berakhir', style: TextStyle(color: secondaryText, fontSize: 11.5)),
                      ])),
                      const SizedBox(width: 8),
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: violet.withValues(alpha: 0.18), shape: BoxShape.circle, boxShadow: [BoxShadow(color: violet.withValues(alpha: 0.12), blurRadius: 12)]), child: const Icon(Icons.check_rounded, color: violet, size: 22)),
                    ]),
                  )]);
                },
              ),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: violet.withValues(alpha: 0.25)), boxShadow: [BoxShadow(color: violet.withValues(alpha: 0.07), blurRadius: 18)]), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF5A3B9A), Color(0xFF24183D)]), boxShadow: [BoxShadow(color: violet.withValues(alpha: 0.2), blurRadius: 16)]), child: const Icon(Icons.lock_rounded, color: Color(0xFFC59BFF), size: 27)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pengaturan sedang dikunci', style: TextStyle(color: primaryText, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Text('Daftar aplikasi dan pengaturan perlindungan tidak dapat diubah sampai komitmen berakhir.', style: TextStyle(color: secondaryText, fontSize: 12, height: 1.5)),
                ])),
              ])),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: outline)), child: Row(children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, color: violet.withValues(alpha: 0.14), border: Border.all(color: violet.withValues(alpha: 0.24))), child: const Icon(Icons.shield_moon_rounded, color: violet, size: 30)),
                const SizedBox(width: 13),
                Expanded(child: Text('Android tetap memiliki kendali sistem yang tidak dapat dikunci mutlak oleh aplikasi biasa.', style: TextStyle(color: isDark ? const Color(0xFFC4A4FF) : const Color(0xFF7650A8), fontSize: 12, height: 1.5, fontWeight: FontWeight.w600))),
              ])),
            ]),
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
    final borderColor = scheme.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.55);
    final deadline = _deadline();
    final remaining = deadline?.difference(DateTime.now());
    final durationLabel = _indefinite
        ? '∞'
        : remaining == null
            ? '—'
            : remaining.inDays > 0
                ? '${remaining.inDays}h ${(remaining.inHours % 24).toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}'
                : '${remaining.inHours.toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}';
    final targetLabel = _indefinite
        ? 'Tidak ada waktu berakhir'
        : deadline == null
            ? 'Atur durasi perlindungan'
            : '${deadline.day.toString().padLeft(2, '0')}/${deadline.month.toString().padLeft(2, '0')} • ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
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
              color: amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: amber.withValues(alpha: 0.42)),
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
              boxShadow: [BoxShadow(color: amber.withValues(alpha: 0.24), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.lock_rounded, size: 20, color: Color(0xFF171717)),
                label: Text(
                  'Aktifkan Mode Ketat ($selectedCount Aplikasi)',
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF211A32), Color(0xFF30231F)]
                        : const [Color(0xFFF1EAFB), Color(0xFFFFF1E3)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: amber.withValues(alpha: isDark ? 0.13 : 0.22)),
                  boxShadow: [
                    BoxShadow(
                      color: amber.withValues(alpha: isDark ? 0.07 : 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: amber),
                        SizedBox(width: 7),
                        Text(
                          'ZONA VAULT OTONOM',
                          style: TextStyle(color: amberLight, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: borderColor),
                              ),
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
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            durationLabel,
                                            style: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(_unitLabel(), style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(child: _QuickDurationButton(label: '+30m', onTap: () => _setQuickDuration(30), cardColor: pageBg, textColor: textPrimary, borderColor: borderColor)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _QuickDurationButton(label: '+1 Jam', onTap: () => _setQuickDuration(60), cardColor: pageBg, textColor: textPrimary, borderColor: borderColor)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                    decoration: BoxDecoration(color: pageBg, borderRadius: BorderRadius.circular(9)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event_available_rounded, color: amber, size: 14),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            targetLabel,
                                            style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
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
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFFF59E0B), Color(0xFFFB7185)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(color: amber.withValues(alpha: 0.28), blurRadius: 17, spreadRadius: 1),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(5),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? const Color(0xFF211A2B) : const Color(0xFFFFF8EF),
                                      ),
                                      child: const Icon(Icons.lock_rounded, color: amber, size: 27),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text('STATUS TARGET', style: TextStyle(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                                  const SizedBox(height: 3),
                                  Text(
                                    selectedCount == 0 ? 'Pilih Aplikasi' : 'Siap Dikunci',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Protokol Anti-Bypass', textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: amber.withValues(alpha: 0.10), shape: BoxShape.circle),
                            child: const Icon(Icons.all_inclusive_rounded, color: amberLight, size: 18),
                          ),
                          const SizedBox(width: 11),
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
                            activeThumbColor: amber,
                            onChanged: (value) => setState(() {
                              _indefinite = value;
                              if (value) _exactEnd = null;
                            }),
                          ),
                        ],
                      ),
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
                                : 'Berakhir ${_exactEnd!.day}/${_exactEnd!.month}/${_exactEnd!.year} • ${_exactEnd!.hour.toString().padLeft(2, '0')}:${_exactEnd!.minute.toString().padLeft(2, '0')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(foregroundColor: amber, side: BorderSide(color: amber.withValues(alpha: 0.45)), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
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
                  border: Border.all(color: danger.withValues(alpha: 0.28)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: danger.withValues(alpha: 0.12), shape: BoxShape.circle),
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
                        decoration: BoxDecoration(color: amber.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                        child: Text('$selectedCount Dipilih', style: const TextStyle(color: amber, fontSize: 10.5, fontWeight: FontWeight.w800)),
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
                  hintText: 'Cari aplikasi atau nama paket...',
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
  Widget build(BuildContext context) => Material(
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
    color: selected ? amber.withValues(alpha: 0.12) : (isDark ? Colors.white.withValues(alpha: 0.035) : Colors.black.withValues(alpha: 0.025)),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? amber.withValues(alpha: 0.5) : borderColor)),
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
    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? amber.withValues(alpha: 0.42) : borderColor)),
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? amber : Colors.transparent, border: Border.all(color: selected ? amber : mutedColor.withValues(alpha: 0.45), width: 1.5)),
              child: Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 17, color: selected ? const Color(0xFF171717) : mutedColor),
            ),
          ],
        ),
      ),
    ),
  );
}
