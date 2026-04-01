import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locked DM chats (blur preview + biometric/PIN to expand).
class ChatPrivacyPreferences {
  ChatPrivacyPreferences._();

  static const _kLockedChatIds = 'chat_locked_ids_json';
  static const _kChatPin = 'chat_privacy_pin';
  static const _kAppLockEnabled = 'app_lock_enabled';

  /// When true, [AppLockGate] requires biometric or PIN to use the app after open/resume.
  static Future<bool> isAppLockEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAppLockEnabled) ?? false;
  }

  static Future<void> setAppLockEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAppLockEnabled, value);
    appLockEnabledListenable.value = value;
  }

  static final ValueNotifier<bool> appLockEnabledListenable =
      ValueNotifier<bool>(false);

  /// Cached PIN for synchronous UI (e.g. app lock overlay on resume).
  static final ValueNotifier<String> privacyPinListenable = ValueNotifier('');

  static Future<void> syncAppLockListenable() async {
    appLockEnabledListenable.value = await isAppLockEnabled();
    privacyPinListenable.value = await getPrivacyPin();
    lockedChatsListenable.value = await getLockedChatIds();
  }

  static Future<Set<String>> getLockedChatIds() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLockedChatIds);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return {};
  }

  static Future<void> setLockedChatIds(Set<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLockedChatIds, jsonEncode(ids.toList()));
    lockedChatsListenable.value = ids;
  }

  static Future<void> toggleLocked(String chatId, bool locked) async {
    final cur = await getLockedChatIds();
    if (locked) {
      cur.add(chatId);
    } else {
      cur.remove(chatId);
    }
    await setLockedChatIds(cur);
  }

  static final ValueNotifier<Set<String>> lockedChatsListenable = ValueNotifier(
    {},
  );

  static Future<void> syncLockedListenable() async {
    lockedChatsListenable.value = await getLockedChatIds();
  }

  /// Simple device PIN (not hardware-backed). Empty = disabled.
  static Future<String> getPrivacyPin() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kChatPin) ?? '';
  }

  static Future<void> setPrivacyPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    if (pin.isEmpty) {
      await p.remove(_kChatPin);
      privacyPinListenable.value = '';
    } else {
      await p.setString(_kChatPin, pin);
      privacyPinListenable.value = pin;
    }
  }
}
