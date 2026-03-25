import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _kThemeModeKey = 'theme_mode';

  @override
  ThemeMode build() {
    _loadThemeMode();
    return ThemeMode.system;
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_kThemeModeKey);
    if (savedMode != null) {
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => ThemeMode.system,
      );
    }
  }

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _saveThemeMode(state);
  }

  void setMode(ThemeMode mode) {
    state = mode;
    _saveThemeMode(mode);
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
