class ChapterParser {
  /// --------------------------------------------------------------
  /// 1. DETECT CHAPTERS
  /// --------------------------------------------------------------
  /// Mencari pola chapter/Bab/Bagian secara luas.
  /// Jika tidak ada → treat 1 buku penuh sebagai 1 chapter.
  static List<Map<String, int>> detectChapters(String text) {
    final regex = RegExp(
      r'^\s*(chapter|bab|bagian|prologue|epilogue)\s*\d*.*$',
      caseSensitive: false,
      multiLine: true,
    );

    final matches = regex.allMatches(text);
    final chapters = <Map<String, int>>[];

    if (matches.isEmpty) {
      return [
        {'start': 0, 'end': text.length}
      ];
    }

    int? currentStart;

    for (final m in matches) {
      if (currentStart != null) {
        chapters.add({'start': currentStart, 'end': m.start});
      }
      currentStart = m.start;
    }

    if (currentStart != null) {
      chapters.add({'start': currentStart, 'end': text.length});
    }

    return chapters;
  }

  /// --------------------------------------------------------------
  /// 2. CHUNK GENERATOR FOR RAG 
  /// --------------------------------------------------------------
  /// Cara kerja:
  /// - Potong menjadi chunk 400–600 karakter
  /// - Ada overlap kecil supaya tidak kehilangan konteks
  /// - Boundary-aware (tidak potong di tengah kata/periode)
  /// --------------------------------------------------------------
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
      int end = start + chunkSize;
      if (end > fullText.length) end = fullText.length;

      String section = fullText.substring(start, end);

      // SMART BOUNDARY
      if (end < fullText.length) {
        final lastPeriod = section.lastIndexOf('.');
        final lastSpace = section.lastIndexOf(' ');

        if (lastPeriod > chunkSize - 80) {
          section = section.substring(0, lastPeriod + 1);
        } else if (lastSpace > chunkSize - 80) {
          section = section.substring(0, lastSpace);
        }
      }

      final cleaned = section.trim();
      if (cleaned.isNotEmpty) {
        chunks.add({
          'content': cleaned,
          'metadata': {
            'chunkIndex': chunkIndex,
            'chapterIndex': chapterIndex ?? 0,
            'startPosition': start,
            'endPosition': start + cleaned.length,
          },
        });
        chunkIndex++;
      }

      // SAFE STEP FOR NO-INFINITE-LOOP
      int step = cleaned.length - overlap;
      if (step <= 0) step = cleaned.length;

      start += step;
    }

    return chunks;
  }

  /// --------------------------------------------------------------
  /// 3. Convert chapter list → fully chunked content
  /// --------------------------------------------------------------
  static List<Map<String, dynamic>> chaptersToChunks(
    List<Map<String, int>> chapters,
    String fullText, {
    int chunkSize = 500,
    int overlap = 100,
  }) {
    final all = <Map<String, dynamic>>[];

    for (int i = 0; i < chapters.length; i++) {
      final start = chapters[i]['start']!;
      final end = chapters[i]['end']!;
      final content = fullText.substring(start, end);

      final chapterChunks = chunkTextForRAG(
        content,
        chunkSize: chunkSize,
        overlap: overlap,
        chapterIndex: i,
      );

      all.addAll(chapterChunks);
    }

    return all;
  }
}
