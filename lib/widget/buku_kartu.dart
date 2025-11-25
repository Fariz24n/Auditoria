import 'dart:io';
import 'package:flutter/material.dart';

class BookCard extends StatelessWidget {
  final String title;
  final String coverPath;
  final VoidCallback onTap;
  final double width;
  final double height;

  const BookCard({
    super.key,
    required this.title,
    required this.coverPath,
    required this.onTap,
    this.width = 100,   // default kecil
    this.height = 150,  // default kecil
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero, // biar gak nambah jarak default
        child: SizedBox(
          width: width,   // 👉 pakai parameter, bukan hardcode
          height: height,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Use Image.file for file system paths, with fallback for errors
              coverPath.isNotEmpty && File(coverPath).existsSync()
                  ? Image.file(
                      File(coverPath),
                      width: width,
                      height: height - 30,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder(width, height - 30);
                      },
                    )
                  : _buildPlaceholder(width, height - 30),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Placeholder widget when cover image is missing or can't be loaded
  Widget _buildPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(
        Icons.book,
        size: 48,
        color: Colors.grey,
      ),
    );
  }
}
