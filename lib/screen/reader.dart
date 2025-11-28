// lib/screen/reader.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../service/ai/chapter_parser.dart';
import '../service/ai/theme_service.dart';
import '../service/ai/vector_database_service.dart';
import '../service/music_service.dart';
import '../service/ai/ai_activation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ReadingSessionManager {
  final ThemeAnalyzer _analyzer = ThemeAnalyzer();
  final MusicService _musicService;
  final VectorDatabaseService _vectorService = VectorDatabaseService();

  // ====== NEW STATE ======
  bool isReady = false;             // Apakah indexing sudah selesai
  int lastAnalyzedPage = -1;        // Halaman terakhir yang sudah dianalisis AI
  int anchorPage = 0;               // Anchor window
  int windowSize = 2;               // ±2 page relevansi
  bool _aiBusy = false;             // Lock concurrency
  Timer? _readerDebounce;           // Debounce di reader-level

  String? _currentDocumentId;
  int _currentPageIndex = 0;
  String? _currentTheme;

  final _themeController = StreamController<String>.broadcast();
  Stream<String> get onThemeChanged => _themeController.stream;

  MusicService get musicService => _musicService;

  bool get hasChapters =>
      _currentDocumentId != null &&
      _vectorService.isDocumentIndexed(_currentDocumentId!);

  StreamSubscription<bool>? _activationSub;

  ReadingSessionManager(this._musicService) {
    _vectorService.initialize();

    // Listener: AI theme → ganti musik
    onThemeChanged.listen((theme) {
      if (AiActivationService.instance.isActive) {
        _musicService.setPlaylistByTheme(theme);
      }
    });

    // Listener: AI on/off
    _activationSub =
        AiActivationService.instance.onActivationChanged.listen((active) {
      if (!active) {
        _musicService.stop();
        return;
      }
      if (isReady) {
        analyzeAtPosition(_currentPageIndex);
      }
    });
  }

  // ================================================================
  // START SESSION — INDEX PDF ONCE (NON-BLOCKING)
  // ================================================================
  Future<void> startSession(String pdfPath) async {
    if (isReady) return;

    _currentTheme = 'default';
    _themeController.add('default');

    _currentDocumentId = pdfPath.hashCode.toString();

    // Mark as ready immediately so UI doesn't freeze
    isReady = true;
    anchorPage = 1;
    lastAnalyzedPage = -1;

    // Index in background without blocking
    if (!_vectorService.isDocumentIndexed(_currentDocumentId!)) {
      _indexPdf(pdfPath).then((_) {
        log('Background indexing complete');
        if (AiActivationService.instance.isActive) {
          analyzeAtPosition(_currentPageIndex);
        }
      }).catchError((e) {
        log('Indexing failed: $e');
        _emitTheme('error');
      });
    } else if (AiActivationService.instance.isActive) {
      analyzeAtPosition(_currentPageIndex);
    }
  }

  // ================================================================
  // PDF TEXT EXTRACTION
  // ================================================================
  static Future<String> _extractPdfText(String path) async {
    final bytes = await File(path).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(doc).extractText();
    doc.dispose();
    return text;
  }

  // ================================================================
  // INDEX PDF — COMPLETELY NON-BLOCKING
  // ================================================================
  Future<void> _indexPdf(String pdfPath) {
    log('Starting background indexing...');
    
    // Extract text in isolate, then process WITHOUT blocking
    return compute(_extractPdfText, pdfPath).then((fullText) {
      final chapters = ChapterParser.detectChapters(fullText);
      
      // Process all chapters sequentially but non-blocking
      return _indexChaptersSequentially(chapters, fullText, 0);
    });
  }

  // Helper: Index chapters one by one without blocking
  Future<void> _indexChaptersSequentially(
    List<Map<String, int>> chapters,
    String fullText,
    int chapterIdx,
  ) {
    if (chapterIdx >= chapters.length) {
      log('Background indexing complete');
      return Future.value();
    }

    final c = chapters[chapterIdx];
    final segment = fullText.substring(c['start']!, c['end']!);
    
    if (segment.trim().length < 40) {
      return _indexChaptersSequentially(chapters, fullText, chapterIdx + 1);
    }

    final chunks = ChapterParser.chunkTextForRAG(
      segment,
      chapterIndex: chapterIdx,
    );

    if (chunks.isEmpty) {
      return _indexChaptersSequentially(chapters, fullText, chapterIdx + 1);
    }

    // Index this batch, then move to next chapter
    return _vectorService.indexDocumentBatch(
      _currentDocumentId!,
      chunks,
    ).then((_) {
      return _indexChaptersSequentially(chapters, fullText, chapterIdx + 1);
    }).catchError((e) {
      log('Chapter $chapterIdx indexing failed: $e');
      // Continue with next chapter even if one fails
      return _indexChaptersSequentially(chapters, fullText, chapterIdx + 1);
    });
  }

  // ================================================================
  // SMART READING POSITION API
  // Called from UI (debounced on UI layer)
  // ================================================================
  void onReadingPositionChanged(int page) {
    if (!isReady) return;
    if (!AiActivationService.instance.isActive) return;

    _currentPageIndex = page;

    // Reader-level debounce 500ms
    _readerDebounce?.cancel();
    _readerDebounce = Timer(const Duration(milliseconds: 500), () {
      analyzeAtPosition(page);
    });
  }

  // ================================================================
  // CORE AI-TRIGGER LOGIC (NON-BLOCKING WITH TIMEOUT)
  // ================================================================
  Future<void> analyzeAtPosition(int page) async {
    if (!isReady) return;

    // 1) Window check
    if ((page - anchorPage).abs() <= windowSize) {
      return;
    }

    // 2) Prevent spam if same page
    if (page == lastAnalyzedPage) return;

    // 3) Concurrency lock
    if (_aiBusy) return;
    _aiBusy = true;

    try {
      lastAnalyzedPage = page;

      // Check if document is actually indexed
      if (!_vectorService.isDocumentIndexed(_currentDocumentId!)) {
        log('Document not yet indexed, using default theme');
        _emitTheme('default');
        anchorPage = page;
        return;
      }

      final query =
          'Determine the emotional or narrative theme for this segment near page $page';

      // Add timeout to prevent infinite waiting
      final chunks = await _vectorService.retrieveRelevantContext(
        query,
        topK: 5,
        documentId: _currentDocumentId,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          log('Retrieval timeout');
          return [];
        },
      );

      if (chunks.isEmpty) {
        _emitTheme('default');
        anchorPage = page;
        return;
      }

      final contextText =
          chunks.map((c) => c['content']).join('\n\n');

      // Add timeout for theme analysis
      final theme = await _analyzer.getThemeFromContext(
        contextText,
        query,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          log('Theme analysis timeout');
          return 'default';
        },
      );

      final finalTheme = theme ?? 'default';

      if (finalTheme != _currentTheme) {
        _currentTheme = finalTheme;
        _emitTheme(finalTheme);
      }

      anchorPage = page;
    } catch (e) {
      log('AI error: $e');
      _emitTheme('default');
    } finally {
      _aiBusy = false;
    }
  }

  // ================================================================
  // THROTTLED THEME EMITTER
  // ================================================================
  Timer? _themeDebounce;
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
    _readerDebounce?.cancel();
    _themeDebounce?.cancel();
    _themeController.close();

    if (_currentDocumentId != null) {
      _vectorService.clearDocument(_currentDocumentId!);
    }
  }
}
