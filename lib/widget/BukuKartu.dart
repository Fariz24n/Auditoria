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
              Image.asset(
                coverPath,
                width: width,
                height: height - 30, // sisain ruang buat judul
                fit: BoxFit.cover,
              ),
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
}
