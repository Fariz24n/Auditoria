import 'dart:async';
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

// GANTI SELURUH METHOD getThemeFromContext DENGAN INI:
  Future<String?> getThemeFromContext(
    String contextText,
    String query,
  ) async {
    debugPrint('\n${'-' * 60}');
    debugPrint('🤖 [AI] THEME ANALYSIS STARTING');
    debugPrint('-' * 60);

    // Input validation
    if (contextText.trim().isEmpty) {
      debugPrint('🚨 [AI] ❌ Empty context text');
      return 'default';
    }

    // Pertegas Prompt agar AI lebih patuh
    final prompt = '''
Analyze the narrative context provided below and determine the most appropriate emotional theme.

CONTEXT:
$contextText

INSTRUCTIONS:
1. STRICTLY choose ONE theme from: ${_validThemes.join(', ')}.
2. If text is neutral/unclear, choose 'calming'.
3. Return JSON: {"theme": "selected_theme", "confidence": 0.0-1.0}
4. Ignore headers, page numbers, or broken sentences. Focus on emotional keywords.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 12));

      final rawText = response.text;
      if (rawText == null || rawText.isEmpty) return 'default';

      final jsonResult = _safeJsonDecode(rawText);
      
      String? theme = jsonResult['theme'] as String?;
      final confidence = (jsonResult['confidence'] as num?)?.toDouble() ?? 0.0;

      debugPrint('🎯 [AI] Raw Theme: "$theme", Confidence: $confidence');

      // 1. Turunkan Batas Confidence ke 0.4 (Lebih toleran)
      if (confidence < 0.4) {
        debugPrint('⚠️ [AI] Confidence low ($confidence). Using default.');
        return 'default';
      }

      if (theme == null) return 'default';
      
      // 2. Normalisasi & Mapping Manual (Agar tidak kaku)
      String themeLower = theme.toLowerCase();

      // Cek apakah tema ada di daftar valid
      if (!_validThemes.contains(themeLower)) {
        debugPrint('⚠️ [AI] Invalid theme "$themeLower". Trying to map...');
        
        // Logika "Penyelamat": Mapping tema mirip ke tema valid
        if (themeLower.contains('sad') || themeLower.contains('depress')) {
            themeLower = 'melancholic';
          } else if (themeLower.contains('joy') || themeLower.contains('fun')) {
            themeLower = 'happy';
          } else if (themeLower.contains('fear') || 
                    themeLower.contains('scary') || 
                    themeLower.contains('suspense')) {
            themeLower = 'thrill';
          } else if (themeLower.contains('fight') || themeLower.contains('war')) {
            themeLower = 'battle';
          } else if (themeLower.contains('relax')) {
            themeLower = 'calming';
          } else {
           debugPrint('🚨 [AI] ❌ Mapping failed. Fallback to default.');
           return 'default';
        }
        debugPrint('✅ [AI] Mapped to valid theme: "$themeLower"');
      }

      return themeLower;

    } catch (e) {
      debugPrint('🚨 [AI] ❌ Error: $e');
      return 'default';
    }
  }

  Map<String, dynamic> _safeJsonDecode(String? text) {
    if (text == null || text.isEmpty) {
      debugPrint('🚨 [JSON] Null or empty text');
      return {};
    }

    // Remove markdown code blocks if present
    String cleaned = text.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    }
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    // Try direct decode
    try {
      final result = jsonDecode(cleaned);
      debugPrint('✅ [JSON] Successfully parsed');
      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ [JSON] Direct decode failed: $e');
    }

    // Try extracting JSON object
    final match = RegExp(r'\{[^{}]*"theme"[^{}]*\}', dotAll: true).firstMatch(cleaned);
    if (match != null) {
      try {
        final result = jsonDecode(match.group(0)!);
        debugPrint('✅ [JSON] Extracted and parsed JSON object');
        return result as Map<String, dynamic>;
      } catch (e) {
        debugPrint('⚠️ [JSON] Extraction failed: $e');
      }
    }

    debugPrint('🚨 [JSON] ❌ All parsing attempts failed');
    return {};
  }
}