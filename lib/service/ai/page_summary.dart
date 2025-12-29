import 'mood_vector.dart';

/// Compact representation of a previously-read page
/// Used for building local context in subsequent analyses
class PageSummary {
  final int pageNumber;
  final String summary;        // 80-120 chars max
  final MoodVector mood;
  final DateTime readAt;

  const PageSummary({
    required this.pageNumber,
    required this.summary,
    required this.mood,
    required this.readAt,
  });

  /// Create a basic summary from raw text (placeholder for now)
  /// In Phase 3, this will call Gemini for proper summarization
  factory PageSummary.fromText(
    String pageText,
    int pageNumber,
    MoodVector mood,
  ) {
    // For now, just take first 100 chars as "summary"
    // This will be replaced with Gemini-based summarization in Phase 3
    final cleanedText = pageText
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    final summary = cleanedText.length > 100
        ? '${cleanedText.substring(0, 97)}...'
        : cleanedText;

    return PageSummary(
      pageNumber: pageNumber,
      summary: summary,
      mood: mood,
      readAt: DateTime.now(),
    );
  }

  @override
  String toString() => 'Page $pageNumber: $summary';
}
