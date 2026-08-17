import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads `assets/pointchat_tips.json` for rotating composer hints.
class PointchatTips {
  PointchatTips._();
  static final PointchatTips instance = PointchatTips._();

  List<String> rotatingTips = const _DefaultTips().tips;
  bool loaded = false;

  static const _assetPath = 'assets/pointchat_tips.json';

  Future<void> ensureLoaded() async {
    if (loaded) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final tips = j['rotating_tips'];
      if (tips is List && tips.isNotEmpty) {
        rotatingTips = tips
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (rotatingTips.isEmpty) {
        rotatingTips = const _DefaultTips().tips;
      }
    } catch (_) {
      rotatingTips = const _DefaultTips().tips;
    }
    loaded = true;
  }
}

class _DefaultTips {
  const _DefaultTips();
  List<String> get tips => const [
        'Message someone with @name or a group with #name',
        '/setting — open settings for seen receipts and notify-on-seen',
        'Location: use the pin button next to the composer',
        'Long-press the mic area to record a voice note',
      ];
}
