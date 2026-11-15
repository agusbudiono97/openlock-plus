import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/core/di.dart';

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

    if (active) {
      final endAt = switch (config.strictModeEndsAtMillis) {
        final millis? => DateTime.fromMillisecondsSinceEpoch(millis).toLocal(),
        null => null,
      };
      final remaining = endAt?.difference(DateTime.now());
      final end = switch (endAt) {
        final date? => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        null => 'Tanpa batas waktu',
      };
      return Scaffold(
        appBar: AppBar(title: const Text('Mode Ketat')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 42,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'KOMITMEN SEDANG AKTIF',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                letterSpacing: 1.2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mode Ketat aktif',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${config.strictModePackages.length} aplikasi sedang diblokir',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        if (remaining != null)
                          Text(
                            remaining.isNegative
                                ? 'Waktu perlindungan habis'
                                : '${remaining.inDays} hari ${(remaining.inHours % 24).toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                          )
                        else
                          Text(
                            'TANPA BATAS WAKTU',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        const SizedBox(height: 8),
                        Text('Berakhir: $end', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'APLIKASI YANG DIBLOKIR',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                apps.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Daftar aplikasi tidak dapat dimuat.'),
                  data: (items) {
                    final selected = items.where((app) =>
                        config.strictModePackages.contains(app.packageName));
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final app in selected)
                          const Chip(
                            avatar: Icon(Icons.block_rounded, size: 16),
                            label: Text(app.label),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Pengaturan dikunci'),
                    subtitle: const Text(
                      'Daftar aplikasi dan pengaturan perlindungan tidak dapat diubah sampai komitmen berakhir. Administrator perangkat dan Aksesibilitas membantu menghambat upaya menonaktifkan atau menghapus OpenLock.',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Android tetap memiliki kendali sistem yang tidak dapat dikunci mutlak oleh aplikasi biasa.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mode Ketat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Blokir aplikasi pilihan sampai waktunya berakhir. Tentukan durasi, tanggal berakhir, atau aktifkan tanpa batas waktu. Sebelum mulai, OpenLock akan meminta izin Administrator perangkat dan Aksesibilitas untuk memperkuat perlindungan dari uninstall dan perubahan pengaturan.',
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tanpa batas waktu'),
            subtitle: const Text('Tidak ada waktu berakhir otomatis'),
            value: _indefinite,
            onChanged: (value) => setState(() {
              _indefinite = value;
              if (value) _exactEnd = null;
            }),
          ),
          if (!_indefinite) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Durasi', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() => _exactEnd = null),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _unit,
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
              ],
            ),
            TextButton.icon(
              onPressed: _pickExactEnd,
              icon: const Icon(Icons.event),
              label: Text(_exactEnd == null ? 'Atau pilih tanggal dan jam berakhir' : 'Berakhir: $_exactEnd'),
            ),
          ],
          const Divider(height: 32),
          Text('Aplikasi yang diblokir (${_selected.length} dipilih)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          apps.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Tidak dapat memuat daftar aplikasi.'),
            data: (items) => Column(
              children: [
                for (final app in items)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(app.label),
                    subtitle: Text(app.packageName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    value: _selected.contains(app.packageName),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(app.packageName);
                      } else {
                        _selected.remove(app.packageName);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.lock),
            label: const Text('Aktifkan Mode Ketat'),
          ),
        ],
      ),
    );
  }
}
