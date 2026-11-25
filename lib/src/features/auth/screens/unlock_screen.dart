import 'dart:async';

import 'package:core_crypto/core_crypto.dart';
import 'package:core_lock/core_lock.dart'
    show
        LockLayout,
        LockShake,
        LockTextLink,
        formatLockCountdown;
import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/features/auth/providers/auth_providers.dart';
import 'package:openlock/src/features/auth/services/pin_auth_service.dart';
import 'package:openlock/src/features/auth/widgets/pin_entry_panel.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';

/// Unlock gate for opening OpenLock itself: PIN dots, a numeric keypad with
/// automatic six-digit submission, fingerprint access, and an escalating
/// cooldown after repeated wrong attempts. "Lupa PIN?" opens recovery.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  /// Key height bounds. The keypad is sized from the screen height so it fits
  /// a 360 × 640 phone without scrolling; keys never drop below the tap
  /// target.
  static const double minKeyHeight = 52;
  static const double maxKeyHeight = 64;

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _panelKey = GlobalKey<PinEntryPanelState>();
  String? _message;
  Duration _cooldown = Duration.zero;
  Timer? _ticker;
  bool _recovering = false;
  int _failures = 0;

  /// Fingerprint unlock is on: the button shows and the prompt starts on the
  /// first frame.
  late final bool _biometric =
      ref.read(sessionProvider.notifier).biometricEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCooldown();
      _tryBiometric();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _syncCooldown() async {
    final remaining =
        await ref.read(pinAuthServiceProvider).cooldownRemaining();
    if (!mounted) return;
    setState(() => _cooldown = remaining);
    _ticker?.cancel();
    if (remaining > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _cooldown -= const Duration(seconds: 1);
          if (_cooldown <= Duration.zero) {
            _cooldown = Duration.zero;
            _ticker?.cancel();
          }
        });
      });
    }
  }

  /// Starts the system prompt; the fingerprint button brings it back. The
  /// prompt shows its own mismatch and cancel feedback, so a failed or
  /// dismissed prompt adds nothing here.
  Future<void> _tryBiometric() async {
    final session = ref.read(sessionProvider.notifier);
    if (!session.biometricEnabled) return;
    if (await ref.read(biometricServiceProvider).authenticate()) {
      session.markUnlocked(UnlockMethod.biometric, then: AppRoutes.apps);
    }
  }

  Future<void> _submit(String pin) async {
    final result = await ref.read(pinAuthServiceProvider).unlock(pin);
    if (!mounted) return;
    switch (result) {
      case UnlockSuccess():
        // Re-push config in case anything changed while locked.
        unawaited(ref.read(configControllerProvider.notifier).pushToNative());
        ref
            .read(sessionProvider.notifier)
            .markUnlocked(UnlockMethod.pin, then: AppRoutes.apps);
      case UnlockWrongPin(:final cooldown):
        _panelKey.currentState?.clear();
        setState(() {
          _failures++;
          _message = 'Wrong PIN';
        });
        if (cooldown != null) await _syncCooldown();
      case UnlockCoolingDown():
        _panelKey.currentState?.clear();
        await _syncCooldown();
    }
  }

  /// Key height for the available screen space; short screens can scroll.
  double _keyHeight(double height) {
    // Reserve room for the brand header, PIN dots, recovery link and footer.
    // Short screens can scroll rather than shrinking keys below a usable size.
    return ((height - 470) / 4).clamp(
      UnlockScreen.minKeyHeight,
      UnlockScreen.maxKeyHeight,
    ).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // The session resolves the config before the unlock screen's first frame.
    final randomize = ref.watch(configControllerProvider
        .select((config) => config.requireValue.randomizeKeypad));
    final coolingDown = _cooldown > Duration.zero;
    final error = coolingDown
        ? 'Too many attempts. Try again in ${formatLockCountdown(_cooldown)}.'
        : _message;
    final c = SuiteColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    SizedBox(
                      height: box.maxHeight < 660
                          ? AppSpacing.lg
                          : AppSpacing.xl,
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: c.hairline),
                      ),
                      alignment: Alignment.center,
                      child: const SuiteAppIcon(
                        app: SuiteApp.openlock,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Open',
                            style: AppTextStyles.h2.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: 'Lock',
                            style: AppTextStyles.h2.copyWith(color: c.accent),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _recovering
                          ? 'Reset your PIN'
                          : 'Masukkan PIN keamanan',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    SizedBox(
                      height: _recovering
                          ? AppSpacing.lg
                          : AppSpacing.xl * 2,
                    ),
                    if (_recovering)
                      _RecoveryForm(
                        enabled: !coolingDown,
                        error: coolingDown ? error : null,
                        onCooldown: _syncCooldown,
                        onBack: () => setState(() => _recovering = false),
                      )
                    else
                      PinEntryPanel(
                        key: _panelKey,
                        enabled: !coolingDown,
                        randomize: randomize,
                        error: error,
                        failures: _failures,
                        keyHeight: _keyHeight(box.maxHeight),
                        showBiometric: _biometric,
                        onBiometric: _biometric && !coolingDown
                            ? _tryBiometric
                            : null,
                        onSubmit: _submit,
                      ),
                    if (!_recovering) ...[
                      const SizedBox(height: AppSpacing.md),
                      LockTextLink(
                        label: 'Lupa PIN?',
                        onPressed: () => setState(() {
                          _message = null;
                          _recovering = true;
                        }),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const Spacer(),
                    const SuiteEndorsement(),
                    const SizedBox(height: AppSpacing.mdl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Recovery key + new PIN. A match sets the PIN, pushes it to native and
/// unlocks (the session notifier handles all three).
class _RecoveryForm extends ConsumerStatefulWidget {
  const _RecoveryForm({
    required this.enabled,
    required this.error,
    required this.onCooldown,
    required this.onBack,
  });

  final bool enabled;

  /// The cooldown line, shown in place of the form's own error.
  final String? error;
  final Future<void> Function() onCooldown;
  final VoidCallback onBack;

  @override
  ConsumerState<_RecoveryForm> createState() => _RecoveryFormState();
}

class _RecoveryFormState extends ConsumerState<_RecoveryForm> {
  final _key = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  late final Future<bool> _hasKey =
      ref.read(pinAuthServiceProvider).hasRecoveryKey();
  bool _busy = false;
  String? _error;
  int _failures = 0;

  @override
  void dispose() {
    _key.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String? problem;
    if (RecoveryKey.normalize(_key.text) == null) {
      problem = 'A recovery key has ${RecoveryKey.length} letters and numbers';
    } else if (_pin.text.length < PinAuthService.minPinLength) {
      problem = 'New PIN must be at least 6 digits';
    } else if (_pin.text != _confirm.text) {
      problem = 'New PINs do not match';
    } else {
      problem = null;
    }
    if (problem != null) {
      setState(() {
        _error = problem;
        _failures++;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(sessionProvider.notifier).recover(
          recoveryKey: _key.text,
          newPin: _pin.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case UnlockSuccess():
        break;
      case UnlockWrongPin(:final cooldown):
        setState(() {
          _error = 'That recovery key is not right';
          _failures++;
        });
        if (cooldown != null) await widget.onCooldown();
      case UnlockCoolingDown():
        await widget.onCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    return FutureBuilder<bool>(
      future: _hasKey,
      builder: (context, snapshot) {
        final hasKey = snapshot.data;
        if (hasKey == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasKey
                  ? 'Enter the recovery key you saved when you set up '
                      'OpenLock, then choose a new PIN.'
                  : 'No recovery key was set up, so a forgotten PIN cannot '
                      'be reset. Unlock with your fingerprint, then create a '
                      'recovery key in Settings.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
            ),
            if (hasKey) ...[
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _key,
                label: 'Recovery key',
                hint: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
                monospace: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: LockLayout.gap),
              AppTextField(
                controller: _pin,
                label: 'New PIN',
                obscureText: true,
                monospace: true,
                clearable: false,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: LockLayout.gap),
              LockShake(
                trigger: _failures,
                child: AppTextField(
                  controller: _confirm,
                  label: 'Confirm new PIN',
                  obscureText: true,
                  monospace: true,
                  clearable: false,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.go,
                  errorText: widget.error ?? _error,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: LockLayout.gap),
              VaultButton(
                label: 'Reset and unlock',
                isLoading: _busy,
                onPressed: widget.enabled && !_busy ? _submit : null,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            LockTextLink(
              label: 'Back to unlock',
              onPressed: _busy ? null : widget.onBack,
            ),
          ],
        );
      },
    );
  }
}
