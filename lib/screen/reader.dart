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
import '../service/database_instance.dart';

class ReadingSessionManager {
  final ThemeAnalyzer _analyzer = ThemeAnalyzer();
  final MusicService _musicService = MusicService(db);
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
  final Map<int, String> _pageThemeCache = {}; // Optional cache kecil

  final _themeController = StreamController<String>.broadcast();
  Stream<String> get onThemeChanged => _themeController.stream;

  MusicService get musicService => _musicService;

  bool get hasChapters =>
      _currentDocumentId != null &&
      _vectorService.isDocumentIndexed(_currentDocumentId!);

  StreamSubscription<bool>? _activationSub;

  ReadingSessionManager() {
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
  // START SESSION — INDEX PDF ONCE
  // ================================================================
  Future<void> startSession(String pdfPath) async {
    if (isReady) return;

    _currentTheme = 'default';
    _themeController.add('default');

    _currentDocumentId = pdfPath.hashCode.toString();

    if (!_vectorService.isDocumentIndexed(_currentDocumentId!)) {
      try {
        await _indexPdf(pdfPath);
      } catch (e) {
        log('Indexing failed: $e');
        _emitTheme('default');
        return;
      }
    }

    isReady = true;
    anchorPage = 1;
    lastAnalyzedPage = -1;

    if (AiActivationService.instance.isActive) {
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
  // INDEX PDF — BUT ONLY ONCE
  // ================================================================
  Future<void> _indexPdf(String pdfPath) async {
    final fullText = await compute(_extractPdfText, pdfPath);

    final chapters = ChapterParser.detectChapters(fullText);
    int globalIndex = 0;

    for (final c in chapters) {
      final segment = fullText.substring(c['start']!, c['end']!);
      if (segment.trim().length < 40) continue;

      final chunks = ChapterParser.chunkTextForRAG(
        segment,
        chapterIndex: globalIndex,
      );

      globalIndex += chunks.length;

      if (chunks.isNotEmpty) {
        await _vectorService.indexDocumentBatch(
          _currentDocumentId!,
          chunks,
        );
      }
    }

    log('Indexing complete with $globalIndex chunks.');
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
  // CORE AI-TRIGGER LOGIC
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

      final query =
          'Determine the emotional or narrative theme for this segment near page $page';

      final chunks = await _vectorService.retrieveRelevantContext(
        query,
        topK: 5,
        documentId: _currentDocumentId,
      );

      if (chunks.isEmpty) {
        _emitTheme('default');
        anchorPage = page;
        return;
      }

      final contextText =
          chunks.map((c) => c['content']).join('\n\n');

      final theme = await _analyzer.getThemeFromContext(
        contextText,
        query,
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
