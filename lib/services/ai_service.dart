import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../appwrite_client.dart';
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
        return 'AI requires an active PointChat AI subscription.';
      }

      final payload = <String, dynamic>{'prompt': prompt};
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
        payload['systemPrompt'] = systemPrompt.trim();
      }

      final response = await appwriteFunctions.createExecution(
        functionId: 'chat_ai',
        body: jsonEncode(payload),
      );

      final responseBody = response.responseBody;
      if (responseBody.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        if (data['success'] == true) {
          return data['text'] as String;
        } else {
          return '⚠️ AI error: ${data['error']}';
        }
      }
      return 'Sorry, I couldn\'t generate a response.';
    } catch (e) {
      debugPrint('Appwrite AI function error: $e');
      return '⚠️ AI error: ${e.toString().split('\n').first}';
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
