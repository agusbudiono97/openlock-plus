import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/models/relock_policy.dart';
import 'package:openlock/src/features/schedules/models/lock_schedule.dart';

/// Owns the [LockConfig] source of truth. Every mutation persists the config
/// (encrypted) and re-pushes the enforcement subset to the native monitor.
final class ConfigController extends AsyncNotifier<LockConfig> {
  @override
  Future<LockConfig> build() => ref.watch(configRepositoryProvider).load();

  Future<void> _apply(LockConfig requested) async {
    // Never fall back to an empty config while the async repository load is
    // still in flight: doing so could overwrite an active commitment saved
    // before this screen finished loading.
    final current = state.valueOrNull ?? await future;
    final strictActive = current.strictModeActiveAt(DateTime.now());

    // Strict Mode is a full settings freeze, not merely a protected timer.
    // Keep the complete snapshot unchanged until the native/Dart deadline
    // expires. This covers app lists, schedules, uninstall settings, and
    // backup restores regardless of which screen initiated the mutation.
    final next = strictActive ? current : requested;

    state = AsyncData(next);
    await ref.read(configRepositoryProvider).save(next);
    await pushToNative();
  }

  /// Rebuilds the native enforcement map from the current config plus the
  /// stored PIN verifier and hands it to the native layer.
  Future<void> pushToNative() async {
    final config = state.valueOrNull;
    if (config == null) return;
    final verifier = await ref.read(pinAuthServiceProvider).verifier();
    // Strict Mode is an independent hard block and must work even before an
    // app-lock PIN has been configured. Empty verifier values disable only
    // the ordinary PIN lock; the native monitor still receives Strict Mode.
    final biometricEnabled =
        await ref.read(biometricServiceProvider).isEnabled();
    await ref.read(enforcementBridgeProvider).pushConfig(
          config.toNativeMap(
            pinHash: verifier?.hash ?? '',
            pinSalt: verifier?.salt ?? '',
            biometricEnabled: biometricEnabled,
          ),
        );
  }

  Future<void> toggleApp(String packageName) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    final locked = Set<String>.of(config.lockedPackages);
    if (!locked.add(packageName)) locked.remove(packageName);
    await _apply(config.copyWith(lockedPackages: locked));
  }

  Future<void> setLockNewApps(bool value) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    await _apply(config.copyWith(lockNewApps: value));
  }

  Future<void> setRelock(RelockPolicy policy) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    await _apply(config.copyWith(relock: policy));
  }

  Future<void> setRandomizeKeypad(bool value) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    await _apply(config.copyWith(randomizeKeypad: value));
  }

  Future<void> setIntruderCapture({bool? enabled, int? threshold}) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    await _apply(config.copyWith(
      intruderCaptureEnabled: enabled,
      intruderThreshold: threshold,
    ));
  }

  Future<void> setFakeCover(bool value) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    await _apply(config.copyWith(fakeCoverEnabled: value));
  }

  /// Sets the global "hide notification content" default for locked apps.
  Future<void> setHideNotifications(bool value) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    await _apply(config.copyWith(hideNotifications: value));
  }

  /// Sets or clears a per-app notification-hiding override. Passing null
  /// removes the override so the app follows the global flag again.
  Future<void> setNotificationOverride(String packageName, bool? value) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    final overrides = Map<String, bool>.of(config.notificationOverrides);
    if (value == null) {
      overrides.remove(packageName);
    } else {
      overrides[packageName] = value;
    }
    await _apply(config.copyWith(notificationOverrides: overrides));
  }

  /// Persists the "prevent uninstall" intent and re-pushes it to the native
  /// monitor so it knows whether to guard the OS deactivate-admin / app-info /
  /// uninstall screens. Does NOT itself activate or deactivate device admin —
  /// that is driven by [PreventUninstallController].
  /// Starts or stops Strict Mode. A null deadline means indefinite.
  Future<void> setStrictMode({
    required bool enabled,
    required Set<String> packages,
    int? endsAtMillis,
  }) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    await _apply(config.copyWith(
      strictModeEnabled: enabled,
      strictModePackages: packages,
      strictModeEndsAtMillis: endsAtMillis,
      clearStrictModeEndsAtMillis: enabled && endsAtMillis == null,
    ));
  }

  Future<void> setPreventUninstall(bool value) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    if (config.preventUninstall == value) return;
    await _apply(config.copyWith(preventUninstall: value));
  }

  Future<void> upsertSchedule(LockSchedule schedule) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    final schedules = List<LockSchedule>.of(config.schedules);
    final index = schedules.indexWhere((s) => s.id == schedule.id);
    if (index >= 0) {
      schedules[index] = schedule;
    } else {
      schedules.add(schedule);
    }
    await _apply(config.copyWith(schedules: schedules));
  }

  Future<void> deleteSchedule(String id) async {
    final config = state.valueOrNull ?? LockConfig.empty;
    final schedules = config.schedules.where((s) => s.id != id).toList();
    await _apply(config.copyWith(schedules: schedules));
  }

  /// Replaces the whole config (used by backup restore).
  Future<void> replace(LockConfig config) => _apply(config);
}

final configControllerProvider =
    AsyncNotifierProvider<ConfigController, LockConfig>(ConfigController.new);
