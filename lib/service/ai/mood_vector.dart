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

    /// Emotion Zone Detection (heuristic keywords → numeric biases)
    /// Returns numeric-only deltas for valence, arousal, tension.
    /// This is a guardrail signal and NEVER selects themes.
    static (_ZoneBias, _ZoneCounts) _computeEmotionZoneBias(String text) {
      final lower = text.toLowerCase();

      // EMOTION ZONE DETECTION: Novel-style narrative cues
      final positiveKeywords = ['warmth','smile','laughed','laughter','gentle','together','close','familiar','shared','safe'];
      final negativeKeywords = ['darkness','threat','danger','blood','fear','shadowed','loomed','closed in','trapped','cornered'];

      // Battle indicators (descriptive action)
      final battleKeywords = ['blade','steel','strike','thrust','slash','clash','wound','blood','charge','retreat'];
      // Thrill / Fear indicators (loss of control, fast tempo)
      final thrillKeywords = ['sudden','burst','crash','slam','chase','fled','panic','no time','heart raced','breath hitched'];
      // Tense / Anticipation indicators (waiting, hesitation)
      final tenseKeywords = ['paused','waited','hesitated','listened','footsteps','knock','creak','held breath','watched','uncertain'];
      // Melancholic indicators (quiet loss)
      final melancholicKeywords = ['empty','silent room','alone','left behind','memory','faded','echo','absence','regret','lingered'];
      // Happy / Light indicators (soft positivity)
      final happyKeywords = ['laughed softly','smiled','light','bright','relief','comfort','ease','content','peaceful','warm'];
      // Calming indicators (environment & slow tempo)
      final calmingKeywords = ['breeze','dusk','dawn','twilight','moonlight','still','silence','river','shore','settled'];

      int _count(List<String> kws) => kws.where((k) => lower.contains(k)).length;

      final counts = _ZoneCounts(
        positive: _count(positiveKeywords),
        negative: _count(negativeKeywords),
        battle: _count(battleKeywords),
        thrill: _count(thrillKeywords),
        tense: _count(tenseKeywords),
        melancholic: _count(melancholicKeywords),
        happy: _count(happyKeywords),
        calming: _count(calmingKeywords),
      );

      // Normalize counts to strengths [0..1] using soft cap
      double _w(int c, {int cap = 3}) => c <= 0 ? 0.0 : (c / cap).clamp(0.0, 1.0);

      final wPositive = _w(counts.positive);
      final wNegative = _w(counts.negative);
      final wBattle = _w(counts.battle);
      final wThrill = _w(counts.thrill);
      final wTense = _w(counts.tense);
      final wMelancholic = _w(counts.melancholic);
      final wHappy = _w(counts.happy);
      final wCalming = _w(counts.calming);

      // Compute numeric-only biases; keep caps modest to avoid drift.
      // Note: We intentionally keep calming/thrill biases constrained.
      double valenceBias = 0.0;
      double arousalBias = 0.0;
      double tensionBias = 0.0;

      // Valence
      valenceBias += 0.22 * wPositive;
      valenceBias += 0.24 * wHappy;
      valenceBias += 0.08 * wCalming;    // small, avoid new calming bias
      valenceBias -= 0.26 * wNegative;
      valenceBias -= 0.12 * wBattle;     // action intensity often reduces valence
      valenceBias -= 0.16 * wThrill;     // fear/uncertainty lowers valence
      valenceBias -= 0.28 * wMelancholic;

      // Arousal
      arousalBias += 0.26 * wBattle;
      arousalBias += 0.30 * wThrill;     // fast tempo, urgency
      arousalBias += 0.16 * wTense;      // anticipation
      arousalBias += 0.10 * wHappy;
      arousalBias -= 0.18 * wCalming;    // environment quiets tempo
      arousalBias -= 0.10 * wMelancholic;

      // Tension
      tensionBias += 0.22 * wBattle;
      tensionBias += 0.26 * wThrill;
      tensionBias += 0.28 * wTense;
      tensionBias += 0.10 * wNegative;
      tensionBias -= 0.18 * wCalming;    // explicit calming reduces tension
      tensionBias -= 0.06 * wPositive;   // soft positivity slightly reduces tension

      // Overall signal strength used internally for guardrail scaling
      final total = counts.total;
      final signalStrength = (total / 8.0).clamp(0.0, 1.0);

      final bias = _ZoneBias(
        valenceDelta: valenceBias.clamp(-0.35, 0.35),
        arousalDelta: arousalBias.clamp(-0.35, 0.35),
        tensionDelta: tensionBias.clamp(-0.35, 0.35),
        strength: signalStrength,
      );

      return (bias, counts);
    }

    /// Factory to combine AI-derived mood with Emotion Zone guardrails.
    /// - Accepts raw page text for heuristic counting.
    /// - Blends numeric deltas without overriding AI themes.
    /// - Returns standard MoodVector (numbers only + mapped `primaryMood`).
    static MoodVector fromTextWithEmotionZones(
      String text, {
      required int pageNumber,
      MoodVector? aiVector,
    }) {
      // Base vector: AI result if available, else conservative neutral/tense
      final base = aiVector ?? MoodVector(
        valence: 0.0,
        arousal: 0.4,
        tension: 0.5,
        primaryMood: 'tense',
        pageNumber: pageNumber,
      );

      final (bias, counts) = _computeEmotionZoneBias(text);

      // Guardrail alpha: stronger when AI is neutral/ambiguous, weaker when confident.
      double alpha = 0.3;

      final isNeutralValence = base.valence >= -0.1 && base.valence <= 0.2;
      final isMidArousal = base.arousal >= 0.3 && base.arousal <= 0.6;

      if (isNeutralValence && isMidArousal) {
        alpha = 0.6; // allow stronger correction when AI is neutral
      }

      // If AI indicates extreme action, reduce heuristic influence
      if (base.primaryMood == 'battle' || base.primaryMood == 'thrill') {
        alpha = 0.15;
      }

      // If AI says calming/happy but zones indicate danger, favor correction
      final dangerScore = counts.battle + counts.thrill + counts.tense + counts.negative;
      final softScore = counts.happy + counts.calming + counts.positive + counts.melancholic;
      if ((base.primaryMood == 'calming' || base.primaryMood == 'happy') && dangerScore > softScore) {
        alpha = 0.7; // stabilize against off-path positivity
      }

      // Blend biases numerically; maintain clamps to avoid drift.
      final newValence = (base.valence + alpha * bias.valenceDelta).clamp(-1.0, 1.0);
      final newArousal = (base.arousal + alpha * bias.arousalDelta).clamp(0.0, 1.0);
      final newTension = (base.tension + alpha * bias.tensionDelta).clamp(0.0, 1.0);

      final mood = _mapToMood(newValence, newArousal, newTension);

      debugPrint(
        '🛡️ [EmotionZone] counts=${counts.toString()} | strength=${bias.strength.toStringAsFixed(2)} | '
        'alpha=${alpha.toStringAsFixed(2)} | base=${base.primaryMood} → mapped=$mood',
      );

      return MoodVector(
        valence: newValence,
        arousal: newArousal,
        tension: newTension,
        primaryMood: mood,
        pageNumber: pageNumber,
      );
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

  /// Private struct-like holder for numeric emotion zone deltas
  class _ZoneBias {
    final double valenceDelta;
    final double arousalDelta;
    final double tensionDelta;
    final double strength; // 0..1 signal strength
    const _ZoneBias({
      required this.valenceDelta,
      required this.arousalDelta,
      required this.tensionDelta,
      required this.strength,
    });
  }

  /// Private struct-like holder for keyword counts (debug + scaling)
  class _ZoneCounts {
    final int positive;
    final int negative;
    final int battle;
    final int thrill;
    final int tense;
    final int melancholic;
    final int happy;
    final int calming;

    const _ZoneCounts({
      required this.positive,
      required this.negative,
      required this.battle,
      required this.thrill,
      required this.tense,
      required this.melancholic,
      required this.happy,
      required this.calming,
    });

    int get total => positive + negative + battle + thrill + tense + melancholic + happy + calming;

    @override
    String toString() =>
        'pos=$positive neg=$negative battle=$battle thrill=$thrill tense=$tense mel=$melancholic happy=$happy calm=$calming';
  }
