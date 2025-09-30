import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewScreen extends StatefulWidget {
  final String bookPath;
  final String bookTitle;

  const PdfViewScreen({
    super.key,
    required this.bookPath,
    required this.bookTitle,
  });

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  late PdfControllerPinch _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openAsset(widget.bookPath),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.bookTitle)),
      body: PdfViewPinch(controller: _pdfController),
    );
  }
}
