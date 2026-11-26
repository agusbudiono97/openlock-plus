import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/schedules/models/lock_schedule.dart';
import 'package:openlock/src/features/schedules/widgets/schedule_format.dart';

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  static const _amber = Color(0xFFF59E0B);
  static const _rose = Color(0xFFFB7185);
  static const _violet = Color(0xFF8B5CF6);
  static const _darkBg = Color(0xFF11101A);
  static const _darkCard = Color(0xFF1C1A27);
  static const _darkSub = Color(0xFF12111C);

  late DateTime _selectedDate;
  int _filterIndex = 0;
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool _isNight(LockSchedule s) => s.endMinutes < s.startMinutes;

  bool _matchesFilter(LockSchedule s) {
    switch (_filterIndex) {
      case 1:
        return s.weekdays.contains(1) &&
            s.weekdays.contains(2) &&
            s.weekdays.contains(3) &&
            s.weekdays.contains(4) &&
            s.weekdays.contains(5);
      case 2:
        return _isNight(s);
      default:
        return true;
    }
  }

  DateTime _dateAt(DateTime date, int minutes) => DateTime(
        date.year, date.month, date.day, minutes ~/ 60, minutes % 60,
      );

  bool _activeNow(LockSchedule s) {
    if (!s.enabled) return false;
    final minute = _now.hour * 60 + _now.minute;
    if (s.startMinutes == s.endMinutes) return s.weekdays.contains(_now.weekday);
    if (s.endMinutes > s.startMinutes) {
      return s.weekdays.contains(_now.weekday) &&
          minute >= s.startMinutes && minute < s.endMinutes;
    }
    final today = s.weekdays.contains(_now.weekday) && minute >= s.startMinutes;
    final yesterday = s.weekdays.contains(_now.subtract(const Duration(days: 1)).weekday) &&
        minute < s.endMinutes;
    return today || yesterday;
  }

  String _countdown(LockSchedule? s) {
    if (s == null) return '--:--:--';
    DateTime target;
    if (_activeNow(s)) {
      target = _dateAt(_now, s.endMinutes);
      if (s.endMinutes < s.startMinutes) {
        target = target.add(const Duration(days: 1));
      }
    } else {
      target = _dateAt(_now, s.startMinutes);
      if (!target.isAfter(_now)) target = target.add(const Duration(days: 1));
    }
    final seconds = target.difference(_now).inSeconds.clamp(0, 86399);
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  String _monthName(int month) => const [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ][month - 1];

  String _weekdayShort(int weekday) =>
      const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][weekday - 1];

  List<DateTime> _weekDates() {
    final monday = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  void _openEditor({String? id}) {
    final route = id == null
        ? AppRoutes.newSchedule
        : '${AppRoutes.editSchedule}/$id';
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? _darkBg : const Color(0xFFF7F9FC);
    final card = dark ? _darkCard : Colors.white;
    final sub = dark ? _darkSub : const Color(0xFFF3F6FA);
    final border = dark ? const Color(0xFF302D3B) : const Color(0xFFDCE4EF);
    final ink = dark ? const Color(0xFFF7F4FC) : const Color(0xFF111827);
    final muted = dark ? const Color(0xFFB5B0C2) : const Color(0xFF64748B);

    final configAsync = ref.watch(configControllerProvider);
    final config = configAsync.valueOrNull ?? LockConfig.empty;
    final schedules = config.schedules;
    final changesLocked = config.strictModeActiveAt(_now) ||
        config.dnsGuardActiveAt(_now);
    final daySchedules = schedules
        .where((s) => s.weekdays.contains(_selectedDate.weekday))
        .where(_matchesFilter)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final enabledSchedules = daySchedules.where((s) => s.enabled).toList();
    final next = enabledSchedules.isEmpty ? null : enabledSchedules.first;
    final nightSchedules = schedules.where(_isNight).toList();
    final packageCount = schedules
        .expand((s) => s.packages)
        .toSet()
        .length;
    final todaySchedules = schedules
        .where((s) => s.weekdays.contains(_now.weekday))
        .toList();
    final activeCount = schedules.where((s) => s.enabled).length;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _TopBar(
                      dark: dark,
                      card: card,
                      border: border,
                      ink: ink,
                      muted: muted,
                      onProfile: () => context.go(AppRoutes.settings),
                      onNotice: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Belum ada notifikasi baru.')),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text('Jadwal & Rutinitas',
                                    style: TextStyle(
                                      color: ink, fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.35,
                                    )),
                                const SizedBox(width: 5),
                                const _Dot(color: _amber),
                              ]),
                              const SizedBox(height: 3),
                              Text('MODE OTOMATIS SIAGA • AI SHIELD',
                                  style: TextStyle(
                                    color: dark ? const Color(0xFFFFC36B) : const Color(0xFFC65F1C),
                                    fontSize: 10, fontWeight: FontWeight.w800,
                                    letterSpacing: .35,
                                  )),
                            ],
                          ),
                        ),
                        _IconSurface(
                          card: card, border: border, muted: muted,
                          icon: Icons.calendar_month_rounded,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null && mounted) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _WeekStrip(
                      dark: dark, card: card, border: border, ink: ink,
                      muted: muted, selected: _selectedDate,
                      dates: _weekDates(),
                      schedules: schedules,
                      onSelect: (date) => setState(() => _selectedDate = date),
                      monthLabel: '${_monthName(_selectedDate.month)} ${_selectedDate.year}',
                      weekLabel: 'Pekan ${((_selectedDate.day - 1) ~/ 7) + 1} • ${schedules.length} Jadwal',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _FilterRow(
                      dark: dark, card: card, border: border, muted: muted,
                      selected: _filterIndex,
                      onSelect: (i) => setState(() => _filterIndex = i),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _NextScheduleCard(
                      dark: dark, card: card, sub: sub, border: border,
                      ink: ink, muted: muted, schedule: next,
                      countdown: _countdown(next),
                      active: next != null && _activeNow(next),
                      changesLocked: changesLocked,
                      onToggle: next == null || changesLocked
                          ? null
                          : (value) => ref.read(configControllerProvider.notifier)
                              .upsertSchedule(next.copyWith(enabled: value)),
                      onEdit: next == null || changesLocked
                          ? null : () => _openEditor(id: next.id),
                      onCreate: changesLocked ? null : () => _openEditor(),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _SummaryScheduleCard(
                      dark: dark, card: card, sub: sub, border: border,
                      ink: ink, muted: muted,
                      schedules: daySchedules,
                      changesLocked: changesLocked,
                      onOpen: (s) => _openEditor(id: s.id),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _NightScheduleCard(
                      dark: dark, card: card, border: border,
                      ink: ink, muted: muted,
                      schedules: nightSchedules,
                      changesLocked: changesLocked,
                      onManage: () => _openEditor(),
                      onOpen: (s) => _openEditor(id: s.id),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _AutomationSummaryCard(
                      dark: dark, card: card, sub: sub, border: border,
                      ink: ink, muted: muted,
                      total: schedules.length,
                      active: activeCount,
                      today: todaySchedules.length,
                      packages: packageCount,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 110),
                  sliver: SliverToBoxAdapter(
                    child: _AddScheduleButton(
                      onTap: changesLocked ? null : () => _openEditor(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.dark, required this.card, required this.border,
    required this.ink, required this.muted, required this.onProfile,
    required this.onNotice,
  });
  final bool dark;
  final Color card, border, ink, muted;
  final VoidCallback onProfile, onNotice;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF302638) : const Color(0xFFFFF4D9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .35)),
          ),
          child: const Icon(Icons.lock_rounded, color: Color(0xFFF59E0B), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('OpenLock', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
          Row(children: [
            const _Dot(color: Color(0xFFF59E0B)),
            const SizedBox(width: 5),
            Text('SHIELD ACTIVE', style: TextStyle(
              color: muted, fontSize: 9, fontWeight: FontWeight.w800,
              letterSpacing: .65,
            )),
          ]),
        ])),
        _IconSurface(card: card, border: border, muted: muted,
          icon: Icons.notifications_none_rounded, onTap: onNotice),
        const SizedBox(width: 10),
        Material(
          color: const Color(0xFFF59E0B),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onProfile,
            child: const SizedBox(width: 36, height: 36,
              child: Icon(Icons.person_outline_rounded, color: Color(0xFF3B2400), size: 20)),
          ),
        ),
      ]);
}

class _IconSurface extends StatelessWidget {
  const _IconSurface({required this.card, required this.border,
    required this.muted, required this.icon, required this.onTap});
  final Color card, border, muted;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: card,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: border),
            ),
            child: Icon(icon, color: muted, size: 19),
          ),
        ),
      );
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.dark, required this.card, required this.border,
    required this.ink, required this.muted, required this.selected,
    required this.dates, required this.schedules, required this.onSelect,
    required this.monthLabel, required this.weekLabel,
  });
  final bool dark;
  final Color card, border, ink, muted;
  final DateTime selected;
  final List<DateTime> dates;
  final List<LockSchedule> schedules;
  final ValueChanged<DateTime> onSelect;
  final String monthLabel, weekLabel;

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(monthLabel, style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(weekLabel, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (final date in dates)
            Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 5),
              child: _DayTile(
                dark: dark, card: card, border: border, ink: ink, muted: muted,
                date: date, selected: date.year == selected.year &&
                    date.month == selected.month && date.day == selected.day,
                count: schedules.where((s) => s.weekdays.contains(date.weekday)).length,
                onTap: () => onSelect(date),
              ),
            )),
        ]),
      ]);
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.dark, required this.card, required this.border,
    required this.ink, required this.muted, required this.date,
    required this.selected, required this.count, required this.onTap});
  final bool dark, selected;
  final Color card, border, ink, muted;
  final DateTime date;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFFF59E0B) : card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 67),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? const Color(0xFFFBBF24) : border),
              boxShadow: selected ? [BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: .22),
                blurRadius: 10, offset: const Offset(0, 3),
              )] : null,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day)
                Text('KINI', style: TextStyle(
                  color: selected ? const Color(0xFF78350F) : const Color(0xFFF59E0B),
                  fontSize: 8, fontWeight: FontWeight.w900,
                ))
              else
                const SizedBox(height: 10),
              Text(const ['Sen','Sel','Rab','Kam','Jum','Sab','Min'][date.weekday - 1],
                style: TextStyle(color: selected ? const Color(0xFF78350F) : muted,
                  fontSize: 10, fontWeight: FontWeight.w600)),
              Text('${date.day}', style: TextStyle(
                color: selected ? const Color(0xFF451A03) : ink,
                fontSize: 17, fontWeight: FontWeight.w800,
              )),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < count.clamp(0, 3); i++)
                  Container(
                    width: 4, height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF78350F) : const Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.dark, required this.card, required this.border,
    required this.muted, required this.selected, required this.onSelect});
  final bool dark;
  final Color card, border, muted;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    const labels = ['Semua Slot', 'Hari Kerja', 'Khusus Malam'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: selected == i ? const Color(0xFFF59E0B) : card,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: selected == i
                      ? const Color(0xFFF59E0B) : border),
                  ),
                  child: Text(labels[i], style: TextStyle(
                    color: selected == i ? const Color(0xFF3B2400) : muted,
                    fontSize: 11, fontWeight: selected == i ? FontWeight.w800 : FontWeight.w500,
                  )),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _NextScheduleCard extends StatelessWidget {
  const _NextScheduleCard({
    required this.dark, required this.card, required this.sub,
    required this.border, required this.ink, required this.muted,
    required this.schedule, required this.countdown, required this.active,
    required this.changesLocked, required this.onToggle, required this.onEdit,
    required this.onCreate,
  });
  final bool dark, active, changesLocked;
  final Color card, sub, border, ink, muted;
  final LockSchedule? schedule;
  final String countdown;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onEdit, onCreate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: dark ? .38 : .55), width: 1.2),
          boxShadow: [BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: dark ? .07 : .055),
            blurRadius: 18, offset: const Offset(0, 6),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: .15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                _Dot(color: Color(0xFFF59E0B)),
                SizedBox(width: 5),
                Text('SLOT BERIKUTNYA', style: TextStyle(
                  color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.w900,
                  letterSpacing: .3,
                )),
              ]),
            ),
            const Spacer(),
            if (schedule != null)
              Text('${ScheduleFormat.time(schedule!.startMinutes)} • ${ScheduleFormat.time(schedule!.endMinutes)} WIB',
                style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            if (schedule != null)
              Switch.adaptive(value: schedule!.enabled, onChanged: onToggle,
                activeColor: const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: 10),
          Text(schedule?.name ?? 'Belum ada rutinitas terjadwal',
            style: TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.35)),
          const SizedBox(height: 4),
          Text(schedule == null
              ? 'Buat slot pertama agar aplikasi pilihan terkunci otomatis sesuai waktumu.'
              : '${ScheduleFormat.weekdays(schedule!.weekdays)} • ${schedule!.packages.length} aplikasi dalam perlindungan',
            style: TextStyle(color: muted, fontSize: 11, height: 1.45)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: sub, borderRadius: BorderRadius.circular(13),
              border: Border.all(color: border)),
            child: Row(children: [
              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 22),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(countdown, style: TextStyle(
                  color: ink, fontSize: 19, fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
                Text(schedule == null ? 'Menunggu jadwal pertama' :
                  (active ? 'Menuju akhir sesi aktif' : 'Menuju waktu mulai'),
                  style: TextStyle(color: muted, fontSize: 10)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF29243A) : const Color(0xFFF4EFFF),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: .25)),
                ),
                child: const Text('AUTO GUARD', style: TextStyle(
                  color: Color(0xFF8B5CF6), fontSize: 9, fontWeight: FontWeight.w800,
                )),
              ),
            ]),
          ),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: Text('Aplikasi terjadwal (${schedule?.packages.length ?? 0})',
              style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700))),
            Text(changesLocked ? 'Pengaturan terkunci' : 'Aturan otomatis',
              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          if (schedule == null || schedule!.packages.isEmpty)
            Text('Belum ada aplikasi yang dipilih pada slot ini.',
              style: TextStyle(color: muted, fontSize: 10))
          else
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final pkg in schedule!.packages.take(5))
                Container(
                  width: 35, height: 35,
                  decoration: BoxDecoration(color: sub, borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: border)),
                  child: const Icon(Icons.apps_rounded, color: Color(0xFFF59E0B), size: 18),
                ),
              if (schedule!.packages.length > 5)
                Container(
                  width: 35, height: 35,
                  decoration: BoxDecoration(color: sub, borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: border)),
                  child: Center(child: Text('+ ${schedule!.packages.length - 5}',
                    style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w700))),
                ),
            ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _ActionButton(
              label: schedule == null ? 'Buat Jadwal' : 'Ubah Jadwal',
              icon: Icons.tune_rounded, primary: true, onTap: schedule == null ? onCreate : onEdit,
            )),
            const SizedBox(width: 9),
            Expanded(child: _ActionButton(
              label: 'Kelola Slot', icon: Icons.calendar_month_rounded,
              primary: false, onTap: onCreate,
            )),
          ]),
        ]),
      );
}

class _SummaryScheduleCard extends StatelessWidget {
  const _SummaryScheduleCard({required this.dark, required this.card,
    required this.sub, required this.border, required this.ink,
    required this.muted, required this.schedules, required this.changesLocked,
    required this.onOpen});
  final bool dark;
  final Color card, sub, border, ink, muted;
  final List<LockSchedule> schedules;
  final bool changesLocked;
  final ValueChanged<LockSchedule> onOpen;
  @override
  Widget build(BuildContext context) {
    final first = schedules.isEmpty ? null : schedules.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 31, height: 31,
            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: .12),
              shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(first?.name ?? 'Rutinitas hari ini',
              style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w800)),
            Text(first == null ? 'Tidak ada slot pada hari yang dipilih' :
              '${ScheduleFormat.time(first.startMinutes)}–${ScheduleFormat.time(first.endMinutes)} WIB • ${ScheduleFormat.weekdays(first.weekdays)}',
              style: TextStyle(color: muted, fontSize: 10)),
          ])),
          if (first != null)
            Text('${schedules.length} Slot', style: TextStyle(
              color: muted, fontSize: 9, fontWeight: FontWeight.w700)),
        ]),
        if (first != null) ...[
          const SizedBox(height: 13),
          Material(
            color: sub, borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: changesLocked ? null : () => onOpen(first),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${first.packages.length} aplikasi dalam slot',
                      style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700)),
                    Text(first.enabled ? 'Otomatis aktif sesuai hari dan jam' : 'Slot sedang nonaktif',
                      style: TextStyle(color: muted, fontSize: 10)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: muted, size: 19),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _NightScheduleCard extends StatelessWidget {
  const _NightScheduleCard({required this.dark, required this.card,
    required this.border, required this.ink, required this.muted,
    required this.schedules, required this.changesLocked,
    required this.onManage, required this.onOpen});
  final bool dark;
  final Color card, border, ink, muted;
  final List<LockSchedule> schedules;
  final bool changesLocked;
  final VoidCallback onManage;
  final ValueChanged<LockSchedule> onOpen;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: dark ? .28 : .22))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: .16),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.nightlight_round, color: Color(0xFF8B5CF6), size: 19)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rutinitas Malam', style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w800)),
              Text(schedules.isEmpty ? 'Belum ada jadwal lintas tengah malam' :
                '${schedules.length} jadwal malam tersimpan',
                style: TextStyle(color: muted, fontSize: 10)),
            ])),
            if (schedules.isNotEmpty)
              const Icon(Icons.lock_outline_rounded, color: Color(0xFFF59E0B), size: 19),
          ]),
          const SizedBox(height: 10),
          Text(schedules.isEmpty
            ? 'Buat rutinitas malam untuk mengatur pemblokiran aplikasi pada jam istirahat.'
            : schedules.map((s) => '${s.name} • ${ScheduleFormat.time(s.startMinutes)}–${ScheduleFormat.time(s.endMinutes)}').join('\n'),
            style: TextStyle(color: muted, fontSize: 10, height: 1.5)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.apps_rounded, color: Color(0xFF8B5CF6), size: 14),
            const SizedBox(width: 5),
            Text('${schedules.fold<int>(0, (n, s) => n + s.packages.length)} aplikasi terjadwal',
              style: TextStyle(color: muted, fontSize: 10)),
            const Spacer(),
            TextButton(
              onPressed: changesLocked ? null : onManage,
              child: const Text('Kelola Jadwal Malam',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
          if (schedules.isNotEmpty) ...[
            const Divider(height: 8),
            for (final s in schedules.take(2))
              ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                title: Text(s.name, style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700)),
                subtitle: Text(ScheduleFormat.summary(s), style: TextStyle(color: muted, fontSize: 10)),
                trailing: Icon(Icons.chevron_right_rounded, color: muted),
                onTap: changesLocked ? null : () => onOpen(s),
              ),
          ],
        ]),
      );
}

class _AutomationSummaryCard extends StatelessWidget {
  const _AutomationSummaryCard({required this.dark, required this.card,
    required this.sub, required this.border, required this.ink,
    required this.muted, required this.total, required this.active,
    required this.today, required this.packages});
  final bool dark;
  final Color card, sub, border, ink, muted;
  final int total, active, today, packages;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.sensors_rounded, color: Color(0xFFF59E0B), size: 17),
            const SizedBox(width: 7),
            Expanded(child: Text('Ringkasan Otomatisasi',
              style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800))),
            Text('DATA JADWAL', style: TextStyle(color: muted, fontSize: 9, letterSpacing: .4)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _MetricTile(icon: Icons.calendar_month_rounded,
              label: 'Jadwal Aktif', value: '$active', tint: const Color(0xFFF59E0B),
              card: sub, border: border, ink: ink, muted: muted)),
            const SizedBox(width: 9),
            Expanded(child: _MetricTile(icon: Icons.apps_rounded,
              label: 'Aplikasi', value: '$packages', tint: const Color(0xFF8B5CF6),
              card: sub, border: border, ink: ink, muted: muted)),
          ]),
          const SizedBox(height: 8),
          Text('$total jadwal tersimpan • $today berlaku pada hari ini',
            style: TextStyle(color: muted, fontSize: 10)),
        ]),
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.icon, required this.label,
    required this.value, required this.tint, required this.card,
    required this.border, required this.ink, required this.muted});
  final IconData icon;
  final String label, value;
  final Color tint, card, border, ink, muted;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(13),
          border: Border.all(color: border)),
        child: Row(children: [
          Icon(icon, color: tint, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: muted, fontSize: 9)),
            Text(value, style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
          ])),
        ]),
      );
}

class _AddScheduleButton extends StatelessWidget {
  const _AddScheduleButton({required this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFFB7185)],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: .25),
            blurRadius: 16, offset: const Offset(0, 5),
          )],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onTap, borderRadius: BorderRadius.circular(15),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3B2400), size: 20),
              SizedBox(width: 8),
              Text('Tambah Slot Rutinitas Baru', style: TextStyle(
                color: Color(0xFF3B2400), fontSize: 13, fontWeight: FontWeight.w800,
              )),
            ]),
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon,
    required this.primary, required this.onTap});
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: primary ? const Color(0xFFF59E0B) : const Color(0xFF242130),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 15, color: primary ? const Color(0xFF3B2400) : Colors.white),
              const SizedBox(width: 5),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: primary ? const Color(0xFF3B2400) : Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w800))),
            ]),
          ),
        ),
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
