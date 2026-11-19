import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Presentation-only theme accent. Kept in SharedPreferences, completely
/// separate from PIN, lock configuration, and enforcement storage.
class ThemePaletteController extends ChangeNotifier {
  static const _storageKey = 'openlock_theme_seed';
  static const defaultSeed = Color(0xFFFF8A3D);

  Color _seed = defaultSeed;
  Color get seed => _seed;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return;
    _seed = Color(0xFF000000 | parsed);
    notifyListeners();
  }

  Future<void> setSeed(Color color) async {
    final value = color.toARGB32() & 0x00FFFFFF;
    if ((_seed.toARGB32() & 0x00FFFFFF) == value) return;
    _seed = Color(0xFF000000 | value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.toRadixString(16).padLeft(6, '0'));
  }

  Future<void> reset() => setSeed(defaultSeed);
}

class ThemePaletteScope extends InheritedNotifier<ThemePaletteController> {
  const ThemePaletteScope({
    required ThemePaletteController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ThemePaletteController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemePaletteScope>();
    assert(scope != null, 'ThemePaletteScope is missing above this context.');
    return scope!.notifier!;
  }
}
