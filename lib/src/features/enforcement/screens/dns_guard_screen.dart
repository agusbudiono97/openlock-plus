import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';

class DnsGuardScreen extends ConsumerStatefulWidget {
  const DnsGuardScreen({super.key});

  @override
  ConsumerState<DnsGuardScreen> createState() => _DnsGuardScreenState();
}

class _DnsGuardScreenState extends ConsumerState<DnsGuardScreen> {
  final _amount = TextEditingController(text: '1');
  String _unit = 'jam';
  DateTime? _exactEnd;
  bool _indefinite = false;
  Timer? _clock;

  @override
  void dispose() {
    _clock?.cancel();
    _amount.dispose();
    super.dispose();
  }

  DateTime? _deadline() {
    if (_indefinite) return null;
    if (_exactEnd != null) return _exactEnd;
    final amount = int.tryParse(_amount.text);
    if (amount == null || amount < 1) return null;
    final now = DateTime.now();
    switch (_unit) {
      case 'menit':
        return now.add(Duration(minutes: amount));
      case 'jam':
        return now.add(Duration(hours: amount));
      case 'hari':
        return now.add(Duration(days: amount));
      case 'bulan':
        final monthIndex = now.month - 1 + amount;
        final year = now.year + monthIndex ~/ 12;
        final month = monthIndex % 12 + 1;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, now.day.clamp(1, lastDay), now.hour, now.minute);
      default:
        return null;
    }
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _exactEnd != null && _exactEnd!.isAfter(now)
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
    final end = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!end.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waktu berakhir harus di masa depan.')),
      );
      return;
    }
    setState(() {
      _exactEnd = end;
      _indefinite = false;
    });
  }

  Future<void> _enable() async {
    final current = ref.read(configControllerProvider).valueOrNull ?? LockConfig.empty;
    if (current.strictModeActiveAt(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tunggu Mode Ketat berakhir sebelum mengaktifkan DNS Guard.')),
      );
      return;
    }
    final end = _deadline();
    if (!_indefinite && (end == null || !end.isAfter(DateTime.now()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih durasi atau tanggal akhir yang valid.')),
      );
      return;
    }
    final bridge = ref.read(enforcementBridgeProvider);
    var permissions = await bridge.getPermissionStates();
    if (!permissions.screenGuardAccess) {
      await bridge.requestScreenGuardAccess();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktifkan Aksesibilitas OpenLock, lalu kembali dan aktifkan DNS Guard lagi.')),
      );
      return;
    }
    if (!await bridge.isDeviceAdminActive()) {
      await bridge.requestDeviceAdmin();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktifkan Administrator perangkat, lalu kembali dan aktifkan DNS Guard lagi.')),
      );
      return;
    }
    try {
      await bridge.startService();
      await ref.read(configControllerProvider.notifier).setDnsGuard(
        enabled: true,
        endsAtMillis: end?.millisecondsSinceEpoch,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DNS Guard gagal diaktifkan: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final now = DateTime.now();
    final active = config.dnsGuardActiveAt(now);
    if (active && config.dnsGuardEndsAtMillis != null) {
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _clock?.cancel();
      _clock = null;
    }
    final end = config.dnsGuardEndsAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(config.dnsGuardEndsAtMillis!).toLocal();
    final remaining = end?.difference(now);
    final timeLabel = remaining == null
        ? 'Tanpa batas waktu'
        : remaining.isNegative
            ? '00:00'
            : '${remaining.inDays > 0 ? '${remaining.inDays} hari ' : ''}${(remaining.inHours % 24).toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('DNS Guard')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.shield_outlined, size: 30),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      active ? 'DNS Guard aktif' : 'Lindungi pengaturan DNS',
                      style: Theme.of(context).textTheme.titleLarge,
                    )),
                    Icon(active ? Icons.verified : Icons.shield_outlined,
                        color: active ? Colors.green : null),
                  ]),
                  const SizedBox(height: 10),
                  Text(active
                      ? 'Akses ke halaman DNS Pribadi akan ditolak. Pengaturan HP lainnya tetap dapat digunakan.'
                      : 'Saat aktif, OpenLock akan menutup akses ke halaman DNS Pribadi, termasuk hasil pencarian di Pengaturan.'),
                  if (active) ...[
                    const SizedBox(height: 16),
                    Text(timeLabel, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(end == null
                        ? 'Perlindungan tidak memiliki batas waktu.'
                        : 'Berakhir: ${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year} • ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'),
                  ],
                ],
              ),
            ),
          ),
          if (!active) ...[
            const SizedBox(height: 22),
            Text('Atur durasi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  enabled: !_indefinite && _exactEnd == null,
                  decoration: const InputDecoration(labelText: 'Jumlah', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Satuan', border: OutlineInputBorder()),
                  items: const ['menit', 'jam', 'hari', 'bulan']
                      .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                      .toList(),
                  onChanged: _indefinite || _exactEnd != null
                      ? null
                      : (value) => setState(() => _unit = value ?? 'jam'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickEnd,
              icon: const Icon(Icons.calendar_month),
              label: Text(_exactEnd == null
                  ? 'Pilih tanggal dan jam berakhir'
                  : 'Berakhir ${_exactEnd!.day}/${_exactEnd!.month}/${_exactEnd!.year} • ${_exactEnd!.hour.toString().padLeft(2, '0')}:${_exactEnd!.minute.toString().padLeft(2, '0')}'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _indefinite,
              title: const Text('Tanpa batas waktu'),
              onChanged: (value) => setState(() {
                _indefinite = value ?? false;
                if (_indefinite) _exactEnd = null;
              }),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _enable,
              icon: const Icon(Icons.lock),
              label: const Text('Aktifkan DNS Guard'),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'DNS Guard memerlukan Aksesibilitas dan Administrator perangkat OpenLock. Perlindungan ini bersifat best-effort: Android tetap dapat menghentikan aplikasi atau menonaktifkan Accessibility melalui jalur sistem tertentu.',
          ),
        ],
      ),
    );
  }
}
