import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

class ThemeAnalyzer {
  late final GenerativeModel _model;

  ThemeAnalyzer() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY tidak ditemukan di .env');
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(properties: {
          'theme': Schema.string(),
          'confidence': Schema.number(),
        }),
      ),
    );
  }

  /// Analyze theme using RAG-retrieved context (grounded generation)
  Future<String?> getThemeFromContext(
    String contextText,
    String query,
  ) async {
    if (contextText.trim().isEmpty) {
      return 'default';
    }

    final prompt = '''
Your task is to analyze the emotional or narrative theme based STRICTLY on the following context only.

QUERY: $query

CONTEXT:
$contextText

INSTRUCTIONS:
1. Analyze ONLY the provided context above. Do not use external knowledge.
2. Determine the predominant emotional theme from: thrill, happy, calming, melancholic, battle, default
3. If you are less than 80% confident or the context is insufficient, return "default"
4. Return JSON format: {"theme": "theme_name", "confidence": 0.0-1.0}

THEME DEFINITIONS:
- thrill: suspense, tension, excitement, mystery, adventure
- happy: joy, celebration, humor, warmth, contentment
- calming: peace, reflection, nature, serenity, meditation
- melancholic: sadness, loss, regret, nostalgia, loneliness
- battle: conflict, action, war, confrontation, struggle
- default: neutral, unclear, or mixed emotions
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final jsonText = response.text?.trim() ?? '{}';
      final jsonResult = jsonDecode(jsonText);
      
      final theme = jsonResult['theme'] as String?;
      final confidence = (jsonResult['confidence'] as num?)?.toDouble() ?? 0.0;

      // Enforce 80% confidence threshold
      if (confidence < 0.8 || theme == null || theme.isEmpty) {
        return 'default';
      }

      return theme;
    } catch (e) {
      debugPrint('ThemeAnalyzer Error: $e');
      return 'default';
    }
  }

  /// Legacy method - kept for backward compatibility
  @Deprecated('Use getThemeFromContext instead')
  Future<String?> getTheme(String chapterText) async {
    return getThemeFromContext(
      chapterText,
      'Analyze the emotional theme of this text',
    );
  }
}
