import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// Wrapper untuk membawa data file dari dialog
class SelectedFileData {
  final String name;
  final String? path;
  final List<int>? bytes;
  final String extension;
  
  SelectedFileData({
    required this.name,
    required this.path,
    required this.bytes,
    required this.extension,
  });
}

class ImportConfigDialog extends StatefulWidget {
  const ImportConfigDialog({super.key});

  @override
  State<ImportConfigDialog> createState() => _ImportConfigDialogState();
}

class _ImportConfigDialogState extends State<ImportConfigDialog> {
  String _path = 'Belum dipilih';
  bool _pdf = true;
  bool _mp3 = false;

  // ================================
  // PICK FILES (Multiple) - ANDROID FRIENDLY
  // ================================
  List<SelectedFileData> _selectedFiles = [];
  
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        if (_pdf) 'pdf',
        if (_mp3) 'mp3',
      ],
      allowMultiple: true,
      withData: true, // ✅ PENTING: Minta bytes data untuk Android
    );

    if (result == null) return;

    print("📁 FilePicker returned ${result.files.length} files");

    _selectedFiles = result.files.map((pf) {
      final ext = pf.extension ?? '';
      print("  📄 File: ${pf.name}");
      print("    Path: ${pf.path}");
      print("    Bytes: ${pf.bytes?.length ?? 0} bytes");
      print("    Extension: .$ext");
      
      return SelectedFileData(
        name: pf.name,
        path: pf.path,
        bytes: pf.bytes,
        extension: '.$ext',
      );
    }).toList();

    if (_selectedFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada file yang dipilih")),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _path = '${_selectedFiles.length} file dipilih';
      });
    }
    
    print("📌 Selected files: ${_selectedFiles.length}");
  }


  // =========================
  // UI Dialog
  // =========================
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Impor dari Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File Selection
          ListTile(
            title: Text(
              _path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text('Pilih file untuk diimport'),
            trailing: const Icon(Icons.file_open),
            onTap: _pickFiles,
          ),
          const SizedBox(height: 12),

          // PDF
          CheckboxListTile(
            title: const Text('PDF'),
            value: _pdf,
            onChanged: (v) => setState(() => _pdf = v!),
          ),

          // MP3
          CheckboxListTile(
            title: const Text('MP3'),
            value: _mp3,
            onChanged: (v) => setState(() => _mp3 = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),

        // =========================
        // TOMBOL OKE
        // =========================
        ElevatedButton(
          onPressed: () async {
            // --- Validasi: files sudah dipilih ---
            if (_selectedFiles.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pilih file terlebih dahulu")),
              );
              return;
            }

            // --- Validasi: minimal 1 ekstensi ---
            if (!_pdf && !_mp3) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Pilih minimal satu tipe file (PDF/MP3)."),
                ),
              );
              return;
            }

            // ==========================
            // DEBUG LOG
            // ==========================
            print("========== ImportConfigDialog ==========");
            print("Dipilih ${_selectedFiles.length} files");
            for (var f in _selectedFiles) {
              print("  - ${f.name} (${f.bytes?.length ?? 0} bytes)");
            }
            print("=========================================");

            // ==========================
            // KIRIM FILES LIST KE SCREEN
            // ==========================
            Navigator.pop(
              context,
              _selectedFiles,
            );
          },
          child: const Text('OKE'),
        ),
      ],
    );
  }
}
