// lib/screen/reader.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../service/ai/theme_service.dart';
import '../service/music_service.dart';
import '../service/ai/ai_activation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../service/ai/chapter_parser.dart';

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
    });
  }

  // ================================================================
  // ON-DEMAND ANALYSIS - No Indexing, Just Analyze Current Pages
  // ================================================================
  Future<void> analyzeCurrentPages(String pdfPath, int currentPage) async {
    if (_isAnalyzing) return;

    _isAnalyzing = true;
    // Hentikan debounce/timer sebelumnya jika ada
    _themeDebounce?.cancel(); 
    
    debugPrint("🚀 [Reader] Memulai analisis halaman $currentPage via ChapterParser...");

    try {
      // 1. Ambil Raw Text (Reader tetap harus melakukan I/O ini)
      final pageRange = _calculatePageRange(currentPage);
      final rawText = await compute(
        _extractPagesText,
        {'path': pdfPath, 'startPage': pageRange['start']!, 'endPage': pageRange['end']!},
      ).timeout(const Duration(seconds: 10), onTimeout: () => '');

      if (rawText.isEmpty || rawText.length < 50) {
        debugPrint("⚠️ [Reader] Teks kosong/terlalu pendek.");
        _emitTheme('default');
        return;
      }

      // 2. 🔥 INTEGRASI CHAPTER PARSER 🔥
      // Kita panggil fungsi chunkTextForRAG milik ChapterParser.
      // Fungsi ini sudah punya logika 'Smart Boundary' dan pembersihan dasar.
      // Kita set chunkSize 1000 karakter agar pas untuk konteks AI (tidak kepanjangan).
      
      final List<Map<String, dynamic>> chunks = await compute(
        _processWithParser, // Fungsi helper baru (lihat di bawah)
        rawText,
      );

      if (chunks.isEmpty) {
        debugPrint("⚠️ [Reader] ChapterParser tidak menghasilkan chunk valid.");
        _emitTheme('default');
        return;
      }

      // 3. Seleksi Chunk Terbaik
      // Karena kita mengambil range halaman (misal hal 4,5,6), 
      // kita ambil chunk yang berada di "tengah" atau chunk pertama yang cukup panjang.
      // Ini mewakili inti cerita di halaman tersebut.
      final selectedChunk = chunks.first['content'] as String;
      
      debugPrint("✅ [Reader] ChapterParser berhasil! Mengirim ${selectedChunk.length} chars ke AI.");
      debugPrint("📝 [Preview] ${selectedChunk.substring(0, 100)}...");

      // 4. Kirim ke ThemeAnalyzer
      final theme = await _analyzer.getThemeFromContext(
        selectedChunk, // Teks ini sudah bersih berkat ChapterParser
        'Analyze emotional theme...',
      );

      _emitTheme(theme ?? 'default');

    } catch (e) {
      debugPrint("🚨 [Reader] Error: $e");
      _emitTheme('default');
    } finally {
      _isAnalyzing = false;
      // Auto-off logic (tetap dipertahankan)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (AiActivationService.instance.isActive) {
           AiActivationService.instance.setActive(false);
        }
      });
    }
  }

  // --- HELPER UNTUK COMPUTE ISOLATE ---
  // Taruh ini di luar class atau sebagai static method
  static List<Map<String, dynamic>> _processWithParser(String text) {
    // Memanfaatkan logika cleaning & chunking yang sudah Anda buat di ChapterParser
    // source: [cite: 83]
    return ChapterParser.chunkTextForRAG(
      text,
      chunkSize: 1000, // Ukuran ideal untuk analisis tema
      overlap: 100,    // Supaya konteks antar potongan tidak hilang
    );
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

      // --- 🔥 DEBUG LOG (SUKSES) ---
      final result = buffer.toString();
      
      debugPrint("=== PDF DEBUG ===");
      debugPrint("Page Range: $startPage - $endPage");
      debugPrint("Total Text Length: ${result.length}");
      
      // Ambil 100 karakter pertama dengan aman (cek panjang dulu biar gak error)
      final preview = result.length > 100 ? result.substring(0, 100) : result;
      // Ganti enter dengan spasi biar log rapi
      debugPrint("Preview Text: ${preview.replaceAll('\n', ' ')}"); 
      debugPrint("=================");

      return result; // Kembalikan teks asli

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
