import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ImportDialogResult {
  final String folderPath;
  final bool scanPdf;
  final bool scanMp3;

  ImportDialogResult({
    required this.folderPath,
    required this.scanPdf,
    required this.scanMp3,
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

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      setState(() => _path = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Impor dari Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Path
          ListTile(
            title: Text(_path, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.folder_open),
            onTap: _pickFolder,
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
        ElevatedButton(
          onPressed: () {
            if (_path == 'Belum dipilih') return;

            Navigator.pop(
              context,
              ImportDialogResult(
                folderPath: _path,
                scanPdf: _pdf,
                scanMp3: _mp3,
              ),
            );
          },
          child: const Text('OKE'),
        ),
      ],
    );
  }
}
