import 'package:core_lock/core_lock.dart' show RecoveryKeyView;
import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/core/store_build.dart';
import 'package:openlock/src/core/theme/theme_palette.dart';
import 'package:openlock/src/core/widgets/screen_header.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/models/relock_policy.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/onboarding/providers/permissions_providers.dart';
import 'package:openlock/src/features/settings/providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-read live state after returning from a system screen: device-admin
    // activation, and notification-access / accessibility grants.
    if (state == AppLifecycleState.resumed) {
      ref.read(preventUninstallControllerProvider.notifier).refresh();
      ref.read(permissionsControllerProvider.notifier).refresh();
    }
  }

  String _relockLabel(RelockPolicy policy) {
    switch (policy.mode) {
      case RelockMode.immediately:
        return 'Saat keluar dari aplikasi';
      case RelockMode.onScreenOff:
        return 'Saat layar mati';
      case RelockMode.afterTimeout:
        return 'Setelah ${policy.timeout.inMinutes} menit';
    }
  }

  /// In-app re-auth required before device admin can be deactivated. Tries
  /// biometrics first (if enabled), then falls back to a PIN prompt. Returns
  /// true only on a successful check.
  Future<bool> _authenticateForDisable() =>
      _reauthenticate('Masukkan PIN untuk menonaktifkan perlindungan uninstall.');


  Future<void> _editAppTheme() async {
    const presets = <(String, Color)>[
      ('Ocean', Color(0xFF007E9C)), ('Mint', Color(0xFF159B79)),
      ('Violet', Color(0xFF805AD5)), ('Blue', Color(0xFF3478D4)),
      ('Rose', Color(0xFFC04475)), ('Amber', Color(0xFFB7791F)),
      ('Forest', Color(0xFF477A45)), ('Monochrome', Color(0xFF596273)),
    ];
    final palette = ThemePaletteScope.of(context);
    final hex = TextEditingController(
      text: palette.seed.toARGB32().toRadixString(16).substring(2).toUpperCase(),
    );
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Warna tema aplikasi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih warna aksen'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: [
                      for (final preset in presets)
                        InkWell(
                          onTap: () async {
                            await palette.setSeed(preset.$2);
                            if (!dialogContext.mounted) return;
                            hex.text = preset.$2.toARGB32().toRadixString(16)
                                .substring(2).toUpperCase();
                            setDialogState(() {});
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 76,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: palette.seed.toARGB32() == preset.$2.toARGB32()
                                    ? Theme.of(dialogContext).colorScheme.primary
                                    : Theme.of(dialogContext).colorScheme.outlineVariant,
                                width: palette.seed.toARGB32() == preset.$2.toARGB32() ? 2 : 1,
                              ),
                            ),
                            child: Column(children: [
                              CircleAvatar(radius: 13, backgroundColor: preset.$2),
                              const SizedBox(height: 5),
                              Text(preset.$1,
                                  style: Theme.of(dialogContext).textTheme.labelSmall),
                            ]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Warna custom (HEX)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hex, maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      prefixText: '#', hintText: '20C9A5', counterText: '',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex.text)
                          ? Color(0xFF000000 | int.parse(hex.text, radix: 16))
                          : Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(width: 8),
                    Text('Pratinjau warna',
                        style: Theme.of(dialogContext).textTheme.bodySmall),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex.text)) return;
                        await palette.setSeed(
                            Color(0xFF000000 | int.parse(hex.text, radix: 16)));
                        if (!dialogContext.mounted) return;
                        setDialogState(() {});
                      },
                      child: const Text('Terapkan'),
                    ),
                  ]),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await palette.reset();
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                },
                child: const Text('Reset default'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Selesai'),
              ),
            ],
          ),
        ),
      );
    } finally {
      hex.dispose();
    }
  }

  Future<void> _editStrictScreenText(LockConfig config) async {
    final title = TextEditingController(text: config.strictScreenTitle);
    final message = TextEditingController(text: config.strictScreenMessage);
    final footer = TextEditingController(text: config.strictScreenFooter);
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Personalisasi layar blokir'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 48,
                  decoration: const InputDecoration(
                    labelText: 'Judul utama',
                    hintText: 'WAKTUNYA BERHENTI',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: message,
                  maxLength: 140,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Pesan utama',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: footer,
                  maxLength: 100,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Pesan penutup',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
      if (save == true && mounted) {
        await ref.read(configControllerProvider.notifier).setStrictScreenText(
              title: title.text,
              message: message.text,
              footer: footer.text,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teks layar blokir berhasil disimpan.')),
          );
        }
      }
    } finally {
      title.dispose();
      message.dispose();
      footer.dispose();
    }
  }

  Future<void> _editStrictScreenPalette(LockConfig config) async {
    const labels = ['Malam mint', 'Senja amber', 'Hutan tenang'];
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Warna layar blokir'),
        children: [
          for (var index = 0; index < labels.length; index++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, index),
              child: Row(
                children: [
                  Icon(
                    config.strictScreenPalette == index
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: config.strictScreenPalette == index
                        ? const Color(0xFF007E9C)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(labels[index]),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null && mounted) {
      await ref
          .read(configControllerProvider.notifier)
          .setStrictScreenPalette(selected);
    }
  }

  /// Re-auth, confirm replacing any existing key, then show a new recovery
  /// key until the user confirms saving it.
  Future<void> _recoveryKey() async {
    if (!await _reauthenticate('Masukkan PIN untuk membuat kunci pemulihan.')) {
      return;
    }
    final auth = ref.read(pinAuthServiceProvider);
    if (await auth.hasRecoveryKey() && mounted) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ganti kunci pemulihan?'),
          content: const Text(
            'Kunci pemulihan lama tidak akan berlaku. Kunci pemulihan '
            'tidak pernah disimpan, jadi kunci lama tidak dapat ditampilkan lagi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Buat kunci baru'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }
    final key = await auth.createRecoveryKey();
    await auth.markRecoveryOffered();
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (routeContext) => PopScope(
          canPop: false,
          child: RecoveryKeyView(
            recoveryKey: key,
            appName: 'OpenLock',
            onDone: () => Navigator.pop(routeContext),
          ),
        ),
      ),
    );
  }

  Future<bool> _reauthenticate(String pinPrompt) async {
    final biometric = ref.read(biometricServiceProvider);
    if (await biometric.isEnabled() && await biometric.authenticate()) {
      return true;
    }
    if (!mounted) return false;
    return _promptPin(pinPrompt);
  }

  Future<bool> _promptPin(String prompt) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var error = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Konfirmasi PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(prompt),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: controller,
                  label: 'PIN',
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  errorText: error ? 'PIN salah' : null,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final ok = await ref
                      .read(pinAuthServiceProvider)
                      .verifyPin(controller.text);
                  if (ok) {
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } else {
                    setDialogState(() => error = true);
                  }
                },
                child: const Text('Konfirmasi'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final config =
        ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final controller = ref.read(configControllerProvider.notifier);
    final biometricSupported =
        ref.watch(biometricSupportedProvider).valueOrNull ?? false;
    final biometricEnabled =
        ref.watch(biometricEnabledProvider).valueOrNull ?? false;
    final preventUninstall =
        ref.watch(preventUninstallControllerProvider).valueOrNull ?? false;
    final permissions = ref.watch(permissionsControllerProvider).valueOrNull;
    final notificationAccess = permissions?.notificationAccess ?? false;
    final screenGuardAccess = permissions?.screenGuardAccess ?? false;
    final strictActive = config.strictModeActiveAt(DateTime.now());

    Widget toggle({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool>? onChanged,
    }) =>
        SettingsTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          showChevron: false,
          trailing: Switch(value: value, onChanged: strictActive ? null : onChanged),
          onTap: strictActive || onChanged == null ? null : () => onChanged(!value),
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageList(
          children: [
            const ScreenHeader(eyebrow: 'PREFERENSI & KEAMANAN', title: 'Profil'),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.secondary.withValues(alpha: .16),
                    Theme.of(context).colorScheme.primary.withValues(alpha: .07),
                    Theme.of(context).colorScheme.surfaceContainerLow,
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.shield_moon_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perlindungan perangkat',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Atur keamanan dan pengalaman OpenLock.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (strictActive)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.lock_clock_rounded),
                  title: Text('Mode Ketat sedang aktif'),
                  subtitle: Text('Pengaturan perlindungan dikunci sampai waktu komitmen berakhir.'),
                ),
              ),
            RowGroup(
              children: [
                AppearanceSetting(controller: ref.watch(appearanceProvider)),
              ],
            ),
            const SectionLead('Tema aplikasi'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: Icons.color_lens_outlined,
                  title: 'Warna dan aksen',
                  subtitle: 'Pilih tema siap pakai atau gunakan warna HEX sendiri',
                  onTap: _editAppTheme,
                ),
              ],
            ),
            const SectionLead('Personalisasi'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: Icons.text_fields_rounded,
                  title: 'Teks layar blokir',
                  subtitle: 'Atur judul, pesan utama, dan pesan penutup',
                  onTap: strictActive ? null : () => _editStrictScreenText(config),
                ),
                SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Warna layar blokir',
                  subtitle: const ['Malam mint', 'Senja amber', 'Hutan tenang']
                      [config.strictScreenPalette.clamp(0, 2).toInt()],
                  onTap: strictActive
                      ? null
                      : () => _editStrictScreenPalette(config),
                ),
              ],
            ),
            const SectionLead('Perlindungan'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: config.dnsGuardActiveAt(DateTime.now())
                      ? Icons.shield_rounded
                      : Icons.dns_outlined,
                  title: 'DNS Guard',
                  subtitle: config.dnsGuardActiveAt(DateTime.now())
                      ? 'Aktif — akses DNS Pribadi diblokir'
                      : 'Lindungi pengaturan DNS dengan durasi mandiri',
                  onTap: () => context.push(AppRoutes.dnsGuard),
                ),
                SettingsTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Izin dan status',
                  subtitle: 'Akses penggunaan, tampil di atas aplikasi, layanan pemantau',
                  onTap: strictActive ? null : () => context.push(AppRoutes.permissions),
                ),
                SettingsTile(
                  icon: Icons.timer_outlined,
                  title: 'Perilaku kunci ulang',
                  subtitle: _relockLabel(config.relock),
                  onTap: strictActive ? null : () => context.push(AppRoutes.relock),
                ),
              ],
            ),
            const SectionLead('Notifikasi'),
            RowGroup(
              children: [
                toggle(
                  icon: Icons.notifications_off_outlined,
                  title: 'Sembunyikan isi notifikasi',
                  subtitle: config.hideNotifications
                      ? 'Notifikasi aplikasi terkunci akan disamarkan'
                      : 'Notifikasi aplikasi terkunci diganti dengan jumlah notifikasi',
                  value: config.hideNotifications,
                  onChanged: (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    await controller.setHideNotifications(value);
                    if (value && !notificationAccess) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Berikan akses notifikasi agar OpenLock dapat menyembunyikan '
                            'isi notifikasi.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                SettingsTile(
                  icon: notificationAccess
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  title: 'Akses notifikasi',
                  subtitle: notificationAccess
                      ? 'Diizinkan'
                      : 'Diperlukan untuk menyembunyikan isi notifikasi',
                  showChevron: false,
                  trailing: notificationAccess
                      ? null
                      : TextButton(
                          onPressed: strictActive ? null : () => ref
                              .read(permissionsControllerProvider.notifier)
                              .requestNotificationAccess(),
                          child: const Text('Izinkan'),
                        ),
                  onTap: strictActive || notificationAccess
                      ? null
                      : () => ref
                          .read(permissionsControllerProvider.notifier)
                          .requestNotificationAccess(),
                ),
              ],
            ),
            const SectionLead('Keamanan'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: Icons.pin_outlined,
                  title: 'Ubah PIN',
                  onTap: strictActive ? null : () => context.push(AppRoutes.changePin),
                ),
                SettingsTile(
                  icon: Icons.key_outlined,
                  title: 'Kunci pemulihan',
                  subtitle: 'Atur ulang PIN jika kamu lupa',
                  onTap: strictActive ? null : _recoveryKey,
                ),
                toggle(
                  icon: Icons.fingerprint,
                  title: 'Buka dengan sidik jari',
                  subtitle: biometricSupported
                      ? 'Gunakan sidik jari untuk membuka'
                      : 'Tidak tersedia di perangkat ini',
                  value: biometricEnabled,
                  onChanged: biometricSupported
                      ? (value) async {
                          final service = ref.read(biometricServiceProvider);
                          if (value) {
                            await service.enable();
                          } else {
                            await service.disable();
                          }
                          ref.invalidate(biometricEnabledProvider);
                          // Keep the native lock screen in sync with the choice.
                          await controller.pushToNative();
                        }
                      : null,
                ),
                toggle(
                  icon: Icons.app_blocking_outlined,
                  title: 'Cegah uninstall',
                  subtitle: preventUninstall
                      ? 'Uninstall memerlukan PIN'
                      : 'Wajibkan PIN untuk uninstall',
                  value: preventUninstall,
                  onChanged: (value) async {
                    final security =
                        ref.read(preventUninstallControllerProvider.notifier);
                    if (value) {
                      await security.requestEnable();
                    } else {
                      final messenger = ScaffoldMessenger.of(context);
                      final lifted = await security
                          .disableWithAuth(_authenticateForDisable);
                      if (!lifted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'PIN atau sidik jari diperlukan untuk mematikan '
                              'perlindungan uninstall.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                if (preventUninstall)
                  SettingsTile(
                    icon: screenGuardAccess
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    title: 'Lindungi layar uninstall',
                    subtitle: screenGuardAccess
                        ? 'PIN diperlukan pada halaman Info aplikasi dan proses uninstall OpenLock.'
                        : 'Aktifkan Aksesibilitas agar OpenLock dapat mengawal halaman Info aplikasi dan proses uninstall.',
                    showChevron: false,
                    trailing: screenGuardAccess
                        ? null
                        : TextButton(
                            onPressed: strictActive ? null : () => ref
                                .read(permissionsControllerProvider.notifier)
                                .requestScreenGuardAccess(),
                            child: const Text('Aktifkan'),
                          ),
                    onTap: strictActive || screenGuardAccess
                        ? null
                        : () => ref
                            .read(permissionsControllerProvider.notifier)
                            .requestScreenGuardAccess(),
                  ),
                toggle(
                  icon: Icons.shuffle,
                  title: 'Acak susunan tombol PIN',
                  subtitle: 'Acak posisi angka pada papan PIN',
                  value: config.randomizeKeypad,
                  onChanged: controller.setRandomizeKeypad,
                ),
              ],
            ),
            const SectionLead('Deteksi penyusup'),
            RowGroup(
              children: [
                toggle(
                  icon: Icons.photo_camera_outlined,
                  title: 'Ambil foto penyusup',
                  subtitle:
                      'Ambil foto setelah ${config.intruderThreshold} percobaan gagal',
                  value: config.intruderCaptureEnabled,
                  onChanged: (value) =>
                      controller.setIntruderCapture(enabled: value),
                ),
                SettingsTile(
                  icon: Icons.list_alt_outlined,
                  title: 'Lihat riwayat penyusup',
                  onTap: () => context.go(AppRoutes.intruder),
                ),
              ],
            ),
            const SectionLead('Lanjutan'),
            RowGroup(
              children: [
                toggle(
                  icon: Icons.warning_amber_outlined,
                  title: 'Tampilan pengalih',
                  subtitle: 'Dialog tiruan aplikasi berhenti',
                  value: config.fakeCoverEnabled,
                  onChanged: controller.setFakeCover,
                ),
                SettingsTile(
                  icon: Icons.backup_outlined,
                  title: 'Cadangkan dan pulihkan',
                  onTap: strictActive ? null : () => context.push(AppRoutes.backup),
                ),
              ],
            ),
            const SectionLead('Pembaruan'),
            RowGroup(
              children: [
                if (!kStoreBuild) const _UpdateTiles(),
                SettingsTile(
                  icon: Icons.info_outline,
                  title: 'Tentang aplikasi',
                  onTap: () => context.push(AppRoutes.about),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Check for updates on open" toggle + a manual "Check now", backed by
/// core_update. On by default; the only network call the app makes.
class _UpdateTiles extends ConsumerStatefulWidget {
  const _UpdateTiles();

  @override
  ConsumerState<_UpdateTiles> createState() => _UpdateTilesState();
}

class _UpdateTilesState extends ConsumerState<_UpdateTiles> {
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final info = await ref.read(updateServiceProvider).check();
    if (!mounted) return;
    setState(() => _checking = false);
    final messenger = ScaffoldMessenger.of(context);
    if (info == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kamu sudah menggunakan versi terbaru.')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Pembaruan tersedia · v${info.version}'),
          action: SnackBarAction(
            label: 'Perbarui',
            onPressed: () => ref.read(updateServiceProvider).openDownload(info),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoCheck = ref.watch(updateAutoCheckProvider).valueOrNull ?? true;
    Future<void> setAuto(bool v) async {
      await ref.read(secureStorageProvider).write(
            key: updateAutoCheckKey,
            value: v ? 'true' : 'false',
          );
      ref.invalidate(updateAutoCheckProvider);
      ref.invalidate(updateCheckProvider);
    }

    return Column(
      children: [
        SettingsTile(
          icon: Icons.system_update_alt,
          title: 'Periksa pembaruan otomatis',
          subtitle: 'Memeriksa pembaruan dari GitHub',
          showChevron: false,
          trailing: Switch(value: autoCheck, onChanged: setAuto),
          onTap: () => setAuto(!autoCheck),
        ),
        const Divider(height: 1, indent: 68),
        SettingsTile(
          icon: Icons.refresh,
          title: 'Periksa sekarang',
          showChevron: false,
          trailing: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _checking ? null : _checkNow,
        ),
      ],
    );
  }
}
