import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted UI prefs for the stream composer.
class ComposerPreferences {
  ComposerPreferences._();

  static const _kTipsRotate = 'composer_tips_rotate';
  static const _kTipsHidden = 'composer_tips_hidden';

  /// Synced with [getTipsHidden] / [setTipsHidden] so profile changes apply without restart.
  static final ValueNotifier<bool> tipsHiddenListenable = ValueNotifier(false);

  static Future<bool> getTipsRotateEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kTipsRotate) ?? true;
  }

  static Future<void> setTipsRotateEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kTipsRotate, value);
  }

  static Future<bool> getTipsHidden() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kTipsHidden) ?? false;
  }

  static Future<void> setTipsHidden(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kTipsHidden, value);
    tipsHiddenListenable.value = value;
  }

  static Future<void> syncListenableFromPrefs() async {
    tipsHiddenListenable.value = await getTipsHidden();
  }
}
