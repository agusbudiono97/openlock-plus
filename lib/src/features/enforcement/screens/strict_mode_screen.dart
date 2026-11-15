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

  @override
  void dispose() {
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
        return DateTime(now.year, now.month + value, now.day, now.hour, now.minute);
      default:
        return null;
    }
  }

  Future<void> _pickExactEnd() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _exactEnd ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_exactEnd ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _exactEnd = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
    if (!_indefinite && end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan durasi atau waktu berakhir yang valid.')),
      );
      return;
    }
    final permissions = await ref.read(enforcementBridgeProvider).getPermissionStates();
    if (!permissions.canEnforce) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktifkan Akses penggunaan dan Tampil di atas aplikasi lain pada menu Izin sebelum memulai.')),
        );
      }
      return;
    }
    await ref.read(configControllerProvider.notifier).setStrictMode(
      enabled: true,
      packages: Set.of(_selected),
      endsAtMillis: end?.millisecondsSinceEpoch,
    );
    await ref.read(enforcementBridgeProvider).startService();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final active = config.strictModeActiveAt(DateTime.now());
    final apps = ref.watch(installedAppsProvider);

    if (active) {
      final end = config.strictModeEndsAtMillis == null
          ? 'Tanpa batas waktu'
          : DateTime.fromMillisecondsSinceEpoch(config.strictModeEndsAtMillis!).toLocal().toString();
      return Scaffold(
        appBar: AppBar(title: const Text('Mode Ketat')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock, size: 64),
                const SizedBox(height: 16),
                const Text('Mode Ketat sedang aktif', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${config.strictModePackages.length} apps are blocked.'),
                const SizedBox(height: 8),
                Text('Berakhir: $end', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text('Tidak ada tombol untuk menghentikan lebih awal di halaman ini. Namun, celah melalui sistem Android masih mungkin terjadi.', textAlign: TextAlign.center),
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
          const Text('Blokir aplikasi pilihan sampai waktunya berakhir. Tentukan durasi, tanggal berakhir, atau aktifkan tanpa batas waktu.'),
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
