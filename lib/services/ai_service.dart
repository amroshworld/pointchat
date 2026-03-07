import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../appwrite_client.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  /// Generate a single response from a prompt
  Future<String> generateResponse(String prompt, {String? systemPrompt}) async {
    try {
      final response = await appwriteFunctions.createExecution(
        functionId: 'chat_ai',
        body: jsonEncode({'prompt': prompt, 'systemPrompt': ?systemPrompt}),
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
      debugPrint('Vercel AI SDK error: $e');
      return '⚠️ AI error: ${e.toString().split('\n').first}';
    }
  }

  /// Stream a response from a prompt
  /// Currently Vercel AI SDK over Appwrite Functions doesn't support streaming back natively via the Dart SDK execution method in the same way.
  /// We'll fall back to just yielding the full response once it's complete to maintain API compatibility.
  Stream<String> streamResponse(String prompt, {String? systemPrompt}) async* {
    yield await generateResponse(prompt, systemPrompt: systemPrompt);
  }
}
