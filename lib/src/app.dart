import 'dart:async';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/theme/theme_palette.dart';
import 'package:openlock/src/core/router/app_router.dart';

class OpenLockApp extends ConsumerStatefulWidget {
  const OpenLockApp({super.key});

  @override
  ConsumerState<OpenLockApp> createState() => _OpenLockAppState();
}

class _OpenLockAppState extends ConsumerState<OpenLockApp> {
  late final ThemePaletteController _palette;

  @override
  void initState() {
    super.initState();
    _palette = ThemePaletteController();
    unawaited(_palette.load());
  }

  @override
  void dispose() {
    _palette.dispose();
    super.dispose();
  }

  ThemeData _motionTheme(Brightness brightness) {
    return AppTheme.seeded(brightness, _palette.seed).copyWith(
      // Material's forward transition gives pushed pages a short, coherent
      // entrance without changing navigation or page state.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final appearance = ref.watch(appearanceProvider);
    return ThemePaletteScope(
      controller: _palette,
      child: ListenableBuilder(
      listenable: Listenable.merge([appearance, _palette]),
      builder: (context, _) => MaterialApp.router(
        title: 'OpenLock',
        theme: _motionTheme(Brightness.light),
        darkTheme: _motionTheme(Brightness.dark),
        themeMode: appearance.mode,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
        ),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
      ),
    );
  }
}
