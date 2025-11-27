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
/// Analyze theme using RAG-retrieved context (grounded generation)
  Future<String?> getThemeFromContext(
    String contextText,
    String query,
  ) async {
    if (contextText.trim().isEmpty) return 'default';

    final prompt = '''
Your task is to analyze the emotional or narrative theme based STRICTLY on the following context only.
QUERY: $query
CONTEXT:
$contextText
INSTRUCTIONS:
1. Return JSON format: {"theme": "theme_name", "confidence": 0.0-1.0}
(Rest of instructions implied...)
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      // 🔥 FIX 1: Gunakan Safe JSON Parsing
      final jsonResult = _safeJsonDecode(response.text);
      
      final theme = jsonResult['theme'] as String?;
      final confidence = (jsonResult['confidence'] as num?)?.toDouble() ?? 0.0;

      if (confidence < 0.8 || theme == null || theme.isEmpty) {
        return 'default';
      }
      return theme;
    } catch (e) {
      debugPrint('ThemeAnalyzer Error: $e');
      return 'default';
    }
  }

  // 🔥 SISIPKAN DI BAGIAN PALING BAWAH CLASS (Sebelum penutup kurawal '}')
  Map<String, dynamic> _safeJsonDecode(String? text) {
    if (text == null) return {};
    try {
      // Coba decode langsung
      return jsonDecode(text);
    } catch (_) {
      // Fallback: Cari pola JSON object {...}
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (match != null) {
        try {
          return jsonDecode(match.group(0)!);
        } catch (e) {
          return {}; 
        }
      }
      return {};
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
