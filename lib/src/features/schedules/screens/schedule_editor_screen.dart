import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/schedules/models/lock_schedule.dart';
import 'package:openlock/src/features/schedules/widgets/schedule_format.dart';

class ScheduleEditorScreen extends ConsumerStatefulWidget {
  const ScheduleEditorScreen({this.scheduleId, super.key});
  final String? scheduleId;

  @override
  ConsumerState<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends ConsumerState<ScheduleEditorScreen> {
  static const _amber = Color(0xFFF59E0B);
  static const _rose = Color(0xFFFB7185);
  static const _violet = Color(0xFF8B5CF6);
  final _nameController = TextEditingController(text: 'Waktu fokus');
  final _searchController = TextEditingController();
  Set<int> _weekdays = {1, 2, 3, 4, 5};
  Set<String> _packages = {};
  int _start = 9 * 60;
  int _end = 17 * 60;
  bool _initialized = false;
  String _query = '';

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _hydrate(LockConfig config) {
    if (_initialized || widget.scheduleId == null) return;
    final matches = config.schedules.where((s) => s.id == widget.scheduleId);
    if (matches.isNotEmpty) {
      final existing = matches.first;
      _nameController.text = existing.name;
      _weekdays = Set.of(existing.weekdays);
      _start = existing.startMinutes;
      _end = existing.endMinutes;
      _packages = Set.of(existing.packages);
    }
    _initialized = true;
  }

  void _reset() {
    setState(() {
      _nameController.text = 'Waktu fokus';
      _weekdays = {1, 2, 3, 4, 5};
      _start = 9 * 60;
      _end = 17 * 60;
      _packages.clear();
    });
  }

  Future<void> _pickTime(bool start) async {
    final value = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked.hour * 60 + picked.minute;
      } else {
        _end = picked.hour * 60 + picked.minute;
      }
    });
  }

  Future<void> _save() async {
    final schedule = LockSchedule(
      id: widget.scheduleId,
      name: _nameController.text.trim().isEmpty ? 'Jadwal' : _nameController.text.trim(),
      packages: _packages,
      weekdays: _weekdays,
      startMinutes: _start,
      endMinutes: _end,
      enabled: true,
    );
    await ref.read(configControllerProvider.notifier).upsertSchedule(schedule);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    if (widget.scheduleId != null) {
      await ref.read(configControllerProvider.notifier).deleteSchedule(widget.scheduleId!);
    }
    if (mounted) context.pop();
  }

  String _duration() {
    final minutes = (_end - _start + 1440) % 1440;
    final total = minutes == 0 ? 24 * 60 : minutes;
    final h = total ~/ 60;
    final m = total % 60;
    return 'Durasi Total: ${h > 0 ? '$h jam' : ''}${h > 0 && m > 0 ? ' ' : ''}${m > 0 ? '$m menit' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF11101A) : const Color(0xFFF7F9FC);
    final card = dark ? const Color(0xFF1E1B29) : Colors.white;
    final sub = dark ? const Color(0xFF302C3B) : const Color(0xFFF0F4FA);
    final border = dark ? const Color(0xFF302D3B) : const Color(0xFFDCE4EF);
    final ink = dark ? const Color(0xFFF7F4FC) : const Color(0xFF111827);
    final muted = dark ? const Color(0xFFB8B1C5) : const Color(0xFF64748B);
    final configAsync = ref.watch(configControllerProvider);
    final loadedConfig = configAsync.valueOrNull;
    final config = loadedConfig ?? LockConfig.empty;
    if (loadedConfig != null) _hydrate(loadedConfig);
    final appsAsync = ref.watch(installedAppsProvider);
    final strictActive = config.strictModeActiveAt(DateTime.now()) ||
        config.dnsGuardActiveAt(DateTime.now());
    final isEditing = widget.scheduleId != null;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 12),
              child: Row(children: [
                IconButton(onPressed: () => context.pop(),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: ink, size: 21)),
                Expanded(child: Text(isEditing ? 'Ubah Jadwal' : 'Jadwal Baru',
                  style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800))),
                TextButton(onPressed: strictActive ? null : _reset,
                  child: const Text('Reset', style: TextStyle(color: _amber, fontSize: 12))),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: strictActive ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _amber, foregroundColor: const Color(0xFF392000),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                CircleAvatar(backgroundColor: _amber, radius: 17,
                  child: const Icon(Icons.person_outline_rounded, color: Color(0xFF392000), size: 19)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _surface(card, border, child: Row(children: [
                    Container(width: 42, height: 42,
                      decoration: BoxDecoration(color: _amber.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.lock_clock_rounded, color: _amber, size: 22)),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('MODE PROTEKSI OTONOM', style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .45)),
                      const SizedBox(height: 3),
                      Text(strictActive ? 'Pengaturan dikunci selama komitmen aktif' : 'Konfigurasi batasan akses aplikasi real-time',
                        style: TextStyle(color: muted, fontSize: 11, height: 1.35)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: sub, borderRadius: BorderRadius.circular(22)),
                      child: Row(children: [
                        const _Dot(color: _amber), const SizedBox(width: 6),
                        Text(strictActive ? 'Terkunci' : 'Aktif\nOtomatis',
                          style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w800, height: 1.2)),
                      ])),
                  ])),
                  const SizedBox(height: 14),
                  _surface(card, border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Nama jadwal', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.edit_note_rounded, color: _amber, size: 21),
                      const SizedBox(width: 7),
                      Expanded(child: TextField(
                        controller: _nameController, enabled: !strictActive,
                        style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Masukkan nama jadwal'),
                      )),
                      IconButton(onPressed: strictActive ? null : () => _nameController.clear(),
                        icon: Icon(Icons.cancel_outlined, color: muted, size: 19)),
                    ]),
                  ])),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: _sectionTitle('Hari aktif', 'Pilih siklus hari proteksi berulang', ink, muted)),
                    for (final action in [
                      ('Hari\nKerja', {1,2,3,4,5}),
                      ('Semua', {1,2,3,4,5,6,7}),
                      ('Akhir\nPekan', {6,7}),
                    ])
                      Padding(padding: const EdgeInsets.only(left: 5),
                        child: _quickChip(action.$1, _weekdays.length == action.$2.length && _weekdays.containsAll(action.$2),
                          card, border, ink, () => setState(() => _weekdays = Set<int>.of(action.$2)))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    for (var day = 1; day <= 7; day++)
                      Expanded(child: Padding(
                        padding: EdgeInsets.only(right: day == 7 ? 0 : 5),
                        child: _dayChip(day, dark, card, border, ink, muted, !strictActive),
                      )),
                  ]),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: Text('Jam pemblokiran', style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800))),
                    const Icon(Icons.timelapse_rounded, color: _amber, size: 15),
                    const SizedBox(width: 5),
                    Text(_duration(), style: const TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _timeCard('Mulai', _start, Icons.schedule_rounded, card, border, ink, muted, !strictActive, () => _pickTime(true))),
                    const SizedBox(width: 10),
                    Expanded(child: _timeCard('Selesai', _end, Icons.alarm_on_rounded, card, border, ink, muted, !strictActive, () => _pickTime(false))),
                  ]),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: Text('Aplikasi yang diblokir', style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _violet.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)),
                      child: Text('${_packages.length} dipilih', style: const TextStyle(color: _violet, fontSize: 10, fontWeight: FontWeight.w800))),
                    const Spacer(),
                    TextButton(onPressed: strictActive ? null : () => appsAsync.whenData((apps) {
                      setState(() {
                        final visible = apps.where((a) => _query.isEmpty ||
                          a.labelKey.contains(_query.toLowerCase()) ||
                          a.packageKey.contains(_query.toLowerCase()));
                        final allSelected = visible.isNotEmpty && visible.every((a) => _packages.contains(a.packageName));
                        if (allSelected) {
                          _packages.removeAll(visible.map((a) => a.packageName));
                        } else {
                          _packages.addAll(visible.map((a) => a.packageName));
                        }
                      });
                    }), child: const Text('Pilih Semua', style: TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 7),
                  _surface(card, border, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Row(children: [
                      Icon(Icons.search_rounded, color: muted, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(color: ink, fontSize: 13),
                        decoration: InputDecoration(hintText: 'Cari aplikasi atau paket...', hintStyle: TextStyle(color: muted), border: InputBorder.none, isDense: true),
                      )),
                      appsAsync.maybeWhen(data: (a) => Text('${a.length}\ntotal', textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700)), orElse: () => const SizedBox.shrink()),
                    ])),
                  const SizedBox(height: 8),
                  _surface(card, border, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: appsAsync.when(
                      loading: () => const Padding(padding: EdgeInsets.all(22), child: Center(child: CircularProgressIndicator())),
                      error: (_, __) => Text('Tidak dapat memuat aplikasi', style: TextStyle(color: muted)),
                      data: (apps) {
                        final visible = apps.where((a) => a.labelKey.contains(_query.toLowerCase()) || a.packageKey.contains(_query.toLowerCase())).toList()
                          ..sort((a,b) => a.labelKey.compareTo(b.labelKey));
                        if (visible.isEmpty) return Padding(padding: const EdgeInsets.all(18),
                          child: Text('Aplikasi tidak ditemukan', style: TextStyle(color: muted, fontSize: 12)));
                        return Column(children: [
                          for (var i = 0; i < visible.length; i++) ...[
                            _AppRow(app: visible[i], selected: _packages.contains(visible[i].packageName),
                              sub: sub, ink: ink, muted: muted,
                              onTap: strictActive ? null : () => setState(() {
                                final p = visible[i].packageName;
                                if (!_packages.add(p)) _packages.remove(p);
                              })),
                            if (i != visible.length - 1) Divider(height: 1, color: border),
                          ],
                        ]);
                      },
                    )),
                  if (isEditing) ...[
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: strictActive ? null : _delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Hapus jadwal'),
                      style: OutlinedButton.styleFrom(foregroundColor: _rose),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(color: bg, border: Border(top: BorderSide(color: border))),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink, side: BorderSide(color: border),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                  child: const Text('Batal'),
                )),
                const SizedBox(width: 9),
                Expanded(flex: 3, child: FilledButton.icon(
                  onPressed: strictActive ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _amber, foregroundColor: const Color(0xFF392000),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('Simpan & Aktifkan Jadwal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surface(Color color, Color border, {required Widget child, EdgeInsets padding = const EdgeInsets.all(15)}) =>
      Container(padding: padding, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(14), border: Border.all(color: border.withValues(alpha: .8))),
        child: child);

  Widget _sectionTitle(String title, String subtitle, Color ink, Color muted) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: muted, fontSize: 10)),
      ]);

  Widget _quickChip(String label, bool selected, Color card, Color border, Color ink, VoidCallback onTap) =>
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(color: selected ? _amber.withValues(alpha: .16) : card,
            borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? _amber : border)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            color: selected ? _amber : ink, fontSize: 9, fontWeight: FontWeight.w800, height: 1.1))));

  Widget _dayChip(int day, bool dark, Color card, Color border, Color ink, Color muted, bool enabled) {
    final selected = _weekdays.contains(day);
    return InkWell(
      onTap: !enabled ? null : () => setState(() {
        if (!_weekdays.add(day)) _weekdays.remove(day);
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(height: 49, decoration: BoxDecoration(
        color: selected ? _amber : card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? _amber : border),
        boxShadow: selected ? [BoxShadow(color: _amber.withValues(alpha: .18), blurRadius: 8, offset: const Offset(0,3))] : null),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(ScheduleFormat.weekdayLabels[day-1], style: TextStyle(
            color: selected ? const Color(0xFF542F00) : muted, fontSize: 11, fontWeight: FontWeight.w700)),
          if (selected) const Padding(padding: EdgeInsets.only(top: 3), child: _Dot(color: Color(0xFF542F00))),
        ]),
      ),
    );
  }

  Widget _timeCard(String label, int minutes, IconData icon, Color card, Color border,
      Color ink, Color muted, bool enabled, VoidCallback onTap) =>
      InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(13),
        child: Container(padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(13), border: Border.all(color: border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(label, style: TextStyle(color: muted, fontSize: 11))),
              Icon(icon, color: label == 'Mulai' ? _amber : _violet, size: 17)]),
            const SizedBox(height: 8),
            Text(ScheduleFormat.time(minutes), style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -.8)),
            Text(label == 'Mulai' ? 'Format 24 jam (WIB)' : 'Proteksi berakhir', style: TextStyle(color: muted, fontSize: 10)),
          ])));

}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.selected,
    required this.sub, required this.ink, required this.muted, required this.onTap});
  final InstalledApp app;
  final bool selected;
  final Color sub, ink, muted;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      onTap: onTap,
      leading: Container(width: 42, height: 42,
        decoration: BoxDecoration(color: sub, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.apps_rounded, color: _ScheduleEditorScreenState._amber, size: 21)),
      title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
      subtitle: Text(app.packageName, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: muted, fontSize: 9)),
      trailing: Container(width: 25, height: 25,
        decoration: BoxDecoration(color: selected ? _ScheduleEditorScreenState._amber : sub,
          borderRadius: BorderRadius.circular(8)),
        child: Icon(selected ? Icons.check_rounded : Icons.circle_outlined,
          color: selected ? const Color(0xFF392000) : muted, size: 17)),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 6, height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
