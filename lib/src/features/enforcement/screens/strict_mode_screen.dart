import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';

class StrictModeScreen extends ConsumerStatefulWidget {
  const StrictModeScreen({super.key});

  @override
  ConsumerState<StrictModeScreen> createState() => _StrictModeScreenState();
}

class _StrictModeScreenState extends ConsumerState<StrictModeScreen> {
  final _amount = TextEditingController(text: '1');
  final Set<String> _selected = {};
  String _unit = 'hours';
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
      case 'minutes':
        return now.add(Duration(minutes: value));
      case 'hours':
        return now.add(Duration(hours: value));
      case 'days':
        return now.add(Duration(days: value));
      case 'months':
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
        const SnackBar(content: Text('Choose at least one app to block.')),
      );
      return;
    }
    final end = _deadline();
    if (!_indefinite && end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid duration or end date.')),
      );
      return;
    }
    await ref.read(configControllerProvider.notifier).setStrictMode(
      enabled: true,
      packages: Set.of(_selected),
      endsAtMillis: end?.millisecondsSinceEpoch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final active = config.strictModeActiveAt(DateTime.now());
    final apps = ref.watch(installedAppsProvider);

    if (active) {
      final end = config.strictModeEndsAtMillis == null
          ? 'Indefinitely'
          : DateTime.fromMillisecondsSinceEpoch(config.strictModeEndsAtMillis!).toLocal().toString();
      return Scaffold(
        appBar: AppBar(title: const Text('Strict Mode')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock, size: 64),
                const SizedBox(height: 16),
                const Text('Strict Mode is active', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(config.strictModePackages.length.toString() + ' apps are blocked.'),
                const SizedBox(height: 8),
                Text('Ends: $end', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text('This screen does not provide an early-stop button. Android system-level bypasses may still exist.', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Strict Mode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Block selected apps until the timer ends. Choose an end time or run indefinitely.'),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Indefinite'),
            subtitle: const Text('No automatic end time'),
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
                    decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() => _exactEnd = null),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _unit,
                  items: const [
                    DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                    DropdownMenuItem(value: 'hours', child: Text('Hours')),
                    DropdownMenuItem(value: 'days', child: Text('Days')),
                    DropdownMenuItem(value: 'months', child: Text('Months')),
                  ],
                  onChanged: (value) => setState(() {
                    _unit = value ?? 'hours';
                    _exactEnd = null;
                  }),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _pickExactEnd,
              icon: const Icon(Icons.event),
              label: Text(_exactEnd == null ? 'Or choose exact end date & time' : 'End: $_exactEnd'),
            ),
          ],
          const Divider(height: 32),
          Text('Apps to block (' + _selected.length.toString() + ' selected)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          apps.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Could not load installed apps.'),
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
            label: const Text('Start Strict Mode'),
          ),
        ],
      ),
    );
  }
}
