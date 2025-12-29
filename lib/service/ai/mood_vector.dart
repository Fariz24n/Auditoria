  import 'dart:math';
  import 'package:flutter/foundation.dart';

  /// Numerical representation of emotional state for smoothing and analysis
  class MoodVector {
    final double valence;    // -1.0 (negative) to +1.0 (positive)
    final double arousal;    // 0.0 (calm) to 1.0 (intense)
    final double tension;    // 0.0 (relaxed) to 1.0 (suspenseful)
    final String primaryMood;
    final int pageNumber;

    const MoodVector({
      required this.valence,
      required this.arousal,
      required this.tension,
      required this.primaryMood,
      required this.pageNumber,
    });

    /// Create MoodVector from legacy theme string
    factory MoodVector.fromTheme(String theme, int pageNumber) {
      switch (theme.toLowerCase()) {
        case 'happy':
          return MoodVector(
            valence: 0.7,
            arousal: 0.6,
            tension: 0.2,
            primaryMood: 'happy',
            pageNumber: pageNumber,
          );
        case 'calming':
          return MoodVector(
            valence: 0.3,
            arousal: 0.2,
            tension: 0.1,
            primaryMood: 'calming',
            pageNumber: pageNumber,
          );
        case 'thrill':
          return MoodVector(
            valence: -0.2,
            arousal: 0.9,
            tension: 0.9,
            primaryMood: 'thrill',
            pageNumber: pageNumber,
          );
        case 'tense':
          return MoodVector(
            valence: -0.1,
            arousal: 0.5,
            tension: 0.7,
            primaryMood: 'tense',
            pageNumber: pageNumber,
          );
        case 'melancholic':
          return MoodVector(
            valence: -0.5,
            arousal: 0.3,
            tension: 0.4,
            primaryMood: 'melancholic',
            pageNumber: pageNumber,
          );
        case 'battle':
          return MoodVector(
            valence: 0.2,
            arousal: 0.95,
            tension: 0.8,
            primaryMood: 'battle',
            pageNumber: pageNumber,
          );
        default:
          // NO MORE CALMING DEFAULT - Use neutral/tense instead
          debugPrint('⚠️ [MoodVector] Unknown theme "$theme", using tense as neutral');
          return MoodVector(
            valence: 0.0,
            arousal: 0.4,
            tension: 0.5,
            primaryMood: 'tense',
            pageNumber: pageNumber,
          );
      }
    }

    /// Compute cosine similarity between two mood vectors
    double similarity(MoodVector other) {
      final a = [valence, arousal, tension];
      final b = [other.valence, other.arousal, other.tension];

      double dot = 0.0, normA = 0.0, normB = 0.0;

      for (int i = 0; i < a.length; i++) {
        dot += a[i] * b[i];
        normA += a[i] * a[i];
        normB += b[i] * b[i];
      }

      if (normA == 0 || normB == 0) return 0.0;

      return dot / (sqrt(normA) * sqrt(normB));
    }

    /// Apply exponential moving average smoothing
    /// 
    /// [current] - Current page's raw mood
    /// [history] - Previous mood vectors (up to 5)
    /// [alpha] - Weight for current mood (0.0-1.0)
    ///           0.3 = gentle smoothing
    ///           0.5 = balanced
    ///           0.7 = responsive to changes
    static MoodVector smooth(
      MoodVector current,
      List<MoodVector> history, {
      double alpha = 0.4,
    }) {
      if (history.isEmpty) return current;

      // ENFORCE: No long emotional memory allowed - max 2 history items
      assert(history.length <= 5, 'History length should not exceed 5');
      
      // ADAPTIVE SMOOTHING: Bypass smoothing for extreme emotions
      // If current mood is battle or thrill, preserve it
      if (current.primaryMood == 'battle' || current.primaryMood == 'thrill') {
        debugPrint('🔥 [SMOOTHING] EXTREME emotion detected (${current.primaryMood}). BYPASSING smoothing entirely.');
        return current;
      }
      
      // If transitioning FROM calm TO extreme, favor the extreme
      final lastMood = history.last;
      if ((lastMood.primaryMood == 'calming' || lastMood.primaryMood == 'happy') &&
          (current.primaryMood == 'battle' || current.primaryMood == 'thrill' || current.primaryMood == 'tense')) {
        debugPrint('🔥 [SMOOTHING] Emotional shift detected (${lastMood.primaryMood} → ${current.primaryMood}). Using higher alpha (0.8).');
        alpha = 0.8;  // Give MORE weight to current emotion
      }
      
      // Limit history to prevent over-smoothing - only last 2 moods
      final recentHistory = history.length > 2 ? history.sublist(history.length - 2) : history;

      // Compute weighted average
      double smoothedValence = current.valence * alpha;
      double smoothedArousal = current.arousal * alpha;
      double smoothedTension = current.tension * alpha;

      final historyWeight = (1.0 - alpha) / recentHistory.length;

      for (final past in recentHistory) {
        smoothedValence += past.valence * historyWeight;
        smoothedArousal += past.arousal * historyWeight;
        smoothedTension += past.tension * historyWeight;
      }

      final smoothed = MoodVector(
        valence: smoothedValence.clamp(-1.0, 1.0),
        arousal: smoothedArousal.clamp(0.0, 1.0),
        tension: smoothedTension.clamp(0.0, 1.0),
        primaryMood: _mapToMood(smoothedValence, smoothedArousal, smoothedTension),
        pageNumber: current.pageNumber,
      );
      
      debugPrint('📊 [SMOOTHING] ${current.primaryMood} → ${smoothed.primaryMood} (alpha=$alpha)');
      return smoothed;
    }

    /// Map valence/arousal coordinates to mood descriptor
    /// Based on Russell's Circumplex Model of Affect
    static String _mapToMood(double valence, double arousal, [double? tension]) {
      // Emotion zone detection
      final isPositiveZone = valence > 0.0;
      final isNegativeZone = valence < -0.2;
      
      // Tension-based detection (if provided) - WITH GUARDS
      // High tension requires negative context for thrill
      if (tension != null && tension > 0.7 && arousal > 0.6 && isNegativeZone) return 'thrill';
      if (tension != null && tension > 0.6 && !isPositiveZone) return 'tense';
      
      // High arousal detection (priority) - WITH GUARDS
      // Very high arousal without positive valence = battle
      if (arousal > 0.8 && !isPositiveZone) return 'battle';
      // High arousal with negative valence = thrill
      if (arousal > 0.7 && isNegativeZone) return 'thrill';
      
      // Valence + Arousal quadrants (Russell's Circumplex)
      // Positive + High Arousal = Happy
      if (valence > 0.3 && arousal > 0.5) return 'happy';
      // Negative + High Arousal = Thrill (with guard)
      if (valence < -0.3 && arousal > 0.5) return 'thrill';
      // Negative + Low Arousal = Melancholic
      if (valence < -0.3 && arousal < 0.4) return 'melancholic';
      
      // Calming ONLY if explicitly low arousal AND positive valence
      if (valence > 0.2 && arousal < 0.3) return 'calming';
      
      // Neutral zone handling
      if (valence >= -0.1 && valence <= 0.2 && arousal > 0.4) return 'happy';
      
      // Default to tense (uncertainty) rather than calming
      return 'tense';
    }

    /// Convert smoothed mood back to music theme
    /// Convert smoothed mood back to music theme
    String toMusicTheme() {
      final isPositiveZone = valence > 0.2;
      final isNegativeZone = valence < -0.3;

      // PRIORITY 1: THRILL
      // Only when ALL signals align (high threat, high tension, high arousal)
      if (isNegativeZone && tension > 0.7 && arousal > 0.7) {
        return 'thrill';
      }

      // PRIORITY 2: BATTLE
      // Intense action but NOT emotional panic
      if (isNegativeZone && arousal > 0.8 && tension > 0.5) {
        return 'battle';
      }

      // PRIORITY 3: TENSE
      // Anticipation, pressure, uncertainty
      if (!isPositiveZone && tension > 0.6) {
        return 'tense';
      }

      // PRIORITY 4: HAPPY
      // Positive energy (moved up to block thrill leakage)
      if (valence > 0.3 && arousal > 0.4) {
        return 'happy';
      }

      // PRIORITY 5: MELANCHOLIC
      // Negative but low activity
      if (isNegativeZone && arousal < 0.4) {
        return 'melancholic';
      }

      // PRIORITY 6: CALMING (explicit only)
      if (valence > 0.2 && arousal < 0.3 && tension < 0.3) {
        debugPrint(
          '✅ [toMusicTheme] Explicit CALMING (v=${valence.toStringAsFixed(2)}, '
          'a=${arousal.toStringAsFixed(2)}, t=${tension.toStringAsFixed(2)})',
        );
        return 'calming';
      }

      // NEUTRAL / TRANSITIONAL ZONE
      if (valence >= -0.1 && valence <= 0.2) {
        if (arousal > 0.4) return 'happy';
        return 'tense';
      }

      // FINAL SAFE DEFAULT
      debugPrint('⚠️ [toMusicTheme] No clear theme. Using tense as conservative default.');
      return 'tense';
    }

    @override
    String toString() =>
        'MoodVector(page=$pageNumber, mood=$primaryMood, v=${valence.toStringAsFixed(2)}, a=${arousal.toStringAsFixed(2)}, t=${tension.toStringAsFixed(2)})';
  }
