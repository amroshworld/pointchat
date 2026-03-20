import 'package:shared_preferences/shared_preferences.dart';

/// Persisted UI prefs for the stream composer.
class ComposerPreferences {
  ComposerPreferences._();

  static const _kTipsRotate = 'composer_tips_rotate';

  static Future<bool> getTipsRotateEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kTipsRotate) ?? true;
  }

  static Future<void> setTipsRotateEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kTipsRotate, value);
  }
}
