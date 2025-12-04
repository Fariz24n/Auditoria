import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart'; // 👈 Pakai pdfx (ringan & gratis)
import '../service/ai/theme_service.dart';
import '../service/music_service.dart';
import '../service/ai/ai_activation.dart';
import '../service/ai/chapter_parser.dart';

class ReadingSessionManager {
  final ThemeAnalyzer _analyzer = ThemeAnalyzer();
  final MusicService _musicService;

  bool _isAnalyzing = false;
  final _themeController = StreamController<String>.broadcast();
  Stream<String> get onThemeChanged => _themeController.stream;

  MusicService get musicService => _musicService;
  bool get isAnalyzing => _isAnalyzing;

  StreamSubscription<bool>? _activationSub;
  Timer? _themeDebounce;

  ReadingSessionManager(this._musicService) {
    onThemeChanged.listen((theme) {
      _musicService.setPlaylistByTheme(theme);
    });

    _activationSub = AiActivationService.instance.onActivationChanged.listen((active) {});
  }

  // ================================================================
  // 1. MAIN ANALYSIS FUNCTION
  // ================================================================
  Future<void> analyzeCurrentPages(String pdfPath, int currentPage) async {
    if (_isAnalyzing) return;

    _isAnalyzing = true;
    _themeDebounce?.cancel();
    
    debugPrint("🚀 [Reader] Memulai analisis halaman $currentPage via ChapterParser...");

    try {
      // A. Ambil Text Raw (Pakai PDFX di Main Thread karena Platform Channel)
      final pageRange = _calculatePageRange(currentPage);
      
      // Kita panggil fungsi lokal biasa (bukan compute) karena PDFX butuh akses native
      final rawText = await _extractPagesTextWithPdfx(
        pdfPath, 
        pageRange['start']!, 
        pageRange['end']!
      ).timeout(const Duration(seconds: 10), onTimeout: () => '');

      if (rawText.isEmpty || rawText.length < 50) {
        debugPrint("⚠️ [Reader] Teks kosong/terlalu pendek.");
        _emitTheme('default');
        return;
      }

      // B. Cleaning & Chunking (Berat di CPU -> Lempar ke Isolate Compute)
      // Ini memanfaatkan logika ChapterParser yang sudah Anda buat
      final List<Map<String, dynamic>> chunks = await compute(
        _processWithParser, 
        rawText,
      );

      if (chunks.isEmpty) {
        debugPrint("⚠️ [Reader] Parser tidak menghasilkan chunk valid.");
        _emitTheme('default');
        return;
      }

      // C. Kirim Chunk Bersih ke AI
      final selectedChunk = chunks.first['content'] as String;
      
      debugPrint("✅ [Reader] Teks bersih (${selectedChunk.length} chars) dikirim ke AI.");

      final theme = await _analyzer.getThemeFromContext(
        selectedChunk, 
        'Analyze emotional theme...',
      );

      _emitTheme(theme ?? 'default');

    } catch (e) {
      debugPrint("🚨 [Reader] Error: $e");
      _emitTheme('default');
    } finally {
      _isAnalyzing = false;
      // Auto-off logic
      Future.delayed(const Duration(milliseconds: 500), () {
        if (AiActivationService.instance.isActive) {
           AiActivationService.instance.setActive(false);
        }
      });
    }
  }

  // --- HELPER STATIC (Safe for Compute) ---
  static List<Map<String, dynamic>> _processWithParser(String text) {
    // Memanggil ChapterParser untuk membersihkan teks
    return ChapterParser.chunkTextForRAG(
      text,
      chunkSize: 1000, 
      overlap: 100,    
    );
  }

  Map<String, int> _calculatePageRange(int currentPage) {
    final start = (currentPage - 1).clamp(1, currentPage);
    final end = currentPage + 1;
    return {'start': start, 'end': end};
  }

  // ================================================================
  // 2. PDFX TEXT EXTRACTION (Async Native)
  // ================================================================
  Future<String> _extractPagesTextWithPdfx(String path, int startPage, int endPage) async {
    try {
      final document = await PdfDocument.openFile(path);
      final buffer = StringBuffer();
      final totalPages = document.pagesCount;

      for (int i = startPage; i <= endPage && i <= totalPages; i++) {
        // PDFX index halaman dimulai dari 1
        final page = await document.getPage(i); 
        final textContent = await page.loadText();
        
        buffer.writeln(textContent.fullText);
        buffer.writeln('\n'); // Spasi antar halaman
        
        await page.close(); // Wajib tutup page
      }

      await document.close(); // Wajib tutup doc
      return buffer.toString();

    } catch (e) {
      debugPrint('PDFX extraction error: $e');
      return '';
    }
  }

  void _emitTheme(String theme) {
    _themeDebounce?.cancel();
    _themeDebounce = Timer(const Duration(milliseconds: 250), () {
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