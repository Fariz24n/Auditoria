import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VectorDatabaseService {
  late final GenerativeModel _embeddingModel;
  final Map<String, List<VectorChunk>> _vectorStore = {};
  bool _isInitialized = false;

  VectorDatabaseService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    _embeddingModel = GenerativeModel(
      model: 'text-embedding-004',
      apiKey: apiKey,
    );
  }

  /// Initialize and load cached embeddings from storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadCachedEmbeddings();
    _isInitialized = true;
  }

  /// Index a document by generating embeddings for all chunks
  Future<void> indexDocument(
    String documentId,
    List<Map<String, dynamic>> chunks,
  ) async {
    if (!_isInitialized) await initialize();

    try {
      // Move embedding generation to background isolate
      final vectorChunks = await compute(
        _generateEmbeddingsInBackground,
        {
          'chunks': chunks,
          'documentId': documentId,
          'apiKey': dotenv.env['GEMINI_API_KEY']!,
          'modelName': 'text-embedding-004',
        },
      );

      // Only save if ALL embeddings succeeded
      if (vectorChunks.length != chunks.length) {
        debugPrint(
          'Partial embedding failure: ${vectorChunks.length}/${chunks.length} chunks embedded',
        );
        debugPrint('Aborting indexing to maintain retrieval quality');
        return;
      }

      _vectorStore[documentId] = vectorChunks;
      await _saveCachedEmbeddings(documentId);
    } catch (e) {
      debugPrint('Indexing failed completely: $e');
      rethrow;
    }
  }

  /// Index document in batches - also uses isolate for embeddings
  Future<void> indexDocumentBatch(
    String documentId,
    List<Map<String, dynamic>> chunks,
  ) async {
    if (!_isInitialized) await initialize();

    try {
      // Generate embeddings in background isolate (same as indexDocument)
      final startIndex = _vectorStore[documentId]?.length ?? 0;
      
      final vectorChunks = await compute(
        _generateEmbeddingsInBackground,
        {
          'chunks': chunks,
          'documentId': documentId,
          'apiKey': dotenv.env['GEMINI_API_KEY']!,
          'modelName': 'text-embedding-004',
          'startIndex': startIndex,
        },
      );

      // Only append if ALL batch embeddings succeeded
      if (vectorChunks.length != chunks.length) {
        debugPrint(
          'Partial batch embedding failure: ${vectorChunks.length}/${chunks.length}',
        );
        debugPrint('Aborting batch indexing to maintain retrieval quality');
        return;
      }

      _vectorStore.putIfAbsent(documentId, () => []);
      _vectorStore[documentId]!.addAll(vectorChunks);

      await _saveCachedEmbeddings(documentId);
    } catch (e) {
      debugPrint('Batch indexing failed: $e');
      rethrow;
    }
  }

  /// Background isolate function for generating real Gemini embeddings
  static Future<List<VectorChunk>> _generateEmbeddingsInBackground(
    Map<String, dynamic> params,
  ) async {
    final chunks = params['chunks'] as List<Map<String, dynamic>>;
    final documentId = params['documentId'] as String;
    final apiKey = params['apiKey'] as String;
    final modelName = params['modelName'] as String;
    final startIndex = params['startIndex'] as int? ?? 0;

    // Create GenerativeModel INSIDE the isolate (cannot be passed across isolates)
    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
    );

    final vectorChunks = <VectorChunk>[];

    for (var i = 0; i < chunks.length; i++) {
      try {
        final chunk = chunks[i];
        final content = chunk['content'] as String;
        final metadata = chunk['metadata'] as Map<String, dynamic>? ?? {};

        // Generate REAL embedding using Gemini API
        final contentObj = Content.text(content);
        final result = await model.embedContent(contentObj);
        final embedding = result.embedding.values;

        vectorChunks.add(
          VectorChunk(
            id: '${documentId}_chunk_${startIndex + i}',
            content: content,
            embedding: embedding,
            metadata: metadata,
          ),
        );
      } catch (e) {
        debugPrint('Failed to embed chunk $i: $e');
        // Break on first failure to reject partial results
        break;
      }
    }

    return vectorChunks;
  }

  /// Retrieve the most relevant chunks for a given query
  Future<List<Map<String, dynamic>>> retrieveRelevantContext(
    String query, {
    int topK = 5,
    String? documentId,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final queryEmbedding = await _generateEmbedding(query);
      if (queryEmbedding == null) return [];

      final allChunks = documentId != null
          ? (_vectorStore[documentId] ?? [])
          : _vectorStore.values.expand((chunks) => chunks).toList();

      if (allChunks.isEmpty) return [];

      // 🔥 SAFE isolate transfer (Map only)
      final lightData = allChunks.map((c) {
        return {
          'id': c.id,
          'embedding': c.embedding,
        };
      }).toList();

      // Run isolate compute
      final scoredIds = await compute(_similarityWorker, {
        'vectors': lightData,
        'query': queryEmbedding,
        'topK': topK,
      });

      // Rebuild mapping on main thread
      final chunkMap = {for (var c in allChunks) c.id: c};

      return scoredIds.map((item) {
        final chunk = chunkMap[item['id']];
        if (chunk == null) return null;

        return {
          'content': chunk.content,
          'metadata': chunk.metadata,
          'similarity': item['score'],
        };
      }).whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Retrieval failed: $e');
      return [];
    }
  }

  /// Check if a document is indexed
  bool isDocumentIndexed(String documentId) {
    return _vectorStore.containsKey(documentId) &&
        _vectorStore[documentId]!.isNotEmpty;
  }

  /// Clear embeddings for a specific document
  Future<void> clearDocument(String documentId) async {
    _vectorStore.remove(documentId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vector_chunks_$documentId');
  }

  /// Generate embedding for a text string
  Future<List<double>?> _generateEmbedding(String text) async {
    try {
      final content = Content.text(text);
      final result = await _embeddingModel.embedContent(content);
      return result.embedding.values;
    } catch (e) {
      debugPrint('Embedding generation error: $e');
      return null;
    }
  }

  /// Save embeddings to persistent storage
  Future<void> _saveCachedEmbeddings(String documentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chunks = _vectorStore[documentId];
      if (chunks == null) return;

      final serialized = chunks.map((c) => c.toJson()).toList();
      await prefs.setString(
        'vector_chunks_$documentId',
        jsonEncode(serialized),
      );
    } catch (e) {
      debugPrint('Failed to save embeddings: $e');
    }
  }

  /// Load cached embeddings from persistent storage
  Future<void> _loadCachedEmbeddings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((k) => k.startsWith('vector_chunks_'));

      for (final key in keys) {
        final documentId = key.replaceFirst('vector_chunks_', '');
        final data = prefs.getString(key);
        if (data != null) {
          final List<dynamic> serialized = jsonDecode(data);
          _vectorStore[documentId] =
              serialized.map((json) => VectorChunk.fromJson(json)).toList();
        }
      }

      debugPrint('Loaded embeddings for ${_vectorStore.length} documents');
    } catch (e) {
      debugPrint('Failed to load cached embeddings: $e');
    }
  }
}

/// Represents a text chunk with its embedding vector
class VectorChunk {
  final String id;
  final String content;
  final List<double> embedding;
  final Map<String, dynamic> metadata;

  VectorChunk({
    required this.id,
    required this.content,
    required this.embedding,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'embedding': embedding,
        'metadata': metadata,
      };

  factory VectorChunk.fromJson(Map<String, dynamic> json) => VectorChunk(
        id: json['id'] as String,
        content: json['content'] as String,
        embedding: (json['embedding'] as List).cast<double>(),
        metadata: json['metadata'] as Map<String, dynamic>,
      );
}

//
// 🔥 GLOBAL WORKER FUNCTIONS (SAFE FOR ISOLATES)
// ---------------------------------------------

List<Map<String, dynamic>> _similarityWorker(Map<String, dynamic> params) {
  final vectors = (params['vectors'] as List).cast<Map<String, dynamic>>();
  final query = (params['query'] as List).cast<double>();
  final topK = params['topK'] as int;

  final scored = vectors.map((v) {
    final id = v['id'] as String;
    final embedding = (v['embedding'] as List).cast<double>();

    return {
      'id': id,
      'score': _cosineMath(query, embedding),
    };
  }).toList();

  scored.sort(
    (a, b) => (b['score'] as double).compareTo(a['score'] as double),
  );

  return scored.take(topK).toList();
}

double _cosineMath(List<double> a, List<double> b) {
  if (a.length != b.length) return 0.0;

  double dot = 0.0, normA = 0.0, normB = 0.0;

  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  if (normA == 0 || normB == 0) return 0.0;

  return dot / (sqrt(normA) * sqrt(normB));
}
