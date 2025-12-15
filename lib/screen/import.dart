import 'package:flutter/material.dart';
import '../drift/app_database.dart';
import '../service/folder_scanner_service.dart';
import '../screen/import_config_dialog.dart';

class ImportScreen extends StatefulWidget {
  final AppDatabase db;

  // ✅ CONST used here for performance
  const ImportScreen({super.key, required this.db});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _loading = false;
  String _msg = "";

  Future<void> _startImport() async {
    // 1. Show Dialog and get LIST of files (Not just config)
    final List<SelectedFileData>? selectedFiles =
        await showDialog<List<SelectedFileData>>(
      context: context,
      // ✅ CONST used here
      builder: (_) => const ImportConfigDialog(),
    );

    // 2. Check if user cancelled or didn't pick files
    if (selectedFiles == null || selectedFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // ✅ CONST used here
          const SnackBar(content: Text("Tidak ada file yang dipilih.")),
        );
      }
      return;
    }

    final scanner = FolderScannerService(widget.db);
    
    setState(() {
      _loading = true;
      _msg = "Memproses ${selectedFiles.length} file...";
    });

    int successCount = 0;
    int totalFiles = selectedFiles.length;

    try {
      // 3. Loop through every selected file and import it
      for (var i = 0; i < totalFiles; i++) {
        final fileData = selectedFiles[i];
        
        setState(() {
          _msg = "Mengimpor ${i + 1} dari $totalFiles...\n${fileData.name}";
        });

        // NOTE: We cannot use 'const' here because fileData values are dynamic/runtime.
        final config = ImportConfig(
          fileName: fileData.name,
          filePath: fileData.path,
          fileBytes: fileData.bytes,
          extension: fileData.extension,
          minSizeKb: 1, 
          isFavorite: false,
          category: null, 
        );

        // Run the import logic
        final imported = await scanner.scanAndImport(config);
        successCount += imported;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successCount > 0
                ? "Berhasil mengimpor $successCount file baru!"
                : "Tidak ada file baru (Mungkin duplikat).",
          ),
          backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengimpor: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _msg = "";
        });
        
        // Optional: Close screen after successful import
        if (successCount > 0) {
           Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ✅ CONST used here
        title: const Text("Impor File"),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ CONST used here
                  const CircularProgressIndicator(),
                  // ✅ CONST used here
                  const SizedBox(height: 20),
                  Text(_msg, textAlign: TextAlign.center),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ CONST used here
                  const Icon(Icons.upload_file, size: 64, color: Colors.grey),
                  // ✅ CONST used here
                  const SizedBox(height: 16),
                  // ✅ CONST used here
                  const Text("Tekan tombol di bawah untuk memilih file"),
                  const SizedBox(height: 8),
                  // ✅ CONST used here
                  const Text("(PDF atau MP3)", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startImport,
        // ✅ CONST used here
        icon: const Icon(Icons.add),
        label: const Text("Pilih File"),
      ),
    );
  }
}