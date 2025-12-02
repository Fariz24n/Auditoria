import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import '../drift/app_database.dart';
import '../service/database_instance.dart';
import '../service/ai/ai_activation.dart';
import '../screen/reader.dart';
import '../widget/music_player_widget.dart';
import '../service/app_router.dart' as router;

class PdfViewScreen extends StatefulWidget {
  final int bookId;

  const PdfViewScreen({required this.bookId, super.key});

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  Book? book;
  late final ReadingSessionManager _reader;

  late StreamSubscription<bool> _aiSub;
  bool _aiActive = AiActivationService.instance.isActive;
  bool _showMusicWidget = true;

  PdfControllerPinch? _pdfController;
  int _lastSavedPage = 0;
  bool _controllerDisposed = false;
  String? _pdfLoadError;
  bool _isOpeningPdf = false;

  // 🔥 NEW: UI Debounce
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _reader = ReadingSessionManager(router.musicService);
    _loadBook();

    // ------------------------------------------------------------
    // 1. Listener Tombol AI (ON/OFF)
    // ------------------------------------------------------------
    _aiSub = AiActivationService.instance.onActivationChanged.listen((active) {
      if (!mounted) return;

      setState(() => _aiActive = active);

      // ⚠️ PERHATIAN: HAPUS BAGIAN INI jika Anda mau musik TETAP JALAN
      // setelah AI otomatis mati.
      /*
      if (!active) {
        _reader.stopMusic(); // <--- KOMENTARI/HAPUS BARIS INI
        return;
      }
      */
      // Sebagai gantinya, jika mati, biarkan saja (jangan panggil stopMusic)

      // Logika jika AI baru saja dinyalakan
      if (active && book != null && book!.filePath.isNotEmpty) {
        final currentPage = _pdfController?.page ?? 1;
        _reader.analyzeCurrentPages(book!.filePath, currentPage);
      }
    });

    // ------------------------------------------------------------
    // 2. 🔥 Listener Hasil Analisis Tema (TARUH DISINI)
    // ------------------------------------------------------------
    // Ini mendengarkan kapan saja AI selesai berpikir dan mengirim tema.
    _reader.onThemeChanged.listen((theme) {
      if (!mounted) return;

      // Tampilkan Notifikasi Debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              // Tampilkan tema yang didapat untuk memastikan data sampai
              Expanded(child: Text("AI Selesai! Tema: '$theme'. Memutar musik...")),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      debugPrint("DEBUG UI: Tema '$theme' diterima di View.");
    });
  }
  
  @override
  void dispose() {
    _aiSub.cancel();
    _reader.dispose();
    _saveLastPage();

    _scrollDebounce?.cancel();

    if (_pdfController != null && !_controllerDisposed) {
      try {
        _pdfController!.dispose();
      } catch (_) {}
      _controllerDisposed = true;
    }

    super.dispose();
  }

  // ============================================================
  //  SAVE LAST PAGE
  // ============================================================
  Future<void> _saveLastPage() async {
    if (book == null || _pdfController == null || _controllerDisposed) return;

    try {
      final page = _pdfController!.page;
      if (page > 0 && page != _lastSavedPage) {
        await db.updateLastPage(widget.bookId, page);
        _lastSavedPage = page;
      }
    } catch (_) {}
  }

  // ============================================================
  //  LOAD BOOK & OPEN PDF
  // ============================================================
  Future<void> _loadBook() async {
    if (_isOpeningPdf) return;

    final books = await db.getAllBooks();
    final match = books.where((b) => b.id == widget.bookId);

    if (match.isEmpty) {
      setState(() => _pdfLoadError = 'Book not found');
      return;
    }

    book = match.first;

    final filePath = book!.filePath;

    if (!File(filePath).existsSync()) {
      setState(() => _pdfLoadError = 'PDF file not found: $filePath');
      return;
    }

    _isOpeningPdf = true;

    try {
      final initialPage = book!.lastPageRead;
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(filePath),
        initialPage: initialPage > 0 ? initialPage : 1,
      );

      _lastSavedPage = initialPage;
      _controllerDisposed = false;

      // Ensure jump landing
      if (initialPage > 0) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted || _pdfController == null) return;
          try {
            _pdfController!.jumpToPage(initialPage);
          } catch (_) {}
        });
      }

      if (mounted) {
        setState(() => _pdfLoadError = null);
      }

    } on PlatformException catch (e) {
      setState(() => _pdfLoadError = 'Failed to open PDF: ${e.message}');
    } catch (e) {
      setState(() => _pdfLoadError = 'Failed to open PDF: $e');
    } finally {
      _isOpeningPdf = false;
    }

    // No warmup needed - AI only activates when button pressed
  }

  // ============================================================
  //  BUILD UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book?.title ?? 'PDF Viewer'),
        actions: [
            IconButton(
              icon: Icon(
                _showMusicWidget ? Icons.music_note : Icons.music_off,
                color: _showMusicWidget ? Colors.green : null,
              ),
              tooltip: _showMusicWidget ? 'Hide Music Player' : 'Show Music Player',
              onPressed: () {
                setState(() => _showMusicWidget = !_showMusicWidget);
              },
            ),
          IconButton(
            icon: Icon(
              _aiActive ? Icons.memory : Icons.memory_outlined,
              color: _aiActive ? Colors.amber : null,
            ),
            tooltip: _aiActive ? 'Disable AI' : 'Enable AI',
            onPressed: () {
              AiActivationService.instance.toggle();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AiActivationService.instance.isActive
                        ? 'AI Activated.'
                        : 'AI Deactivated.',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_pdfLoadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _pdfLoadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else if (_pdfController == null)
            const Center(child: CircularProgressIndicator())
          else
            PdfViewPinch(
              controller: _pdfController!,
              onPageChanged: (page) {
                if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();
                _scrollDebounce = Timer(const Duration(seconds: 2), () {
                  if (mounted && page > 0) {
                    db.updateLastPage(widget.bookId, page);
                    debugPrint("💾 Halaman $page tersimpan otomatis!");
                    }
                  });
                },
              ),
              // No onPageChanged - we only analyze once when AI button pressed


          if (_showMusicWidget)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: MusicPlayerWidget(
                  musicService: _reader.musicService,
                  themeStream: _reader.onThemeChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
