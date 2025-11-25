// lib/screen/pdf_view_screen.dart
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

class PdfViewScreen extends StatefulWidget {
  final int bookId;

  const PdfViewScreen({required this.bookId, super.key});

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  Book? book;
  final _reader = ReadingSessionManager();

  late StreamSubscription<bool> _aiSub;
  bool _aiActive = AiActivationService.instance.isActive;

  PdfControllerPinch? _pdfController;
  int _lastSavedPage = 0;
  bool _isOpeningPdf = false;
  bool _pdfControllerDisposed = false;
  String? _pdfLoadError;

  @override
  void initState() {
    super.initState();
    _loadBook();

    _aiSub = AiActivationService.instance.onActivationChanged.listen((active) {
      if (!mounted) return;
      setState(() => _aiActive = active);

      if (!active) {
        _reader.stopMusic();
        return;
      }

      // Defer heavy work so UI can remain responsive.
      // Use a short delay and ensure we don't call startSession if already running.
      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) return;
        if (book == null || book!.filePath.isEmpty) return;
        // If not parsed yet, start session with timeout (to avoid infinite block)
        if (!_reader.hasChapters) {
          try {
            await _reader.startSession(book!.filePath).timeout(
                  const Duration(seconds: 12),
                );
          } catch (e) {
            // Log and fail gracefully; do not throw
            debugPrint('AI parse timeout/failed: $e');
          }
        } else {
          // Analyze current visible page, not page 0
          final currentPage = _pdfController?.page ?? 0;
          _reader.analyzeAndPlayForPage(currentPage);
        }
      });
    });
  }

  @override
  void dispose() {
    _aiSub.cancel();
    _reader.dispose();
    _saveLastPage();
    
    if (_pdfController != null && !_pdfControllerDisposed) {
      try {
        _pdfController!.dispose();
        _pdfControllerDisposed = true;
      } catch (e) {
        // Ignore disposal errors
      }
    }
    super.dispose();
  }

  Future<void> _saveLastPage() async {
    if (book == null || _pdfController == null || _pdfControllerDisposed) return;
    try {
      final currentPage = _pdfController!.page;
      if (currentPage > 0 && currentPage != _lastSavedPage) {
        await db.updateLastPage(widget.bookId, currentPage);
        _lastSavedPage = currentPage;
      }
    } catch (e) {
      // Ignore save errors
    }
  }

  Future<void> _loadBook() async {
    if (_isOpeningPdf) return;

    final allBooks = await db.getAllBooks();
    final match = allBooks.where((b) => b.id == widget.bookId);

    if (match.isEmpty) {
      setState(() {
        _pdfLoadError = 'Book not found';
      });
      return;
    }

    book = match.first;
    final filePath = book!.filePath;

    if (!File(filePath).existsSync()) {
      setState(() {
        _pdfLoadError = 'PDF file not found: $filePath';
      });
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
      _pdfControllerDisposed = false;

      if (initialPage > 0) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted || _pdfController == null) return;
          try {
            _pdfController!.jumpToPage(initialPage);
          } catch (e) {
            // Ignore jump errors
          }
        });
      }

      if (mounted) {
        setState(() {
          _pdfLoadError = null;
        });
      }

    } on PlatformException catch (e) {
      setState(() {
        _pdfLoadError = 'Failed to open PDF: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _pdfLoadError = 'Failed to open PDF: $e';
      });
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
              _aiActive ? Icons.memory : Icons.memory_outlined,
              color: _aiActive ? Colors.amber : null,
            ),
            tooltip: _aiActive ? 'Matikan AI' : 'Aktifkan AI',
            onPressed: () {
              AiActivationService.instance.toggle();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AiActivationService.instance.isActive
                        ? 'Mode AI diaktifkan.'
                        : 'Mode AI dimatikan.',
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
                if (_aiActive && _reader.hasChapters) {
                  _reader.onPageChanged(page);
                }
              },
            ),
          if (_aiActive)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: MusicPlayerWidget(
                musicService: _reader.musicService,
                themeStream: _reader.onThemeChanged,
              ),
            ),
        ],
      ),
    );
  }
}
