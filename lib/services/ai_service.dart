import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // TODO: REPLACE THIS WITH YOUR REAL API KEY FROM Google AI Studio (aistudio.google.com/app/apikey)
  static const String _apiKey = 'AIzaSyDpOAgw6-EGuybp_eeUjVj_ViJHiyWbZps';

  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  GenerativeModel? _model;

  GenerativeModel get model {
    if (_apiKey == 'AIzaSyDpOAgw6-EGuybp_eeUjVj_ViJHiyWbZps' ||
        _apiKey.isEmpty) {
      throw Exception(
        'PLEASE ENTER YOUR GOOGLE GEMINI API KEY IN lib/services/ai_service.dart',
      );
    }

    _model ??= GenerativeModel(
      model: '',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        maxOutputTokens: 1024,
        temperature: 0.7,
        topP: 0.95,
        topK: 40,
      ),
      systemInstruction: Content.system(
        'You are a helpful AI assistant integrated into PointChat, a messaging app. '
        'Keep responses concise, friendly, and useful. '
        'Format your responses for chat — use short paragraphs, emojis when appropriate, and be conversational. '
        'Maximum 2-3 sentences unless the user asks for more detail.',
      ),
    );
    return _model!;
  }

  /// Generate a single response from a prompt
  Future<String> generateResponse(String prompt) async {
    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Sorry, I couldn\'t generate a response.';
    } catch (e) {
      debugPrint('Gemini AI error: $e');
      return '⚠️ AI error: ${e.toString().split('\n').first}';
    }
  }

  /// Stream a response from a prompt
  Stream<String> streamResponse(String prompt) async* {
    try {
      final response = model.generateContentStream([Content.text(prompt)]);
      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      debugPrint('Gemini AI stream error: $e');
      yield '⚠️ AI error: ${e.toString().split('\n').first}';
    }
  }
}
