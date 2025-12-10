import 'package:flutter/material.dart';
import '../drift/app_database.dart';
import '../service/folder_scanner_service.dart';
import 'import_config_dialog.dart';

class ImportScreen extends StatefulWidget {
  final AppDatabase db;

  const ImportScreen({super.key, required this.db});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late final FolderScannerService _scannerService;
  bool _isLoading = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _scannerService = FolderScannerService(widget.db);
  }

  // Tetap pakai dialog – tapi tanpa list hasil
  Future<void> _showImportPanel() async {
    final ImportConfig? config = await showDialog<ImportConfig>(
      context: context,
      builder: (context) => const ImportConfigDialog(),
    );

    if (config == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Memindai folder...";
    });

    try {
      await _scannerService.scanAndImport(config);

      if (!mounted) return;

      // Setelah selesai → langsung tutup layar ini
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = "";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal scan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impor'),
      ),

      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
            )
          : const Center(
              child: Text('Tekan tombol folder untuk impor'),
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => ImportConfigDialog(db: db),
          );
        },
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
