import 'package:openlock/src/features/enforcement/models/relock_policy.dart';
import 'package:openlock/src/features/schedules/models/lock_schedule.dart';

/// The Flutter-side source of truth for everything the lock behaves by. Stored
/// encrypted at rest (AES-256-GCM, key in secure storage). The *subset* the
/// native monitor needs is projected via [toNativeMap] and pushed into the
/// native EncryptedSharedPreferences.
final class LockConfig {
  const LockConfig({
    this.lockedPackages = const {},
    this.lockNewApps = false,
    this.relock = const RelockPolicy(),
    this.randomizeKeypad = false,
    this.intruderCaptureEnabled = false,
    this.intruderThreshold = 3,
    this.fakeCoverEnabled = false,
    this.preventUninstall = false,
    this.hideNotifications = false,
    this.notificationOverrides = const {},
    this.schedules = const [],
    this.strictModeEnabled = false,
    this.strictModePackages = const {},
    this.strictModeEndsAtMillis,
    this.dnsGuardEnabled = false,
    this.dnsGuardEndsAtMillis,
    this.strictScreenTitle = 'WAKTUNYA BERHENTI',
    this.strictScreenMessage =
        'Kamu sedang menjaga komitmenmu. Aplikasi ini belum bisa digunakan.',
    this.strictScreenFooter =
        'Tetap kuat. Waktu perlindungan akan berakhir sesuai jadwal.',
    this.strictScreenPalette = 0,
  });

  /// Apps locked at all times (user toggles in the app picker).
  final Set<String> lockedPackages;

  /// Automatically lock apps installed after this was turned on.
  final bool lockNewApps;

  final RelockPolicy relock;

  /// Randomize the digit positions on the lock keypad (anti-shoulder-surf).
  final bool randomizeKeypad;

  final bool intruderCaptureEnabled;

  /// Failed attempts before an intruder photo is captured.
  final int intruderThreshold;

  /// Show a fake "app has stopped" decoy instead of the lock screen.
  final bool fakeCoverEnabled;

  /// Device-admin uninstall protection is on. Mirrors whether OpenLock is an
  /// active device administrator; also tells the native monitor to guard the
  /// OS deactivate-admin / app-info / uninstall screens.
  final bool preventUninstall;

  /// Global default for hiding locked apps' notification content: the
  /// NotificationListenerService replaces each notification with a redacted
  /// OpenLock notice. Off by default. Only applies to locked apps.
  final bool hideNotifications;

  /// Per-package explicit overrides of [hideNotifications]. A package absent
  /// from the map follows the global flag; present maps to its explicit choice.
  final Map<String, bool> notificationOverrides;

  final List<LockSchedule> schedules;

  /// Strict Mode locks this package set until [strictModeEndsAtMillis].
  /// A null end time means indefinite. Expiry is evaluated by the native guard.
  final bool strictModeEnabled;
  final Set<String> strictModePackages;
  final int? strictModeEndsAtMillis;

  /// Independent DNS settings guard commitment. Null deadline means indefinite.
  final bool dnsGuardEnabled;
  final int? dnsGuardEndsAtMillis;

  bool dnsGuardActiveAt(DateTime now) =>
      dnsGuardEnabled &&
      (dnsGuardEndsAtMillis == null ||
          now.millisecondsSinceEpoch < dnsGuardEndsAtMillis!);

  /// User-editable copy shown on the full-screen Strict Mode barrier.
  final String strictScreenTitle;
  final String strictScreenMessage;
  final String strictScreenFooter;
  final int strictScreenPalette;

  bool strictModeActiveAt(DateTime now) =>
      strictModeEnabled &&
      (strictModeEndsAtMillis == null ||
          now.millisecondsSinceEpoch < strictModeEndsAtMillis!);

  /// Whether notifications from [package] should be hidden. Only locked apps
  /// qualify; an explicit per-app override wins over the global flag. Mirror of
  /// the Kotlin `ConfigStore.shouldHideNotificationsFor`.
  bool hidesNotificationsFor(String package) {
    if (!lockedPackages.contains(package)) return false;
    return notificationOverrides[package] ?? hideNotifications;
  }

  static const LockConfig empty = LockConfig();

  LockConfig copyWith({
    Set<String>? lockedPackages,
    bool? lockNewApps,
    RelockPolicy? relock,
    bool? randomizeKeypad,
    bool? intruderCaptureEnabled,
    int? intruderThreshold,
    bool? fakeCoverEnabled,
    bool? preventUninstall,
    bool? hideNotifications,
    Map<String, bool>? notificationOverrides,
    List<LockSchedule>? schedules,
    bool? strictModeEnabled,
    Set<String>? strictModePackages,
    int? strictModeEndsAtMillis,
    bool clearStrictModeEndsAtMillis = false,
    bool? dnsGuardEnabled,
    int? dnsGuardEndsAtMillis,
    bool clearDnsGuardEndsAtMillis = false,
    String? strictScreenTitle,
    String? strictScreenMessage,
    String? strictScreenFooter,
    int? strictScreenPalette,
  }) =>
      LockConfig(
        lockedPackages: lockedPackages ?? this.lockedPackages,
        lockNewApps: lockNewApps ?? this.lockNewApps,
        relock: relock ?? this.relock,
        randomizeKeypad: randomizeKeypad ?? this.randomizeKeypad,
        intruderCaptureEnabled:
            intruderCaptureEnabled ?? this.intruderCaptureEnabled,
        intruderThreshold: intruderThreshold ?? this.intruderThreshold,
        fakeCoverEnabled: fakeCoverEnabled ?? this.fakeCoverEnabled,
        preventUninstall: preventUninstall ?? this.preventUninstall,
        hideNotifications: hideNotifications ?? this.hideNotifications,
        notificationOverrides:
            notificationOverrides ?? this.notificationOverrides,
        schedules: schedules ?? this.schedules,
        strictModeEnabled: strictModeEnabled ?? this.strictModeEnabled,
        strictModePackages: strictModePackages ?? this.strictModePackages,
        strictModeEndsAtMillis: clearStrictModeEndsAtMillis
            ? null
            : strictModeEndsAtMillis ?? this.strictModeEndsAtMillis,
        dnsGuardEnabled: dnsGuardEnabled ?? this.dnsGuardEnabled,
        dnsGuardEndsAtMillis: clearDnsGuardEndsAtMillis
            ? null
            : dnsGuardEndsAtMillis ?? this.dnsGuardEndsAtMillis,
        strictScreenTitle: strictScreenTitle ?? this.strictScreenTitle,
        strictScreenMessage: strictScreenMessage ?? this.strictScreenMessage,
        strictScreenFooter: strictScreenFooter ?? this.strictScreenFooter,
        strictScreenPalette: strictScreenPalette ?? this.strictScreenPalette,
      );

  Map<String, dynamic> toJson() => {
        'lockedPackages': lockedPackages.toList()..sort(),
        'lockNewApps': lockNewApps,
        'relock': relock.toJson(),
        'randomizeKeypad': randomizeKeypad,
        'intruderCaptureEnabled': intruderCaptureEnabled,
        'intruderThreshold': intruderThreshold,
        'fakeCoverEnabled': fakeCoverEnabled,
        'preventUninstall': preventUninstall,
        'hideNotifications': hideNotifications,
        'notificationOverrides': notificationOverrides,
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'strictModeEnabled': strictModeEnabled,
        'strictModePackages': strictModePackages.toList()..sort(),
        'strictModeEndsAtMillis': strictModeEndsAtMillis,
        'dnsGuardEnabled': dnsGuardEnabled,
        'dnsGuardEndsAtMillis': dnsGuardEndsAtMillis,
        'strictScreenTitle': strictScreenTitle,
        'strictScreenMessage': strictScreenMessage,
        'strictScreenFooter': strictScreenFooter,
        'strictScreenPalette': strictScreenPalette,
      };

  factory LockConfig.fromJson(Map<String, dynamic> json) => LockConfig(
        lockedPackages: ((json['lockedPackages'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
        lockNewApps: json['lockNewApps'] as bool? ?? false,
        relock: json['relock'] is Map<String, dynamic>
            ? RelockPolicy.fromJson(json['relock'] as Map<String, dynamic>)
            : const RelockPolicy(),
        randomizeKeypad: json['randomizeKeypad'] as bool? ?? false,
        intruderCaptureEnabled:
            json['intruderCaptureEnabled'] as bool? ?? false,
        intruderThreshold: (json['intruderThreshold'] as num?)?.toInt() ?? 3,
        fakeCoverEnabled: json['fakeCoverEnabled'] as bool? ?? false,
        preventUninstall: json['preventUninstall'] as bool? ?? false,
        hideNotifications: json['hideNotifications'] as bool? ?? false,
        notificationOverrides:
            ((json['notificationOverrides'] as Map<dynamic, dynamic>?) ??
                    const {})
                .map((key, value) => MapEntry(key as String, value as bool)),
        schedules: ((json['schedules'] as List<dynamic>?) ?? const [])
            .map((e) => LockSchedule.fromJson(e as Map<String, dynamic>))
            .toList(),
        strictModeEnabled: json['strictModeEnabled'] as bool? ?? false,
        strictModePackages:
            ((json['strictModePackages'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toSet(),
        strictModeEndsAtMillis:
            (json['strictModeEndsAtMillis'] as num?)?.toInt(),
        dnsGuardEnabled: json['dnsGuardEnabled'] as bool? ?? false,
        dnsGuardEndsAtMillis:
            (json['dnsGuardEndsAtMillis'] as num?)?.toInt(),
        strictScreenTitle: json['strictScreenTitle'] as String? ??
            'WAKTUNYA BERHENTI',
        strictScreenMessage: json['strictScreenMessage'] as String? ??
            'Kamu sedang menjaga komitmenmu. Aplikasi ini belum bisa digunakan.',
        strictScreenFooter: json['strictScreenFooter'] as String? ??
            'Tetap kuat. Waktu perlindungan akan berakhir sesuai jadwal.',
        strictScreenPalette:
            (json['strictScreenPalette'] as num?)?.toInt() ?? 0,
      );

  /// The exact map handed to the native monitor. [pinHash]/[pinSalt] are the
  /// PBKDF2 verifier the on-top LockActivity checks entered PINs against; they
  /// live in secure storage and are merged in here at push time.
  Map<String, dynamic> toNativeMap({
    String pinHash = '',
    String pinSalt = '',
    bool biometricEnabled = false,
  }) =>
      {
        'lockedPackages': lockedPackages.toList()..sort(),
        'relockMode': relock.mode.storageValue,
        'relockTimeoutMinutes': relock.timeout.inMinutes,
        'randomizeKeypad': randomizeKeypad,
        'intruderCaptureEnabled': intruderCaptureEnabled,
        'intruderThreshold': intruderThreshold,
        'fakeCoverEnabled': fakeCoverEnabled,
        'preventUninstall': preventUninstall,
        'hideNotifications': hideNotifications,
        'notificationOverrides': notificationOverrides,
        'biometricEnabled': biometricEnabled,
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'strictModeEnabled': strictModeEnabled,
        'strictModePackages': strictModePackages.toList()..sort(),
        'strictModeEndsAtMillis': strictModeEndsAtMillis,
        'strictScreenTitle': strictScreenTitle,
        'strictScreenMessage': strictScreenMessage,
        'strictScreenFooter': strictScreenFooter,
        'strictScreenPalette': strictScreenPalette,
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'pinIterations': 120000,
      };
}
