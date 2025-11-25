class ChapterParser {
  static List<Map<String, dynamic>> chunkTextForRAG(
    String fullText, {
    int chunkSize = 500,
    int overlap = 100,
    int? chapterIndex,
  }) {
    final chunks = <Map<String, dynamic>>[];
    
    if (fullText.isEmpty) return chunks;

    int start = 0;
    int chunkIndex = 0;

    while (start < fullText.length) {
      final end = (start + chunkSize).clamp(0, fullText.length);
      String chunkText = fullText.substring(start, end);

      // Optimasi pemotongan kalimat (Smart Boundary)
      if (end < fullText.length) {
        final lastPeriod = chunkText.lastIndexOf('.');
        final lastSpace = chunkText.lastIndexOf(' '); // fallback ke spasi
        
        // Prioritaskan titik, lalu spasi, asalkan tidak membuang terlalu banyak teks (>100 char)
        if (lastPeriod > chunkSize - 100) {
          chunkText = chunkText.substring(0, lastPeriod + 1);
        } else if (lastSpace > chunkSize - 100) {
          chunkText = chunkText.substring(0, lastSpace);
        }
      }

      final cleanContent = chunkText.trim();
      if (cleanContent.isNotEmpty) {
         chunks.add({
          'content': cleanContent,
          'metadata': {
            'chunkIndex': chunkIndex,
            'chapterIndex': chapterIndex ?? 0,
            'startPosition': start,
            'endPosition': start + chunkText.length,
          },
        });
        chunkIndex++;
      }

      // 🔥 FIX INFINITE LOOP:
      // Hitung langkah maju. Jika (panjang chunk - overlap) hasilnya <= 0,
      // kita paksa maju minimal sebesar sisa panjang chunk agar loop selesai.
      int step = chunkText.length - overlap;
      if (step <= 0) {
         step = chunkText.length; // Maju habis jika sisa dikit
      }
      
      start += step;
    }

    return chunks;
  }

  /// Convert extracted chapters into RAG-ready chunks
  static List<Map<String, dynamic>> chaptersToChunks(
    List<Map<String, String>> chapters, {
    int chunkSize = 500,
    int overlap = 100,
  }) {
    final allChunks = <Map<String, dynamic>>[];

    for (var i = 0; i < chapters.length; i++) {
      final content = chapters[i]['content'] ?? '';
      final heading = chapters[i]['heading'] ?? 'Chapter $i';
      
      final chapterChunks = chunkTextForRAG(
        content,
        chunkSize: chunkSize,
        overlap: overlap,
        chapterIndex: i,
      );

      // Add chapter heading to metadata
      for (var chunk in chapterChunks) {
        chunk['metadata']['chapterHeading'] = heading;
      }

      allChunks.addAll(chapterChunks);
    }

    return allChunks;
  }

  static List<Map<String, int>> detectChapters(String text) {
      final regex = RegExp(
        r'^\s*(chapter|bab|bagian|prologue|epilogue)\s*\d*.*$', 
        caseSensitive: false, 
        multiLine: true,
      );

      final matches = regex.allMatches(text);
      final chapters = <Map<String, int>>[];

      if (matches.isEmpty) {
        // Fallback: Jika tidak ada chapter, anggap 1 buku = 1 chapter
        return [{'start': 0, 'end': text.length}];
      }

      int? currentStart;
      
      for (final match in matches) {
        if (currentStart != null) {
          // Tutup chapter sebelumnya
          chapters.add({'start': currentStart, 'end': match.start});
        }
        currentStart = match.start;
      }
      
      // Tambahkan chapter terakhir (dari match terakhir sampai habis)
      if (currentStart != null) {
        chapters.add({'start': currentStart, 'end': text.length});
      }

      return chapters;
    }

}
