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
import '../service/database_instance.dart';

class ReadingSessionManager {
  final ThemeAnalyzer _analyzer = ThemeAnalyzer();
  final MusicService _musicService = MusicService(db);
  final VectorDatabaseService _vectorService = VectorDatabaseService();

  String? _currentDocumentId;
  int _currentPageIndex = 0;
  String? _currentTheme;
  final Map<int, String> _pageThemeCache = {};

  final _themeController = StreamController<String>.broadcast();
  Stream<String> get onThemeChanged => _themeController.stream;

  // Expose music service for UI controls
  MusicService get musicService => _musicService;

  // Expose state for UI checks
  bool get hasChapters =>
      _currentDocumentId != null &&
      _vectorService.isDocumentIndexed(_currentDocumentId!);
  int get currentChapterIndex => _currentPageIndex;

  bool _isBusy = false;
  bool _isIndexing = false;
  int? _pendingPage;
  Timer? _themeDebounceTimer;
  StreamSubscription<bool>? _activationSub;

  ReadingSessionManager() {
    _vectorService.initialize();

    onThemeChanged.listen((theme) {
      if (AiActivationService.instance.isActive) {
        _musicService.playTheme(theme);
      }
    });

    _activationSub =
        AiActivationService.instance.onActivationChanged.listen((active) {
      if (!active) {
        _musicService.stop();
      } else {
        if (_currentDocumentId != null && hasChapters) {
          analyzeAndPlayForPage(_currentPageIndex);
        }
      }
    });
  }

  void onPageChanged(int page) {
    if (!hasChapters) return;

    if (page != _currentPageIndex) {
      _currentPageIndex = page;
      analyzeAndPlayForPage(page);
    }
  }

  Future<void> startSession(String pdfPath) async {
    if (_isIndexing) return; // Prevent double indexing

    _currentTheme = 'default';
    _themeController.add('default');

    _currentDocumentId = pdfPath.hashCode.toString();

    if (!_vectorService.isDocumentIndexed(_currentDocumentId!)) {
      _isIndexing = true;
      try {
        await _indexPdfAndStream(pdfPath);
      } catch (e) {
        log('Failed to index document: $e');
        _emitTheme('error');
        return;
      } finally {
        _isIndexing = false;
      }
    }

    if (hasChapters && AiActivationService.instance.isActive) {
      await analyzeAndPlayForPage(_currentPageIndex);
    }
  }

  // ------------------------------
  // NEW FUNCTIONS BELOW
  // ------------------------------

  /// Extract full text from PDF (no chunking)
  static Future<String> _parsePdfTextOnly(String path) async {
    final fileBytes = await File(path).readAsBytes();
    final document = PdfDocument(inputBytes: fileBytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  /// Worker isolate for chunking
  static List<Map<String, dynamic>> _chunkWorker(
      Map<String, dynamic> params) {
    final text = params['text'] as String;
    const maxChunkLength = 500;
    final startOffset = params['globalIndexStart'] as int;

    final chunks = <Map<String, dynamic>>[];
    int index = 0;

    while (index < text.length) {
      var end = index + maxChunkLength;

      if (end < text.length) {
        final lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > index && lastSpace > end - 50) {
          end = lastSpace;
        }
      } else {
        end = text.length;
      }

      final content = text.substring(index, end).trim();
      if (content.isNotEmpty) {
        chunks.add({
          'content': content,
          'index': startOffset + chunks.length,
          'metadata': {'type': 'text'},
        });
      }

      index = end;
    }

    return chunks;
  }

  /// Streamed, chapter-based PDF indexer
  Future<void> _indexPdfAndStream(String pdfPath) async {
    try {
      final fullText = await compute(_parsePdfTextOnly, pdfPath);
      if (fullText.isEmpty) return;

      final chapters = ChapterParser.detectChapters(fullText);
      log('Detected ${chapters.length} chapters');

      int globalIndex = 0;

      for (final chapter in chapters) {
        final text = fullText.substring(chapter['start']!, chapter['end']!);
        if (text.trim().length < 50) continue;

        final chunks = await compute(_chunkWorker, {
          'text': text,
          'globalIndexStart': globalIndex,
        });

        globalIndex += chunks.length;

        if (chunks.isNotEmpty) {
          await _vectorService.indexDocumentBatch(
              _currentDocumentId!, chunks);
        }

        await Future.delayed(const Duration(milliseconds: 10));
      }

      log('Indexing complete. Total chunks: $globalIndex');
    } catch (e) {
      log('Indexing error: $e');
      _emitTheme('error');
    }
  }

  // ------------------------------
  // END OF NEW FUNCTIONS
  // ------------------------------

  Future<void> analyzeAndPlayForPage(int pageIndex) async {
    if (!hasChapters) return;

    if (_isBusy) {
      _pendingPage = pageIndex;
      return;
    }

    // Check cache first
    if (_pageThemeCache.containsKey(pageIndex)) {
      final cachedTheme = _pageThemeCache[pageIndex]!;
      if (cachedTheme != _currentTheme) {
        _currentTheme = cachedTheme;
        _emitTheme(cachedTheme);
        await _musicService.playTheme(cachedTheme);
      }
      return;
    }

    _isBusy = true;

    try {
      if (!AiActivationService.instance.isActive) {
        _currentPageIndex = pageIndex;
        return;
      }

      final query =
          'Analyze the emotional theme or narrative mood of the content on page $pageIndex';

      final relevantChunks = await _vectorService.retrieveRelevantContext(
        query,
        topK: 5,
        documentId: _currentDocumentId,
      );

      if (relevantChunks.isEmpty) {
        _emitTheme('default');
        _pageThemeCache[pageIndex] = 'default';
        return;
      }

      final contextText =
          relevantChunks.map((c) => c['content']).join('\n\n');
      final theme =
          await _analyzer.getThemeFromContext(contextText, query);

      final resultTheme = theme ?? 'default';
      if (resultTheme != _currentTheme) {
        _currentTheme = resultTheme;
        _emitTheme(resultTheme);
      }

      _pageThemeCache[pageIndex] = resultTheme;
      _currentPageIndex = pageIndex;
    } catch (e) {
      log('Error analyzing page: $e');
      _emitTheme('default');
    } finally {
      _isBusy = false;

      if (_pendingPage != null) {
        final nextPage = _pendingPage!;
        _pendingPage = null;
        analyzeAndPlayForPage(nextPage);
      }
    }
  }

  void _emitTheme(String theme) {
    _themeDebounceTimer?.cancel();
    _themeDebounceTimer =
        Timer(const Duration(milliseconds: 250), () {
      _themeController.add(theme);
    });
  }

  @Deprecated('Use analyzeAndPlayForPage instead')
  Future<void> analyzeAndPlayChapter(int index) async {
    await analyzeAndPlayForPage(index);
  }

  void stopMusic() => _musicService.stop();

  void dispose() {
    _activationSub?.cancel();
    _themeDebounceTimer?.cancel();
    _themeController.close();
    stopMusic();

    if (_currentDocumentId != null) {
      _vectorService.clearDocument(_currentDocumentId!);
    }
  }
}
