// lib/screen/pdf_view_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
  late final ReadingStateManager _reader;
  late StreamSubscription<bool> _aiSub;
  
  bool _aiActive = AiActivationService.instance.isActive;
  bool _showMusicWidget = false;
  bool _isAiProcessing = false; // Track proses AI untuk UI feedback

  final PdfViewerController _pdfViewerController = PdfViewerController();
  String? _pdfLoadError;
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _reader = ReadingStateManager(router.musicService);
    _loadBook();

    // Listener Aktivasi AI
    _aiSub = AiActivationService.instance.onActivationChanged.listen((active) {
      if (!mounted) return;
      setState(() => _aiActive = active);
      
      if (active) {
        _triggerAnalysis();
      }
    });

    // Listener Theme Change dari AI
    _reader.onThemeChanged.listen((theme) {
      if (!mounted) return;
      _showThemeSnackBar(theme);
    });
  }

  /// Wrapper aman untuk memicu analisis AI
  Future<void> _triggerAnalysis() async {
    // Guard: Jangan jalan jika sedang proses, PDF belum siap, atau AI mati
    if (_isAiProcessing || _reader.isAnalyzing || book == null) return;
    if (!AiActivationService.instance.isActive) return;

    setState(() => _isAiProcessing = true);
    
    try {
      final currentPage = _pdfViewerController.pageNumber;
      if (currentPage > 0) {
        debugPrint("🚀 [UI] Triggering AI Analysis for page $currentPage");
        await _reader.analyzeCurrentPages(book!.filePath, currentPage);
      }
    } catch (e) {
      debugPrint("❌ [UI] Analysis Error: $e");
    } finally {
      if (mounted) setState(() => _isAiProcessing = false);
    }
  }
  
  /// Initialize music with default playlist for manual controls
  Future<void> _initializeMusicPlayback() async {
    if (book == null) return;
    try {
      // Load default theme playlist to enable manual controls
      await _reader.musicService.setPlaylistByTheme('default', startIndex: 0);
      debugPrint("✅ [UI] Music playback initialized with default theme");
    } catch (e) {
      debugPrint("⚠️ [UI] Music initialization warning: $e");
    }
  }

  void _showThemeSnackBar(String theme) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text("Mood: ${theme.toUpperCase()} - Menyesuaikan musik...")),
          ],
        ),
        backgroundColor: Colors.blueGrey[900],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _aiSub.cancel();
    _reader.dispose();
    _saveLastPage();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  void _saveLastPage() {
    if (book != null) {
      final currentPage = _pdfViewerController.pageNumber;
      db.updateLastPage(widget.bookId, currentPage);
    }
  }

  Future<void> _loadBook() async {
    try {
      final loadedBook = await (db.select(db.books)
            ..where((t) => t.id.equals(widget.bookId)))
          .getSingleOrNull();

      if (loadedBook == null) {
        if (mounted) {
          setState(() {
            _pdfLoadError = 'Buku tidak ditemukan';
          });
        }
        return;
      }

      final file = File(loadedBook.filePath);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _pdfLoadError = 'File PDF tidak ditemukan di:\n${loadedBook.filePath}';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          book = loadedBook;
        });

        // Jump ke halaman terakhir dibaca
        if (loadedBook.lastPageRead > 0) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _pdfViewerController.jumpToPage(loadedBook.lastPageRead);
            }
          });
        }
        
        // Initialize music playback for manual controls
        _initializeMusicPlayback();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pdfLoadError = 'Error membuka buku: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book?.title ?? 'PDF Viewer'),
        actions: [
          // Tombol Music Toggle
          IconButton(
            icon: Icon(
              _showMusicWidget ? Icons.music_note : Icons.music_off,
              color: _showMusicWidget ? Colors.green : null,
            ),
            onPressed: () => setState(() => _showMusicWidget = !_showMusicWidget),
          ),
          
          // Tombol AI Toggle (Responsive State)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _isAiProcessing 
              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)))
              : IconButton(
                  icon: Icon(
                    _aiActive ? Icons.psychology : Icons.psychology_outlined,
                    color: _aiActive ? Colors.amber : null,
                  ),
                  onPressed: () {
                    AiActivationService.instance.toggle();
                  },
                ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_pdfLoadError != null)
            _buildErrorView()
          else if (book == null)
            const Center(child: CircularProgressIndicator())
          else
            SfPdfViewer.file(
              File(book!.filePath),
              controller: _pdfViewerController,
              onPageChanged: (details) {
                // 1. Auto-save page
                _handlePageSave(details.newPageNumber);
                
                // 2. Auto-trigger AI jika aktif (Debounced)
                if (_aiActive) {
                  _triggerAnalysis();
                }
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

  void _handlePageSave(int pageNum) {
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(seconds: 2), () {
      db.updateLastPage(widget.bookId, pageNum);
      debugPrint("💾 Auto-saved page $pageNum");
    });
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_pdfLoadError!, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}