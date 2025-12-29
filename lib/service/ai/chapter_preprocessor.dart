import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'chapter_emotion_map.dart';

/// Service for one-time chapter-level emotional analysis
/// Produces an emotional map that provides global context for page-level analysis
class ChapterPreprocessor {
  late final GenerativeModel _model;

  ChapterPreprocessor() {
    debugPrint('\n🔧 [ChapterPreprocessor] Initializing...');
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    debugPrint('🔑 [ChapterPreprocessor] API Key loaded: ${apiKey != null && apiKey.isNotEmpty ? 'YES' : 'NO'}');
    
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
    debugPrint('✅ [ChapterPreprocessor] GenerativeModel initialized');
  }

  /// Analyze a full chapter and produce emotional map
  /// 
  /// This is expensive (full chapter text to Gemini) but only runs once per chapter
  /// Results are cached in database
  Future<ChapterEmotionMapData> analyzeChapter({
    required String chapterText,
    required String chapterId,
    required int totalPages,
  }) async {
    debugPrint('\n🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟');
    debugPrint('🤖 [ChapterPreprocessor.analyzeChapter] STARTED');
    debugPrint('🤖 [ChapterPreprocessor] Chapter ID: $chapterId');
    debugPrint('🤖 [ChapterPreprocessor] Total Pages: $totalPages');
    debugPrint('🤖 [ChapterPreprocessor] Text Length: ${chapterText.length} characters');
    debugPrint('🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟 🌟\n');

    try {
      debugPrint('🤖 [ChapterPreprocessor] Building prompt...');
      final prompt = _buildChapterAnalysisPrompt(
        chapterText,
        totalPages,
      );
      debugPrint('🤖 [ChapterPreprocessor] Prompt ready (${prompt.length} chars)');

      debugPrint('🤖 [ChapterPreprocessor] ⏳ Calling Gemini API with 45s timeout...');
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 45));

      debugPrint('🤖 [ChapterPreprocessor] ✅ Gemini response received');
      
      final rawText = response.text;
      if (rawText == null || rawText.isEmpty) {
        throw Exception('Empty response from Gemini');
      }

      debugPrint('🤖 [ChapterPreprocessor] Parsing JSON response...');
      final jsonResult = _safeJsonDecode(rawText);
      
      debugPrint('🤖 [ChapterPreprocessor] Creating emotion map from JSON...');
      final emotionMap = _parseEmotionMap(jsonResult, chapterId);

      debugPrint('🤖 [ChapterPreprocessor] ✅ ✅ ✅ ANALYSIS COMPLETE');
      debugPrint('🤖 [ChapterPreprocessor] Summary: ${emotionMap.chapterSummary}');
      debugPrint('🤖 [ChapterPreprocessor] Segments: ${emotionMap.segments.length}');
      debugPrint('🤖 [ChapterPreprocessor] Narrative Arc: ${emotionMap.narrativeArc}\n');

      return emotionMap;
    } catch (e, stackTrace) {
      debugPrint('\n🤖 [ChapterPreprocessor] ❌ ❌ ❌ ANALYSIS FAILED');
      debugPrint('🤖 [ChapterPreprocessor] Exception: $e');
      debugPrint('🤖 [ChapterPreprocessor] Stack trace:');
      debugPrint('$stackTrace\n');
      
      debugPrint('🤖 [ChapterPreprocessor] Creating FALLBACK emotion map...');
      // Return fallback emotion map
      return _createFallbackMap(chapterId, totalPages);
    }
  }

  /// Build Gemini prompt for chapter analysis
  String _buildChapterAnalysisPrompt(String chapterText, int totalPages) {
    return '''
You are an expert literary analyst. Analyze this full chapter and create an emotional roadmap.

CHAPTER TEXT:
$chapterText

TOTAL PAGES IN CHAPTER: $totalPages

TASK:
Create an emotional map of this chapter by dividing it into 3-5 narrative segments.

OUTPUT JSON FORMAT:
{
  "chapter_summary": "<150-250 char summary of key plot points and themes>",
  "narrative_arc": "<rising_tension|climax|falling_action|resolution|exposition>",
  "overall_emotional_tone": "<one phrase like 'melancholic_with_hope' or 'triumphant'>",
  "segments": [
    {
      "page_range": [1, 8],
      "dominant_mood": "<one-word emotional tone>",
      "intensity": <0.0-1.0>,
      "key_events": "<brief description of what happens>",
      "emotional_shift": "<describe mood change within segment>"
    }
  ]
}

GUIDELINES:
- Divide chapter into 3-5 segments of roughly equal length
- Use natural mood descriptors: "hopeful", "tense", "melancholic", "triumphant", "uncertain"
- Intensity: 0.0-0.3=subtle, 0.4-0.6=moderate, 0.7-1.0=strong
- Focus on emotional progression, not just events
- Keep descriptions concise but meaningful
''';
  }

  /// Parse Gemini response into ChapterEmotionMapData
  ChapterEmotionMapData _parseEmotionMap(
    Map<String, dynamic> json,
    String chapterId,
  ) {
    final segments = <EmotionSegment>[];
    final segmentsList = json['segments'] as List?;

    if (segmentsList != null) {
      for (final segmentJson in segmentsList) {
        final segment = segmentJson as Map<String, dynamic>;
        final pageRange = segment['page_range'] as List;

        segments.add(EmotionSegment(
          startPage: pageRange[0] as int,
          endPage: pageRange[1] as int,
          dominantMood: segment['dominant_mood'] as String? ?? 'neutral',
          intensity: (segment['intensity'] as num?)?.toDouble() ?? 0.5,
          keyEvents: segment['key_events'] as String? ?? '',
          emotionalShift: segment['emotional_shift'] as String? ?? '',
        ));
      }
    }

    return ChapterEmotionMapData(
      chapterId: chapterId,
      chapterSummary: json['chapter_summary'] as String? ?? 'No summary available',
      narrativeArc: json['narrative_arc'] as String? ?? 'unknown',
      overallTone: json['overall_emotional_tone'] as String? ?? 'neutral',
      segments: segments,
      analyzedAt: DateTime.now(),
    );
  }

  /// Create fallback map when analysis fails
  ChapterEmotionMapData _createFallbackMap(String chapterId, int totalPages) {
    return ChapterEmotionMapData(
      chapterId: chapterId,
      chapterSummary: 'Chapter analysis unavailable',
      narrativeArc: 'unknown',
      overallTone: 'neutral',
      segments: [
        EmotionSegment(
          startPage: 1,
          endPage: totalPages,
          dominantMood: 'neutral',
          intensity: 0.5,
          keyEvents: 'Unable to analyze chapter',
          emotionalShift: 'none',
        ),
      ],
      analyzedAt: DateTime.now(),
    );
  }

  /// Safe JSON decoding with fallbacks
  Map<String, dynamic> _safeJsonDecode(String text) {
    String cleaned = text.trim();

    // Remove markdown code blocks
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

    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ [ChapterPreprocessor] JSON decode failed: $e');
      return {};
    }
  }
}
