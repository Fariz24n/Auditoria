import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../drift/app_database.dart';
import '../service/database_instance.dart';
import '../service/ai/ai_activation.dart';
import '../screen/reader.dart';

import '../widget/music_player_widget.dart';
import '../service/app_router.dart' as router;

// 🔥 Syncfusion PDF Viewer
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
  bool _showMusicWidget = false;

  // Syncfusion controller untuk navigasi halaman
  final PdfViewerController _pdfViewerController = PdfViewerController();

  int _lastSavedPage = 0;
  bool _isOpeningPdf = false;
  String? _pdfLoadError;

  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _reader = ReadingSessionManager(router.musicService);
    _loadBook();

    _aiSub = AiActivationService.instance.onActivationChanged.listen((active) {
      if (!mounted) return;
      setState(() => _aiActive = active);

      if (active && book != null && book!.filePath.isNotEmpty) {
        final currentPage = _pdfViewerController.pageNumber;
        _reader.analyzeCurrentPages(book!.filePath, currentPage);
      }
    });

      _reader.onThemeChanged.listen((theme) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row( // <-- tambahkan const di sini
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text("AI: Tema diterima! Memutar musik...")),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 3),
        ),
      );
      debugPrint("DEBUG UI: Tema '$theme' diterima.");
    });

  }

  @override
  void dispose() {
    _aiSub.cancel();
    _reader.dispose();
    _saveLastPage();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  Future<void> _saveLastPage() async {
    if (book == null) return;

    try {
      final page = _pdfViewerController.pageNumber;
      if (page > 0 && page != _lastSavedPage) {
        await db.updateLastPage(widget.bookId, page);
        _lastSavedPage = page;
      }
    } catch (_) {}
  }

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
      _lastSavedPage = initialPage;

      // Jump ke halaman awal setelah viewer selesai build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (initialPage > 0) {
          _pdfViewerController.jumpToPage(initialPage);
        }
      });

      setState(() => _pdfLoadError = null);
    } catch (e) {
      setState(() => _pdfLoadError = 'Failed to open PDF: $e');
    } finally {
      _isOpeningPdf = false;
    }
  }

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
            onPressed: () {
              setState(() => _showMusicWidget = !_showMusicWidget);
            },
          ),
          IconButton(
            icon: Icon(
              _aiActive ? Icons.memory : Icons.memory_outlined,
              color: _aiActive ? Colors.amber : null,
            ),
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
          else if (book == null)
            const Center(child: CircularProgressIndicator())
          else
            SfPdfViewer.file(
              File(book!.filePath),
              controller: _pdfViewerController,
              onDocumentLoaded: (details) {
                final initial = book!.lastPageRead;
                if (initial > 0) {
                  _pdfViewerController.jumpToPage(initial);
                }
              },
              onDocumentLoadFailed: (details) {
                setState(() {
                  _pdfLoadError = details.error.toString();
                });
              },
              onPageChanged: (details) {
                // Debounce auto-save page
                if (_scrollDebounce?.isActive ?? false) {
                  _scrollDebounce!.cancel();
                }

                _scrollDebounce = Timer(const Duration(seconds: 2), () {
                  db.updateLastPage(widget.bookId, details.newPageNumber);
                  debugPrint("💾 Auto-saved page ${details.newPageNumber}");
                });
              },
            ),

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
