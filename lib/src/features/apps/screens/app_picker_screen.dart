import 'dart:io';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_update/core_update.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/core/store_build.dart';
import 'package:openlock/src/core/widgets/screen_header.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/models/relock_policy.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/intruder/providers/intruder_providers.dart';

class AppPickerScreen extends ConsumerWidget {
  const AppPickerScreen({super.key});

  /// Rows shown while the installed apps load; enough to fill the screen
  /// below the header.
  static const _skeletonRows = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(appListProvider);
    final config =
        ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final view = list.valueOrNull;
    final rowCount = switch (list) {
      AsyncData(:final value) =>
        value.visible.isEmpty ? 1 : value.visible.length,
      AsyncError() => 1,
      _ => _skeletonRows,
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xl,
              ),
              // Header blocks first, then one lazily built row per app. The
              // header never waits for the app list; only the rows do.
              itemCount: _headerCount + rowCount,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              // Resolve upcoming launcher icons before they enter the viewport.
              cacheExtent: 720,
              itemBuilder: (context, index) {
                if (index < _headerCount) {
                  return _header(
                    context,
                    ref,
                    index,
                    config: config,
                    total: view?.total,
                    lockedCount: view?.lockedCount,
                  );
                }
                final i = index - _headerCount;
                if (list.hasError) {
                  return const AppEmptyState(
                    compact: true,
                    icon: Icons.error_outline_rounded,
                    title: 'Gagal memuat aplikasi',
                    message:
                        'Daftar aplikasi yang terpasang belum tersedia.',
                  );
                }
                if (view == null) {
                  return GroupedRowItem(
                    isFirst: i == 0,
                    isLast: i == rowCount - 1,
                    child: const _AppTileSkeleton(),
                  );
                }
                if (view.visible.isEmpty) {
                  return const AppEmptyState(
                    compact: true,
                    icon: Icons.search_off_rounded,
                    title: 'Aplikasi tidak ditemukan',
                    message: 'Coba kata pencarian lain.',
                  );
                }
                final app = view.visible[i];
                return RepaintBoundary(
                  child: GroupedRowItem(
                    isFirst: i == 0,
                    isLast: i == view.visible.length - 1,
                    child: _AppTile(
                      app: app,
                      config: config,
                      onToggle: () => ref
                          .read(configControllerProvider.notifier)
                          .toggleApp(app.packageName),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static const _headerCount = 5;

  Widget _header(
    BuildContext context,
    WidgetRef ref,
    int index, {
    required LockConfig config,
    required int? total,
    required int? lockedCount,
  }) {
    switch (index) {
      case 0:
        return const ScreenHeader(eyebrow: 'Perlindungan', title: 'OpenLock');
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!kStoreBuild) const _UpdateBannerCard(),
            _ProtectionHero(
              config: config,
              lockedCount: lockedCount,
              total: total,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLead('Daftar aplikasi'),
            AppSearchField(
              hint: 'Cari aplikasi',
              onChanged: (value) =>
                  ref.read(appSearchQueryProvider.notifier).state = value,
            ),
          ],
        );
      case 3:
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Text(
            lockedCount == null ? '' : '$lockedCount aplikasi dikunci',
            style: AppTextStyles.label.copyWith(
              color: SuiteColors.of(context).textSecondary,
            ),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.strictMode),
                  icon: const Icon(Icons.lock_clock_rounded),
                  label: const Text('Blokir Cepat'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.schedules),
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Jadwal baru'),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _ProtectionStat extends StatelessWidget {
  const _ProtectionStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 104, maxWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelStrong.copyWith(
              color: valueColor ?? c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashboard hero: how many apps are guarded, with schedules, intruder
/// events and the relock rule that explain the protection beneath it.
class _ProtectionHero extends ConsumerWidget {
  const _ProtectionHero({
    required this.config,
    required this.lockedCount,
    required this.total,
  });

  final LockConfig config;

  /// Null until the installed apps have loaded.
  final int? lockedCount;
  final int? total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SuiteColors.of(context);
    final intruders = ref.watch(intruderControllerProvider).valueOrNull;
    final activeSchedules = config.schedules.where((s) => s.enabled).length;
    final relockLabel = switch (config.relock.mode) {
      RelockMode.immediately => 'Saat keluar',
      RelockMode.onScreenOff => 'Layar mati',
      RelockMode.afterTimeout => '${config.relock.timeout.inMinutes} menit',
    };

    // Keep the dashboard card local instead of using a fixed-column footer.
    // The soft accent wash adds depth without changing any protection state.
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        side: BorderSide(color: c.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.48),
              c.surface,
              c.surface,
            ],
            stops: const [0, 0.48, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.shield_moon_rounded,
                      color: scheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Text(
                      'Aplikasi terlindungi',
                      style: AppTextStyles.label.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'OPENLOCK',
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  lockedCount == null ? '-' : '$lockedCount',
                  key: ValueKey(lockedCount),
                  style: AppTextStyles.hero.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                total == null
                    ? 'Menghitung aplikasi terpasang'
                    : 'dari $total aplikasi terpasang',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: c.textTertiary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(height: 1, color: c.hairline),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ProtectionStat(label: 'Jadwal', value: '$activeSchedules aktif'),
                  _ProtectionStat(
                    label: 'Penyusup',
                    value: intruders == null ? '-' : '${intruders.length}',
                    valueColor:
                        (intruders?.isNotEmpty ?? false) ? c.negative : null,
                  ),
                  _ProtectionStat(label: 'Kunci ulang', value: relockLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppTile extends ConsumerWidget {
  const _AppTile({
    required this.app,
    required this.config,
    required this.onToggle,
  });

  final InstalledApp app;
  final LockConfig config;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SuiteColors.of(context);
    final frozen = config.strictModeActiveAt(DateTime.now());
    final locked = config.lockedPackages.contains(app.packageName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListRow(
          onTap: frozen ? null : onToggle,
          leading: _AppIcon(app: app),
          title: app.label,
          subtitle: app.packageName,
          trailing: Switch(
            value: locked,
            onChanged: frozen ? null : (_) => onToggle(),
          ),
        ),
        // Per-app notification-hiding override, only meaningful once the app is
        // locked. Reflects the effective choice (override, else the global
        // default) and writes an explicit per-app override. Inset like
        // AppListRow, so it starts under the app's name, its switch lines up
        // under the lock switch, and the label wraps rather than pushing the
        // switch out of the card.
        if (locked)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + _iconSize + AppSpacing.smd + 2,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 18,
                  color: c.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Sembunyikan notifikasi',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Switch(
                  value: config.hidesNotificationsFor(app.packageName),
                  onChanged: frozen
                      ? null
                      : (value) => ref
                          .read(configControllerProvider.notifier)
                          .setNotificationOverride(app.packageName, value),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// An [_AppTile] while the installed apps load: built from the same row so
/// it has exactly the same height, with the text left blank.
class _AppTileSkeleton extends StatelessWidget {
  const _AppTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppListRow(
      leading: Skeleton(width: _iconSize, height: _iconSize, radius: 12),
      title: '',
      subtitle: '',
      trailing: Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: Switch(value: false, onChanged: null),
      ),
    );
  }
}

const double _iconSize = 40;

/// A row's launcher icon, loaded from native's disk cache once the row is
/// built. A same-size placeholder holds the space until it is decoded.
class _AppIcon extends ConsumerWidget {
  const _AppIcon({required this.app});

  final InstalledApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loader = ref.watch(appIconLoaderProvider);
    if (loader.isResolved(app)) return _icon(context, loader.resolvedPath(app));
    return FutureBuilder<String?>(
      future: loader.pathFor(app),
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(hasError: true) => _icon(context, null),
        AsyncSnapshot(connectionState: ConnectionState.done) =>
          _icon(context, snapshot.data),
        _ => const _IconPlaceholder(),
      },
    );
  }

  Widget _icon(BuildContext context, String? path) {
    if (path == null) {
      return SizedBox.square(
        dimension: _iconSize,
        child:
            Icon(Icons.android, color: SuiteColors.of(context).textSecondary),
      );
    }
    // Decode straight to the drawn size; decoding runs off the UI thread.
    final px = (_iconSize * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.file(
      File(path),
      width: _iconSize,
      height: _iconSize,
      cacheWidth: px,
      cacheHeight: px,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) =>
          sync || frame != null ? child : const _IconPlaceholder(),
      // The OS may clear the cache directory while the app is running.
      errorBuilder: (context, _, __) => _icon(context, null),
    );
  }
}

class _IconPlaceholder extends StatelessWidget {
  const _IconPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _iconSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SuiteColors.of(context).surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// "Update available" card, shown when a newer GitHub release exists and the
/// user hasn't dismissed it this session.
class _UpdateBannerCard extends ConsumerWidget {
  const _UpdateBannerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateCheckProvider).valueOrNull;
    final dismissed = ref.watch(updateDismissedProvider);
    if (info == null || dismissed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.smd),
      child: UpdateBanner(
        info: info,
        onUpdate: () => ref.read(updateServiceProvider).openDownload(info),
        onDismiss: () =>
            ref.read(updateDismissedProvider.notifier).state = true,
      ),
    );
  }
}
