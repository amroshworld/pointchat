import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:appwrite/enums.dart';
import '../appwrite_client.dart';
import '../utils/pointchat_tips.dart';
import 'subscription_service.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  /// Generate a single response from a prompt
  Future<String> generateResponse(String prompt, {String? systemPrompt}) async {
    try {
      final hasAccess = await SubscriptionService.instance.ensureAiAccess();
      if (!hasAccess) {
        return 'AI access is not active for this account.';
      }

      await PointchatTips.instance.ensureLoaded();
      final tipCtx = PointchatTips.instance.aiKnowledgeSuffix();
      final mergedSystem = <String>[
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
          systemPrompt.trim(),
        if (tipCtx.isNotEmpty) tipCtx,
      ].join('\n');

      final payload = <String, dynamic>{'prompt': prompt};
      if (mergedSystem.isNotEmpty) {
        payload['systemPrompt'] = mergedSystem;
      }

      final response = await appwriteFunctions.createExecution(
        functionId: 'chat_ai',
        body: jsonEncode(payload),
      );

      if (response.status == ExecutionStatus.failed) {
        if (kDebugMode) {
          debugPrint(
            'chat_ai execution failed: errors=${response.errors} logs=${response.logs}',
          );
        }
        return 'AI is temporarily unavailable. Please try again.';
      }

      if (response.responseStatusCode < 200 ||
          response.responseStatusCode >= 300) {
        if (kDebugMode) {
          debugPrint(
            'chat_ai HTTP ${response.responseStatusCode} body=${response.responseBody} logs=${response.logs}',
          );
        }
        return 'AI is temporarily unavailable. Please try again.';
      }

      final responseBody = response.responseBody;
      if (responseBody.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        if (data['success'] == true) {
          return data['text'] as String;
        }
        if (kDebugMode) {
          debugPrint('chat_ai success=false payload=$data');
        }
        return 'AI is temporarily unavailable. Please try again.';
      }
      return 'AI is temporarily unavailable. Please try again.';
    } catch (e) {
      debugPrint('Appwrite AI function error: $e');
      return 'AI is temporarily unavailable. Please try again.';
    }
  }

  /// Stream a response from a prompt
  /// Appwrite Functions return the final payload, so this keeps the calling UI
  /// compatible while using the safer function execution path.
  /// We'll fall back to just yielding the full response once it's complete to maintain API compatibility.
  Stream<String> streamResponse(String prompt, {String? systemPrompt}) async* {
    yield await generateResponse(prompt, systemPrompt: systemPrompt);
  }
}
