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
    'tense', 
    'battle',
    'melancholic'  // Added to match MoodVector
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
      return _detectThemeFromKeywords(contextText);
    }

    // Pertegas Prompt agar AI lebih patuh
    final prompt = '''
Analyze the narrative context provided below and determine the most appropriate emotional theme.

CONTEXT:
$contextText

INSTRUCTIONS:
1. STRICTLY choose ONE theme from: ${_validThemes.join(', ')}.
2. DO NOT default to 'calming' unless the text is truly peaceful, relaxed, or serene.
3. If there is ANY conflict, danger, fear, or action → choose 'thrill' or 'battle'.
4. If there is violence, weapons, fighting → MUST choose 'battle'.
5. If there is sadness, grief, or melancholy → choose 'melancholic' or 'tense'.
6. Return JSON: {"theme": "selected_theme", "confidence": 0.0-1.0}
7. Be BOLD. Choose extreme emotions if present. Don't play it safe.
8. NEVER choose 'calming' when violence, danger, threat, or conflict exists.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 25));

      final rawText = response.text;
      if (rawText == null || rawText.isEmpty) {
        debugPrint('🚨 [AI] No response from AI, analyzing with keyword detection');
        return _detectThemeFromKeywords(contextText);
      }

      final jsonResult = _safeJsonDecode(rawText);
      
      String? theme = jsonResult['theme'] as String?;
      final confidence = (jsonResult['confidence'] as num?)?.toDouble() ?? 0.0;

      debugPrint('🎯 [AI] AI_RAW_THEME: "$theme", AI_CONFIDENCE: $confidence');

      // LOWERED threshold - trust AI more
      if (confidence < 0.10) {
        debugPrint('⚠️ [AI] Confidence very low ($confidence). Analyzing with keywords.');
        return _detectThemeFromKeywords(contextText);
      }

      if (theme == null) {
        debugPrint('⚠️ [AI] Null theme returned. Analyzing with keywords.');
        return _detectThemeFromKeywords(contextText);
      }
      
      // Normalisasi & Mapping Manual
      String themeLower = theme.toLowerCase();

      // Cek apakah tema ada di daftar valid
      if (!_validThemes.contains(themeLower)) {
        debugPrint('⚠️ [AI] Invalid theme "$themeLower". Trying to map...');
        
        // Mapping tema mirip ke tema valid
        if (themeLower.contains('sad') || themeLower.contains('depress') || themeLower.contains('grief')) {
            themeLower = 'melancholic';
          } else if (themeLower.contains('joy') || themeLower.contains('fun') || themeLower.contains('cheer')) {
            themeLower = 'happy';
          } else if (themeLower.contains('fear') || 
                    themeLower.contains('scary') || 
                    themeLower.contains('suspense') ||
                    themeLower.contains('danger')) {
            themeLower = 'thrill';
          } else if (themeLower.contains('fight') || themeLower.contains('war') || themeLower.contains('combat')) {
            themeLower = 'battle';
          } else if (themeLower.contains('anxious') || themeLower.contains('stress')) {
            themeLower = 'tense';
          } else if (themeLower.contains('relax') || themeLower.contains('peace')) {
            themeLower = 'calming';
          } else {
           debugPrint('🚨 [AI] Mapping failed. Analyzing with keywords.');
           return _detectThemeFromKeywords(contextText);
        }
        debugPrint('✅ [AI] POST_MAPPING_THEME: "$themeLower"');
      }

      return themeLower;

    } catch (e) {
      debugPrint('🚨 [AI] ❌ Exception: $e. Analyzing with keywords.');
      return _detectThemeFromKeywords(contextText);
    }
  }
  
  /// Keyword-based theme detection as intelligent fallback
  /// NEVER defaults to calming - analyzes actual content
  String _detectThemeFromKeywords(String text) {
    final lower = text.toLowerCase();
    
    // HARD KEYWORD OVERRIDE (HIGHEST PRIORITY - SANITY CHECK)
    // These MUST trigger battle/thrill immediately
    final extremeConflict = ['fight', 'blood', 'attack', 'weapon', 'kill', 'combat', 'strike', 'sword', 'explosion', 'gunfire'];
    final extremeFear = ['scream', 'terror', 'horror', 'panic', 'danger'];
    
    for (final keyword in extremeConflict) {
      if (lower.contains(keyword)) {
        debugPrint('🔥 [HARD OVERRIDE] EXTREME CONFLICT DETECTED: "$keyword" → BATTLE');
        return 'battle';
      }
    }
    
    for (final keyword in extremeFear) {
      if (lower.contains(keyword)) {
        debugPrint('🔥 [HARD OVERRIDE] EXTREME FEAR DETECTED: "$keyword" → THRILL');
        return 'thrill';
      }
    }
    
    // EMOTION ZONE DETECTION: Novel-style narrative cues
    final positiveKeywords = ['warmth','smile','laughed','laughter','gentle','together','close','familiar','shared','safe'];
    final positiveCount = positiveKeywords.where((k) => lower.contains(k)).length;

    final negativeKeywords = ['darkness','threat','danger','blood','fear','shadowed','loomed','closed in','trapped','cornered'];
    final negativeCount = negativeKeywords.where((k) => lower.contains(k)).length;

    // Battle indicators (descriptive action)
    final battleKeywords = ['blade','steel','strike','thrust','slash','clash','wound','blood','charge','retreat'];
    final battleCount = battleKeywords.where((k) => lower.contains(k)).length;

    // Thrill / Fear indicators (loss of control, fast tempo)
    final thrillKeywords = ['sudden','burst','crash','slam','chase','fled','panic','no time','heart raced','breath hitched'];
    final thrillCount = thrillKeywords.where((k) => lower.contains(k)).length;

    // Tense / Anticipation indicators (waiting, hesitation)
    final tenseKeywords = ['paused','waited','hesitated','listened','footsteps','knock','creak','held breath','watched','uncertain'];
    final tenseCount = tenseKeywords.where((k) => lower.contains(k)).length;

    // Melancholic indicators (quiet loss)
    final melancholicKeywords = ['empty','silent room','alone','left behind','memory','faded','echo','absence','regret','lingered'];
    final melancholicCount = melancholicKeywords.where((k) => lower.contains(k)).length;

    // Happy / Light indicators (soft positivity)
    final happyKeywords = ['laughed softly','smiled','light','bright','relief','comfort','ease','content','peaceful','warm'];
    final happyCount = happyKeywords.where((k) => lower.contains(k)).length;

    // Calming indicators (environment & slow tempo)
    final calmingKeywords = ['breeze','dusk','dawn','twilight','moonlight','still','silence','river','shore','settled'];
    final calmingCount = calmingKeywords.where((k) => lower.contains(k)).length;

    
    debugPrint('📊 [KEYWORD] battle=$battleCount, thrill=$thrillCount, tense=$tenseCount, melancholic=$melancholicCount, happy=$happyCount, calming=$calmingCount');
    debugPrint('📊 [ZONE] positive=$positiveCount, negative=$negativeCount');
    
    // ZONE GUARD: If positive context is dominant, reject battle/thrill
    final isPositiveContext = positiveCount > negativeCount;
    final isNegativeContext = negativeCount > positiveCount;
    
    // Priority order: extreme emotions first (WITH ZONE GUARDS)
    if (battleCount >= 2 && !isPositiveContext) {
      debugPrint('✅ [KEYWORD] DETECTED: battle (zone safe)');
      return 'battle';
    }
    if (thrillCount >= 2 && isNegativeContext) {
      debugPrint('✅ [KEYWORD] DETECTED: thrill (zone safe)');
      return 'thrill';
    }
    if (tenseCount >= 2) {
      debugPrint('✅ [KEYWORD] DETECTED: tense');
      return 'tense';
    }
    if (melancholicCount >= 2) {
      debugPrint('✅ [KEYWORD] DETECTED: melancholic');
      return 'melancholic';
    }
    if (happyCount >= 2) {
      debugPrint('✅ [KEYWORD] DETECTED: happy');
      return 'happy';
    }
    if (calmingCount >= 2) {
      debugPrint('✅ [KEYWORD] DETECTED: calming');
      return 'calming';
    }
    
    // Single keyword detection (lower threshold, WITH ZONE GUARDS)
    if (battleCount >= 1 && !isPositiveContext) return 'battle';
    if (thrillCount >= 1 && isNegativeContext) return 'thrill';
    if (melancholicCount >= 1) return 'melancholic';
    if (tenseCount >= 1) return 'tense';
    if (happyCount >= 1) return 'happy';
    if (calmingCount >= 1) return 'calming';
    
    // LAST RESORT: NO CALMING FALLBACK
    // If we reach here, text is truly neutral/ambiguous
    // Return tense as it represents uncertainty better than false calm
    debugPrint('⚠️ [KEYWORD] No clear emotional indicators. Using tense (neutral uncertainty)');
    throw Exception('ThemeAnalyzer: No clear theme detected in text. Text may be too short or neutral.');
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