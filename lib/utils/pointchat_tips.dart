import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads `assets/pointchat_tips.json` for rotating composer hints and optional
/// `ai_knowledge` appended to AI system prompts.
class PointchatTips {
  PointchatTips._();
  static final PointchatTips instance = PointchatTips._();

  List<String> rotatingTips = const _DefaultTips().tips;
  String aiKnowledge = '';
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
      final ak = j['ai_knowledge'];
      if (ak != null) {
        aiKnowledge = ak.toString().trim();
      }
    } catch (_) {
      rotatingTips = const _DefaultTips().tips;
      aiKnowledge = '';
    }
    loaded = true;
  }

  /// Appended to [systemPrompt] in [AiService] so the model knows current features.
  String aiKnowledgeSuffix() {
    if (aiKnowledge.isEmpty) return '';
    return '\n\nApp knowledge (use when relevant; do not invent features not listed):\n$aiKnowledge';
  }
}

class _DefaultTips {
  const _DefaultTips();
  List<String> get tips => const [
        'Message someone with @name or a group with #name',
        '@ai — PointChat AI · /newbot Name — custom bot',
        'Location: use the pin button next to the composer',
        'Long-press the mic area to record a voice note',
      ];
}
