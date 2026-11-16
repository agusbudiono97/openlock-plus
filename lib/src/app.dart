import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/router/app_router.dart';

class OpenLockApp extends ConsumerWidget {
  const OpenLockApp({super.key});

  ThemeData _motionTheme(Brightness brightness) {
    return AppTheme.build(brightness, accent: AppAccents.openlock).copyWith(
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
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final appearance = ref.watch(appearanceProvider);
    return ListenableBuilder(
      listenable: appearance,
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
    );
  }
}
