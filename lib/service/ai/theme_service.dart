import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

class ThemeAnalyzer {
  late final GenerativeModel _model;

  // Daftar tema yang dikenali oleh MusicService & UI Anda
  static const List<String> _validThemes = [
    'happy', 
    'calming', 
    'thrill', 
    'melancholic', 
    'battle'
  ];

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

  Future<String?> getThemeFromContext(
    String contextText,
    String query,
  ) async {
    if (contextText.trim().isEmpty) return 'default';

    // 🔥 FIX 2: Pertegas Prompt dengan Daftar Tema Valid
    final prompt = '''
    Analyze the narrative context provided below and determine the most appropriate emotional theme/atmosphere.
    
    CONTEXT:
    $contextText
    
    INSTRUCTIONS:
    1. You must choose ONE theme strictly from this list: ${_validThemes.join(', ')}.
    2. If the text is neutral or unclear, choose 'calming'.
    3. Return JSON format: {"theme": "selected_theme", "confidence": 0.0-1.0}
    4. Confidence Score Guide:
       - 0.9: Explicit keywords (e.g., "tears", "blood", "laugh").
       - 0.6: Implied atmosphere.
    ''';

    try {
      debugPrint("ThemeAnalyzer: Sending to Gemini..."); // Debug Log
      final response = await _model.generateContent([Content.text(prompt)]);
      
      debugPrint("ThemeAnalyzer Raw Response: ${response.text}"); // 🔥 WAJIB LIHAT INI DI LOG

      final jsonResult = _safeJsonDecode(response.text);
      
      final theme = jsonResult['theme'] as String?;
      final confidence = (jsonResult['confidence'] as num?)?.toDouble() ?? 0.0;

      // 🔥 FIX 1: Turunkan Threshold Confidence ke 0.5 atau 0.6
      // Lebih baik musik main (meski agak meleset) daripada 'default' terus.
      if (confidence < 0.5) { 
        debugPrint("ThemeAnalyzer: Confidence too low ($confidence). Using default.");
        return 'default';
      }

      if (theme == null || !_validThemes.contains(theme.toLowerCase())) {
        debugPrint("ThemeAnalyzer: Invalid theme '$theme'. Using default.");
        return 'default';
      }

      return theme.toLowerCase();

    } catch (e) {
      debugPrint('ThemeAnalyzer Error: $e');
      return 'default';
    }
  }

  Map<String, dynamic> _safeJsonDecode(String? text) {
    if (text == null) return {};
    try {
      return jsonDecode(text);
    } catch (_) {
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
}