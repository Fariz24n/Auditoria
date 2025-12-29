// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import '../service/folder_scanner_service.dart';

// class ImportConfigDialog extends StatefulWidget {
//   const ImportConfigDialog({super.key});

//   @override
//   State<ImportConfigDialog> createState() => _ImportConfigDialogState();
// }

// class _ImportConfigDialogState extends State<ImportConfigDialog> {
//   String _path = 'Belum dipilih';
//   bool _pdf = true;
//   bool _mp3 = false;

//   Future<void> _pickFolder() async {
//     final path = await FilePicker.platform.getDirectoryPath();
//     if (path != null) {
//       setState(() => _path = path);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Impor dari Folder'),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Folder path
//           ListTile(
//             title: Text(
//               _path,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//             trailing: const Icon(Icons.folder_open),
//             onTap: _pickFolder,
//           ),
//           const SizedBox(height: 12),

//           // PDF option
//           CheckboxListTile(
//             title: const Text('PDF'),
//             value: _pdf,
//             onChanged: (v) => setState(() => _pdf = v!),
//           ),

//           // MP3 option
//           CheckboxListTile(
//             title: const Text('MP3'),
//             value: _mp3,
//             onChanged: (v) => setState(() => _mp3 = v!),
//           ),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('BATAL'),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             if (_path == 'Belum dipilih') return;

//             // VALIDASI minimal pilih 1 ekstensi
//             if (!_pdf && !_mp3) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content:
//                       Text('Pilih minimal satu jenis file (PDF atau MP3).'),
//                 ),
//               );
//               return;
//             }

//             // KIRIM ImportConfig versi service
//             Navigator.pop(
//               context,
//               ImportConfig(
//                 selectedPath: _path,
//                 allowedExtensions: [
//                   if (_pdf) '.pdf',
//                   if (_mp3) '.mp3',
//                 ],
//                 minSizeKb: 1,
//                 isFavorite: false,
//                 category: null,
//               ),
//             );
//           },
//           child: const Text('OKE'),
          
//         ),
//       ],
      
//     );
//   }
// }

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

    _selectedFiles = result.files.map((pf) {
      final ext = pf.extension ?? '';
      
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

            // KIRIM FILES LIST KE SCREEN
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
