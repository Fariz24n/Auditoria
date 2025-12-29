import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../service/ai/theme_service.dart';
import '../service/music_service.dart';
import '../service/ai/ai_activation.dart';
import '../service/ai/mood_vector.dart';
import '../service/ai/page_summary.dart';
import '../service/ai/chapter_emotion_map.dart';
import '../service/ai/chapter_preprocessor.dart';
import '../service/database_instance.dart';

/// Phase 1 + Phase 2 Reading State Manager
/// - Phase 1: Mood smoothing & rolling context
/// - Phase 2: Chapter-aware emotional context
class ReadingStateManager {
  final ThemeAnalyzer _analyzer = ThemeAnalyzer();
  final MusicService _musicService;
  final ChapterPreprocessor _preprocessor = ChapterPreprocessor();

  // ====== STATE ======
  bool _isAnalyzing = false;

  static const int _maxRecentPages = 3;
  final Queue<PageSummary> _recentPages = Queue();

  static const int _maxMoodHistory = 5;
  final Queue<MoodVector> _moodHistory = Queue();

  // ====== CHAPTER CONTEXT ======
  ChapterEmotionMapData? _currentChapterMap;
  String? _lastChapterId;

  final _themeController = StreamController<String>.broadcast();
  Stream<String> get onThemeChanged => _themeController.stream;

  MusicService get musicService => _musicService;
  bool get isAnalyzing => _isAnalyzing;

  StreamSubscription<bool>? _activationSub;
  Timer? _themeDebounce;

  ReadingStateManager(this._musicService) {
    onThemeChanged.listen(_musicService.setPlaylistByTheme);

    _activationSub =
        AiActivationService.instance.onActivationChanged.listen((active) {
      if (!active) return;
    });
  }

  // ================================================================
  // PHASE 1 HELPERS
  // ================================================================

  void _addPageToHistory(PageSummary summary) {
    _recentPages.add(summary);
    while (_recentPages.length > _maxRecentPages) {
      _recentPages.removeFirst();
    }
  }

  void _addMoodToHistory(MoodVector mood) {
    _moodHistory.add(mood);
    while (_moodHistory.length > _maxMoodHistory) {
      _moodHistory.removeFirst();
    }
  }

  String _buildLocalContext() {
    if (_recentPages.isEmpty) return '';
    final buffer = StringBuffer('RECENT PAGES:\n');
    for (final page in _recentPages) {
      buffer.writeln(page.toString());
    }
    return buffer.toString();
  }

  // ================================================================
  // PHASE 2 — CHAPTER CONTEXT (FIXED)
  // ================================================================

  int _toChapterRelativePage(int absolutePage) {
    final chapterIndex = _extractChapterIndex(absolutePage);
    final chapterStart = (chapterIndex - 1) * 10 + 1;
    return (absolutePage - chapterStart) + 1;
  }

  Future<void> _ensureChapterContext(String pdfPath, int currentPage) async {
    final chapterId = _generateChapterId(pdfPath, currentPage);

    if (chapterId == _lastChapterId &&
        _currentChapterMap != null &&
        _currentChapterMap!.isValid()) {
      return;
    }

    _lastChapterId = chapterId;

    final cached = await db.getChapterEmotionMap(chapterId);
    if (cached != null) {
      try {
        final map =
            ChapterEmotionMapData.fromJsonString(cached.emotionMapJson);
        if (map.isValid()) {
          _currentChapterMap = map;
          return;
        }
      } catch (_) {
        debugPrint('📖 Cache corrupted, reanalyzing...');
      }
    }

    final chapterText = await _extractChapterText(pdfPath, currentPage);
    if (chapterText.length < 100) return;

    _currentChapterMap = await _preprocessor.analyzeChapter(
      chapterText: chapterText,
      chapterId: chapterId,
      totalPages: 10, // Phase 2 limitation
    );

    await db.saveChapterEmotionMap(
      chapterId,
      _extractBookIdFromPath(pdfPath),
      _extractChapterIndex(currentPage),
      _currentChapterMap!.toJsonString(),
    );
  }

  String _buildEnrichedContext(String currentPageText, int pageNumber) {
    final buffer = StringBuffer();

    if (_currentChapterMap != null && _currentChapterMap!.isValid()) {
      buffer.writeln('CHAPTER CONTEXT:');
      buffer.writeln(_currentChapterMap!.chapterSummary);

      final relativePage = _toChapterRelativePage(pageNumber);
      final segment =
          _currentChapterMap!.findSegmentForPage(relativePage);

      if (segment != null) {
        final sceneMood = (segment.dominantMood.isNotEmpty
            ? segment.dominantMood
            : (_currentChapterMap?.overallTone ?? 'neutral'));
        buffer.writeln('\nCURRENT SCENE MOOD: $sceneMood');
        buffer.writeln('KEY EVENTS: ${segment.keyEvents}');
      }
      buffer.writeln('');
    }

    final localContext = _buildLocalContext();
    if (localContext.isNotEmpty) {
      buffer.writeln(localContext);
      buffer.writeln('');
    }

    buffer.writeln('CURRENT PAGE:');
    buffer.writeln(currentPageText);

    return buffer.toString();
  }

  // ================================================================
  // MAIN ORCHESTRATOR (CLEAN)
  // ================================================================

  Future<void> analyzeCurrentPages(String pdfPath, int currentPage) async {
    if (_isAnalyzing) return;
    _isAnalyzing = true;

    try {
      // Clear recent pages to ensure fresh analysis of current page only
      _recentPages.clear();
      
      await _ensureChapterContext(pdfPath, currentPage);
      final rawText = await compute(_extractPagesText, {
        'path': pdfPath,
        'startPage': currentPage,
        'endPage': currentPage,
      });

      if (rawText.isEmpty) return;

      // GUARD: Ensure page text is substantial enough for meaningful analysis
      if (rawText.trim().length < 200) {
        debugPrint("⚠️ [READER] Page text too short (${rawText.trim().length} chars) — skipping AI analysis");
        return;
      }

      debugPrint("=== AI INPUT PAGE TEXT ===");
      debugPrint("TEXT LENGTH: ${rawText.length} characters");
      debugPrint("FIRST 500 CHARS: ${rawText.substring(0, rawText.length > 500 ? 500 : rawText.length)}");
      debugPrint("========================");

      final context =
          _buildEnrichedContext(rawText, currentPage);

      final themeString = await _analyzer.getThemeFromContext(
        context,
        'Analyze emotional tone',
      );
      
      debugPrint('🎯 [READER] AI_RAW_THEME: "$themeString"');

      // Handle exception case where no clear theme detected
      final rawMood = themeString != null 
          ? MoodVector.fromTheme(themeString, currentPage)
          : MoodVector.fromTheme('tense', currentPage);
      
      debugPrint('📊 [READER] POST_MAPPING (raw mood): ${rawMood.primaryMood} [v=${rawMood.valence.toStringAsFixed(2)}, a=${rawMood.arousal.toStringAsFixed(2)}, t=${rawMood.tension.toStringAsFixed(2)}]');

      final smoothedMood = _moodHistory.isEmpty
          ? rawMood
          : MoodVector.smooth(
              rawMood,
              _moodHistory.toList(),
              alpha: 0.4,
            );
      
      debugPrint('📊 [READER] POST_SMOOTHING: ${smoothedMood.primaryMood} [v=${smoothedMood.valence.toStringAsFixed(2)}, a=${smoothedMood.arousal.toStringAsFixed(2)}, t=${smoothedMood.tension.toStringAsFixed(2)}]');

      _addMoodToHistory(smoothedMood);

      final pageSummary = PageSummary.fromText(
        rawText,
        currentPage,
        smoothedMood,
      );
      _addPageToHistory(pageSummary);

      final finalTheme = smoothedMood.toMusicTheme();
      debugPrint('🎵 [READER] FINAL_MUSIC_THEME: "$finalTheme"');
      debugPrint('${'-' * 60}\n');
      
      _emitTheme(finalTheme);
      AiActivationService.instance.setActive(false);
    } finally {
      _isAnalyzing = false;
    }
  }

  // ================================================================
  // HELPERS
  // ================================================================

  String _generateChapterId(String pdfPath, int pageNumber) {
    final bookId = _extractBookIdFromPath(pdfPath);
    final chapterIndex = _extractChapterIndex(pageNumber);
    return 'book_${bookId}_chapter_$chapterIndex';
  }

  int _extractBookIdFromPath(String path) =>
      path.hashCode.abs() % 100000;

  int _extractChapterIndex(int pageNumber) =>
      (pageNumber / 10).floor() + 1;

  Future<String> _extractChapterText(
      String pdfPath, int currentPage) async {
    final startPage = (currentPage - 5).clamp(1, currentPage);
    final endPage = currentPage + 5;

    return compute(_extractPagesText, {
      'path': pdfPath,
      'startPage': startPage,
      'endPage': endPage,
    });
  }

  static Future<String> _extractPagesText(
      Map<String, dynamic> params) async {
    try {
      final bytes = await File(params['path']).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);

      final buffer = StringBuffer();
      final totalPages = doc.pages.count;

      for (int i = params['startPage'] - 1;
          i < params['endPage'] && i < totalPages;
          i++) {
        buffer.writeln(
          PdfTextExtractor(doc)
              .extractText(startPageIndex: i, endPageIndex: i),
        );
        buffer.writeln('\n--- Page Break ---\n');
      }

      doc.dispose();
      return buffer.toString();
    } catch (e) {
      debugPrint('PDF extraction error: $e');
      return '';
    }
  }

  void _emitTheme(String theme) {
    _themeDebounce?.cancel();
    _themeDebounce =
        Timer(const Duration(milliseconds: 250), () {
      _themeController.add(theme);
    });
  }

  void stopMusic() => _musicService.stop();

  void dispose() {
    _activationSub?.cancel();
    _themeDebounce?.cancel();
    _themeController.close();
    _musicService.stop();
    _recentPages.clear();
    _moodHistory.clear();
  }
}
