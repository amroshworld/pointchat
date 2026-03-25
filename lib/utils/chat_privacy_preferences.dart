import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locked DM chats (blur preview + biometric/PIN to expand).
class ChatPrivacyPreferences {
  ChatPrivacyPreferences._();

  static const _kLockedChatIds = 'chat_locked_ids_json';
  static const _kChatPin = 'chat_privacy_pin';
  static const _kReduceUiMotion = 'perf_reduce_ui_motion';

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
    } else {
      await p.setString(_kChatPin, pin);
    }
  }

  /// Shorter animations / lighter inline message cap in chat list.
  static Future<bool> getReduceUiMotion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kReduceUiMotion) ?? false;
  }

  static Future<void> setReduceUiMotion(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReduceUiMotion, value);
    reduceUiMotionListenable.value = value;
  }

  static final ValueNotifier<bool> reduceUiMotionListenable = ValueNotifier(
    false,
  );

  static Future<void> syncPerformanceListenable() async {
    reduceUiMotionListenable.value = await getReduceUiMotion();
  }
}
