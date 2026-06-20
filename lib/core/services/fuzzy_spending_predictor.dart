import 'package:pocket_plan/models/transaction_model.dart';

// ═══════════════════════════════════════════════════════════
// FUZZY LOGIC SPENDING PREDICTOR
//
// Implements a Mamdani-style fuzzy inference system (FIS) to
// forecast a student's spending for the next month and for
// the following six months, based on:
//   - Recent spending TREND   (Decreasing / Stable / Increasing)
//   - Spending VOLATILITY     (Low / Medium / High)
//   - Budget UTILIZATION      (Low / Moderate / High)
//
// The FIS outputs a fuzzy ADJUSTMENT FACTOR applied on top of
// the historical average monthly spending, producing a final
// crisp predicted amount via the centroid (Mamdani) method,
// together with a confidence score reflecting how clear-cut
// the fuzzy memberships were for that prediction.
// ═══════════════════════════════════════════════════════════

class FuzzyForecastResult {
  final double predictedAmount;
  final double confidenceScore; // 0-100%
  final String trendLabel;
  final String volatilityLabel;
  final String utilizationLabel;
  final double adjustmentFactor; // e.g. +0.18 means +18%

  FuzzyForecastResult({
    required this.predictedAmount,
    required this.confidenceScore,
    required this.trendLabel,
    required this.volatilityLabel,
    required this.utilizationLabel,
    required this.adjustmentFactor,
  });
}

class FuzzySpendingPredictor {
  // ─────────────────────────────────────────
  // PUBLIC ENTRY POINT — 1 month forecast
  // ─────────────────────────────────────────
  static FuzzyForecastResult predictNextMonth({
    required List<TransactionModel> transactions,
    required double currentMonthLimit,
    int monthsOfHistory = 6,
  }) {
    final monthlyTotals = _aggregateByMonth(transactions, monthsOfHistory);

    if (monthlyTotals.isEmpty) {
      return FuzzyForecastResult(
        predictedAmount: 0,
        confidenceScore: 0,
        trendLabel: 'Insufficient data',
        volatilityLabel: 'Insufficient data',
        utilizationLabel: 'Insufficient data',
        adjustmentFactor: 0,
      );
    }

    final average = _average(monthlyTotals);
    final trendSlope = _trendSlope(monthlyTotals);
    final volatility = _coefficientOfVariation(monthlyTotals, average);
    final double utilization = currentMonthLimit > 0
        ? (monthlyTotals.last / currentMonthLimit)
        : 0;

    return _runInference(
      historicalAverage: average,
      trendSlope: trendSlope,
      volatility: volatility,
      utilization: utilization,
    );
  }

  // ─────────────────────────────────────────
  // PUBLIC ENTRY POINT — 6 month forecast
  // Recursively rolls the fuzzy output of month N into the
  // trend input of month N+1, widening uncertainty over time.
  // ─────────────────────────────────────────
  static List<FuzzyForecastResult> predictSixMonths({
    required List<TransactionModel> transactions,
    required double currentMonthLimit,
    int monthsOfHistory = 6,
  }) {
    final results = <FuzzyForecastResult>[];
    final monthlyTotals = _aggregateByMonth(transactions, monthsOfHistory);

    if (monthlyTotals.isEmpty) {
      return List.generate(
        6,
        (_) => FuzzyForecastResult(
          predictedAmount: 0,
          confidenceScore: 0,
          trendLabel: 'Insufficient data',
          volatilityLabel: 'Insufficient data',
          utilizationLabel: 'Insufficient data',
          adjustmentFactor: 0,
        ),
      );
    }

    // Working copy of history that grows with each simulated month
    final workingHistory = List<double>.from(monthlyTotals);
    double workingLimit = currentMonthLimit;

    for (int month = 1; month <= 6; month++) {
      final average = _average(workingHistory);
      final trendSlope = _trendSlope(workingHistory);
      final volatility = _coefficientOfVariation(workingHistory, average);
      final double utilization = workingLimit > 0
          ? (workingHistory.last / workingLimit)
          : 0;

      // Confidence naturally decays the further out the forecast goes,
      // reflecting accumulating uncertainty over a longer horizon.
      final horizonDecay = 1.0 - (month - 1) * 0.08;

      final result = _runInference(
        historicalAverage: average,
        trendSlope: trendSlope,
        volatility: volatility,
        utilization: utilization,
        confidenceMultiplier: horizonDecay.clamp(0.4, 1.0),
      );

      results.add(result);

      // Feed this month's predicted amount back into history so the
      // next iteration's trend/volatility reflects the simulated path
      workingHistory.add(result.predictedAmount);
      if (workingHistory.length > monthsOfHistory) {
        workingHistory.removeAt(0);
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════
  // FUZZY INFERENCE CORE
  // ═══════════════════════════════════════════════════════════
  static FuzzyForecastResult _runInference({
    required double historicalAverage,
    required double trendSlope,
    required double volatility,
    required double utilization,
    double confidenceMultiplier = 1.0,
  }) {
    // ── 1. FUZZIFICATION ──
    // Trend: slope as a fraction of the average (-1 to +1 range typical)
    final double trendRatio = historicalAverage > 0
        ? trendSlope / historicalAverage
        : 0;
    final trendMembership = _fuzzifyTrend(trendRatio);

    final volatilityMembership = _fuzzifyVolatility(volatility);

    final utilizationMembership = _fuzzifyUtilization(utilization);

    // ── 2. RULE EVALUATION (Mamdani min for AND) ──
    // Each rule produces a firing strength and an associated
    // output adjustment label (Decrease / Stable / Increase),
    // mapped to a representative crisp adjustment value used
    // in the weighted centroid defuzzification below.
    final rules = <_FuzzyRule>[
      // Increasing trend rules
      _FuzzyRule(
        strength: _min([trendMembership.increasing, volatilityMembership.low]),
        outputValue: 0.22, // strong, confident increase
      ),
      _FuzzyRule(
        strength: _min([
          trendMembership.increasing,
          volatilityMembership.medium,
        ]),
        outputValue: 0.15,
      ),
      _FuzzyRule(
        strength: _min([trendMembership.increasing, volatilityMembership.high]),
        outputValue: 0.10, // less confident due to high volatility
      ),

      // Stable trend rules
      _FuzzyRule(
        strength: _min([
          trendMembership.stable,
          utilizationMembership.moderate,
        ]),
        outputValue: 0.0,
      ),
      _FuzzyRule(
        strength: _min([trendMembership.stable, utilizationMembership.high]),
        outputValue: 0.05,
      ),
      _FuzzyRule(
        strength: _min([trendMembership.stable, utilizationMembership.low]),
        outputValue: -0.05,
      ),

      // Decreasing trend rules
      _FuzzyRule(
        strength: _min([trendMembership.decreasing, volatilityMembership.low]),
        outputValue: -0.15,
      ),
      _FuzzyRule(
        strength: _min([
          trendMembership.decreasing,
          volatilityMembership.medium,
        ]),
        outputValue: -0.10,
      ),
      _FuzzyRule(
        strength: _min([trendMembership.decreasing, volatilityMembership.high]),
        outputValue: -0.05,
      ),

      // High utilization warning rules — even with a stable/decreasing
      // trend, a high utilization ratio nudges the forecast upward,
      // since the student is already close to or over their limit
      _FuzzyRule(
        strength: _min([utilizationMembership.high, trendMembership.stable]),
        outputValue: 0.08,
      ),
    ];

    // ── 3. DEFUZZIFICATION (Weighted Average / Centroid Method) ──
    double weightedSum = 0;
    double totalWeight = 0;
    for (final rule in rules) {
      weightedSum += rule.strength * rule.outputValue;
      totalWeight += rule.strength;
    }

    final adjustmentFactor = totalWeight > 0 ? weightedSum / totalWeight : 0.0;
    final predictedAmount = (historicalAverage * (1 + adjustmentFactor)).clamp(
      0,
      double.infinity,
    );

    // ── 4. CONFIDENCE SCORE ──
    // Confidence reflects how strongly the rules fired overall
    // (higher total weight = clearer membership = more confident),
    // scaled down by the horizon decay factor for multi-month forecasts.
    final ruleClarity = (totalWeight / rules.length).clamp(0, 1);
    final confidence = (ruleClarity * 100 * confidenceMultiplier).clamp(0, 100);

    return FuzzyForecastResult(
      predictedAmount: predictedAmount.toDouble(),
      confidenceScore: confidence.toDouble(),
      trendLabel: trendMembership.dominantLabel,
      volatilityLabel: volatilityMembership.dominantLabel,
      utilizationLabel: utilizationMembership.dominantLabel,
      adjustmentFactor: adjustmentFactor.toDouble(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MEMBERSHIP FUNCTIONS (triangular fuzzy sets)
  // ═══════════════════════════════════════════════════════════

  // Trend ratio: negative = decreasing, ~0 = stable, positive = increasing
  static _TrendMembership _fuzzifyTrend(double ratio) {
    final decreasing = _triangular(ratio, -1.0, -0.5, 0.0);
    final stable = _triangular(ratio, -0.15, 0.0, 0.15);
    final increasing = _triangular(ratio, 0.0, 0.5, 1.0);
    return _TrendMembership(decreasing, stable, increasing);
  }

  // Volatility: coefficient of variation (std dev / mean)
  static _VolatilityMembership _fuzzifyVolatility(double cv) {
    final low = _triangular(cv, 0.0, 0.0, 0.25);
    final medium = _triangular(cv, 0.10, 0.30, 0.50);
    final high = _triangular(cv, 0.35, 0.6, 1.0);
    return _VolatilityMembership(low, medium, high);
  }

  // Utilization: spent / limit ratio for the most recent month
  static _UtilizationMembership _fuzzifyUtilization(double ratio) {
    final low = _triangular(ratio, 0.0, 0.0, 0.5);
    final moderate = _triangular(ratio, 0.3, 0.7, 1.0);
    final high = _triangular(ratio, 0.8, 1.2, 1.6);
    return _UtilizationMembership(low, moderate, high);
  }

  // Standard triangular membership function
  static double _triangular(double x, double a, double b, double c) {
    if (x <= a || x >= c) return 0.0;
    if (x == b) return 1.0;
    if (x < b) return (x - a) / (b - a);
    return (c - x) / (c - b);
  }

  static double _min(List<double> values) =>
      values.reduce((a, b) => a < b ? a : b);

  // ═══════════════════════════════════════════════════════════
  // STATISTICAL HELPERS
  // ═══════════════════════════════════════════════════════════

  static List<double> _aggregateByMonth(
    List<TransactionModel> transactions,
    int monthsOfHistory,
  ) {
    final Map<String, double> totals = {};

    for (final tx in transactions) {
      if (tx.type != TransactionType.expense) continue;
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      totals[key] = (totals[key] ?? 0) + tx.amount;
    }

    final sortedKeys = totals.keys.toList()..sort();
    final recentKeys = sortedKeys.length > monthsOfHistory
        ? sortedKeys.sublist(sortedKeys.length - monthsOfHistory)
        : sortedKeys;

    return recentKeys.map((k) => totals[k]!).toList();
  }

  static double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // Simple linear regression slope (least squares) over the
  // monthly totals, used as the trend indicator
  static double _trendSlope(List<double> values) {
    if (values.length < 2) return 0;
    final n = values.length;
    final xValues = List.generate(n, (i) => i.toDouble());
    final xMean = _average(xValues);
    final yMean = _average(values);

    double numerator = 0;
    double denominator = 0;
    for (int i = 0; i < n; i++) {
      numerator += (xValues[i] - xMean) * (values[i] - yMean);
      denominator += (xValues[i] - xMean) * (xValues[i] - xMean);
    }
    return denominator != 0 ? numerator / denominator : 0;
  }

  // Coefficient of variation = standard deviation / mean
  // Used as the volatility measure
  static double _coefficientOfVariation(List<double> values, double mean) {
    if (values.length < 2 || mean == 0) return 0;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    final stdDev = variance > 0 ? _sqrt(variance) : 0;
    return stdDev / mean;
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }
}

// ─────────────────────────────────────────
// INTERNAL HELPER CLASSES
// ─────────────────────────────────────────
class _FuzzyRule {
  final double strength;
  final double outputValue;
  _FuzzyRule({required this.strength, required this.outputValue});
}

class _TrendMembership {
  final double decreasing;
  final double stable;
  final double increasing;
  _TrendMembership(this.decreasing, this.stable, this.increasing);

  String get dominantLabel {
    if (increasing >= stable && increasing >= decreasing) return 'Increasing';
    if (decreasing >= stable && decreasing >= increasing) return 'Decreasing';
    return 'Stable';
  }
}

class _VolatilityMembership {
  final double low;
  final double medium;
  final double high;
  _VolatilityMembership(this.low, this.medium, this.high);

  String get dominantLabel {
    if (high >= medium && high >= low) return 'High';
    if (medium >= low && medium >= high) return 'Medium';
    return 'Low';
  }
}

class _UtilizationMembership {
  final double low;
  final double moderate;
  final double high;
  _UtilizationMembership(this.low, this.moderate, this.high);

  String get dominantLabel {
    if (high >= moderate && high >= low) return 'High';
    if (moderate >= low && moderate >= high) return 'Moderate';
    return 'Low';
  }
}
