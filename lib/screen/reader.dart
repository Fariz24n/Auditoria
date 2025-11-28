// lib/screen/reader.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../service/ai/theme_service.dart';
import '../service/music_service.dart';
import '../service/ai/ai_activation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ReadingSessionManager {
  final ThemeAnalyzer _analyzer = ThemeAnalyzer();
  final MusicService _musicService;

  // ====== SIMPLIFIED STATE ======
  bool _isAnalyzing = false;        // Currently analyzing?

  final _themeController = StreamController<String>.broadcast();
  Stream<String> get onThemeChanged => _themeController.stream;

  MusicService get musicService => _musicService;
  bool get isAnalyzing => _isAnalyzing;

  StreamSubscription<bool>? _activationSub;

  ReadingSessionManager(this._musicService) {
    // Listener: AI theme → ganti musik
    onThemeChanged.listen((theme) {
      _musicService.setPlaylistByTheme(theme);
    });

    // Listener: AI on/off
    _activationSub =
        AiActivationService.instance.onActivationChanged.listen((active) {
      if (!active) {
        _musicService.stop();
      }
    });
  }

  // ================================================================
  // ON-DEMAND ANALYSIS - No Indexing, Just Analyze Current Pages
  // ================================================================
  Future<void> analyzeCurrentPages(String pdfPath, int currentPage) async {
    if (_isAnalyzing) {
      log('Already analyzing, skipping...');
      return;
    }

    _isAnalyzing = true;
    
    log('Starting on-demand analysis for pages around $currentPage');

    try {
      // Extract text from current page ± 1 page (3 pages total)
      final pageRange = _calculatePageRange(currentPage);
      
      final extractedText = await compute(
        _extractPagesText,
        {'path': pdfPath, 'startPage': pageRange['start']!, 'endPage': pageRange['end']!},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('Text extraction timeout');
          return '';
        },
      );

      if (extractedText.isEmpty || extractedText.length < 100) {
        log('Not enough text extracted, using default theme');
        _emitTheme('default');
        return;
      }

      log('Extracted ${extractedText.length} characters, analyzing theme...');

      // Analyze theme directly from extracted text
      final theme = await _analyzer.getThemeFromContext(
        extractedText,
        'Analyze the emotional theme of this book passage',
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          log('Theme analysis timeout');
          return 'default';
        },
      );

      final finalTheme = theme ?? 'default';
      log('Analysis complete: $finalTheme');
      
      _emitTheme(finalTheme);

    } catch (e) {
      log('Analysis error: $e');
      _emitTheme('default');
    } finally {
      _isAnalyzing = false;
      
      // Auto-disable AI after analysis completes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (AiActivationService.instance.isActive) {
          log('Analysis complete, auto-disabling AI mode');
          AiActivationService.instance.setActive(false);
        }
      });
    }
  }

  // ================================================================
  // HELPER: Calculate page range (current ± 1 page)
  // ================================================================
  Map<String, int> _calculatePageRange(int currentPage) {
    final start = (currentPage - 1).clamp(1, currentPage);
    final end = currentPage + 1;
    return {'start': start, 'end': end};
  }

  // ================================================================
  // PDF TEXT EXTRACTION (Specific Pages Only)
  // ================================================================
  static Future<String> _extractPagesText(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    final startPage = params['startPage'] as int;
    final endPage = params['endPage'] as int;

    try {
      final bytes = await File(path).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      
      final buffer = StringBuffer();
      final totalPages = doc.pages.count;

      // Extract only requested pages
      for (int i = startPage - 1; i < endPage && i < totalPages; i++) {
        final pageText = PdfTextExtractor(doc).extractText(startPageIndex: i, endPageIndex: i);
        buffer.writeln(pageText);
        buffer.writeln('\n--- Page Break ---\n');
      }

      doc.dispose();
      return buffer.toString();
    } catch (e) {
      debugPrint('PDF extraction error: $e');
      return '';
    }
  }

  // No complex indexing or continuous analysis needed!

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
    _themeDebounce?.cancel();
    _themeController.close();
    _musicService.stop();
  }
}
