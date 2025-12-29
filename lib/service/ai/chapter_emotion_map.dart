 import 'dart:convert';

  /// Represents an emotional segment within a chapter
  class EmotionSegment {
    final int startPage;
    final int endPage;
    final String dominantMood;      // e.g., "hopeful", "tense", "triumphant"
    final double intensity;         // 0.0-1.0
    final String keyEvents;         // Brief description of what happens
    final String emotionalShift;    // e.g., "curious → anxious"

    const EmotionSegment({
      required this.startPage,
      required this.endPage,
      required this.dominantMood,
      required this.intensity,
      required this.keyEvents,
      required this.emotionalShift,
    });

    Map<String, dynamic> toJson() => {
          'startPage': startPage,
          'endPage': endPage,
          'dominantMood': dominantMood,
          'intensity': intensity,
          'keyEvents': keyEvents,
          'emotionalShift': emotionalShift,
        };

    factory EmotionSegment.fromJson(Map<String, dynamic> json) => EmotionSegment(
          startPage: json['startPage'] as int,
          endPage: json['endPage'] as int,
          dominantMood: json['dominantMood'] as String,
          intensity: (json['intensity'] as num).toDouble(),
          keyEvents: json['keyEvents'] as String,
          emotionalShift: json['emotionalShift'] as String,
        );
  }

  /// Chapter-level emotional structure
  /// Provides global context that persists across pages
  class ChapterEmotionMapData {
    final String chapterId;           // "book_123_chapter_5"
    final String chapterSummary;      // 150-250 char narrative summary
    final String narrativeArc;        // "rising_tension", "climax", "resolution"
    final String overallTone;         // "melancholic_with_hope", "triumphant"
    final List<EmotionSegment> segments;
    final DateTime analyzedAt;

    const ChapterEmotionMapData({
      required this.chapterId,
      required this.chapterSummary,
      required this.narrativeArc,
      required this.overallTone,
      required this.segments,
      required this.analyzedAt,
    });

    /// Find the segment that contains a specific page
    EmotionSegment? findSegmentForPage(int pageNumber) {
      for (final segment in segments) {
        if (pageNumber >= segment.startPage && pageNumber <= segment.endPage) {
          return segment;
        }
      }
      return null;
    }

    /// Check if this map is still valid (not too old)
    bool isValid({Duration maxAge = const Duration(days: 30)}) {
      return DateTime.now().difference(analyzedAt) < maxAge;
    }

    Map<String, dynamic> toJson() => {
          'chapterId': chapterId,
          'chapterSummary': chapterSummary,
          'narrativeArc': narrativeArc,
          'overallTone': overallTone,
          'segments': segments.map((s) => s.toJson()).toList(),
          'analyzedAt': analyzedAt.millisecondsSinceEpoch,
        };

    factory ChapterEmotionMapData.fromJson(Map<String, dynamic> json) =>
        ChapterEmotionMapData(
          chapterId: json['chapterId'] as String,
          chapterSummary: json['chapterSummary'] as String,
          narrativeArc: json['narrativeArc'] as String,
          overallTone: json['overallTone'] as String,
          segments: (json['segments'] as List)
              .map((s) => EmotionSegment.fromJson(s as Map<String, dynamic>))
              .toList(),
          analyzedAt: DateTime.fromMillisecondsSinceEpoch(
            json['analyzedAt'] as int,
          ),
        );

    /// Serialize to string for database storage
    String toJsonString() => jsonEncode(toJson());

    /// Deserialize from database string
    factory ChapterEmotionMapData.fromJsonString(String jsonString) =>
        ChapterEmotionMapData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }


