import 'package:core_lock/core_lock.dart' show RecoveryKeyView;
import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/core/store_build.dart';
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
            const ScreenHeader(eyebrow: 'OpenLock', title: 'Pengaturan'),
            if (strictActive)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_clock_rounded),
                  title: const Text('Mode Ketat sedang aktif'),
                  subtitle: const Text('Pengaturan perlindungan dikunci sampai waktu komitmen berakhir.'),
                ),
              ),
            RowGroup(
              children: [
                AppearanceSetting(controller: ref.watch(appearanceProvider)),
              ],
            ),
            const SectionLead('Perlindungan'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Izin dan status',
                  subtitle: 'Akses penggunaan, tampil di atas aplikasi, layanan pemantau',
                  onTap: () => context.push(AppRoutes.permissions),
                ),
                SettingsTile(
                  icon: Icons.timer_outlined,
                  title: 'Perilaku kunci ulang',
                  subtitle: _relockLabel(config.relock),
                  onTap: () => context.push(AppRoutes.relock),
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
                      : 'Replace locked apps\' notifications with a count',
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
                          onPressed: () => ref
                              .read(permissionsControllerProvider.notifier)
                              .requestNotificationAccess(),
                          child: const Text('Izinkan'),
                        ),
                  onTap: notificationAccess
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
                  onTap: () => context.push(AppRoutes.changePin),
                ),
                SettingsTile(
                  icon: Icons.key_outlined,
                  title: 'Kunci pemulihan',
                  subtitle: 'Atur ulang PIN jika kamu lupa',
                  onTap: _recoveryKey,
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
                        ? 'PIN required on OpenLock\'s App info and uninstall '
                            'aplikasi'
                        : 'Enable in Accessibility to guard OpenLock\'s App '
                            'dan uninstall OpenLock',
                    showChevron: false,
                    trailing: screenGuardAccess
                        ? null
                        : TextButton(
                            onPressed: () => ref
                                .read(permissionsControllerProvider.notifier)
                                .requestScreenGuardAccess(),
                            child: const Text('Aktifkan'),
                          ),
                    onTap: screenGuardAccess
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
                  subtitle: 'Fake "app stopped" dialog',
                  value: config.fakeCoverEnabled,
                  onChanged: controller.setFakeCover,
                ),
                SettingsTile(
                  icon: Icons.backup_outlined,
                  title: 'Cadangkan dan pulihkan',
                  onTap: () => context.push(AppRoutes.backup),
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
