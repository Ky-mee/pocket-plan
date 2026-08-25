import 'package:pocket_plan/models/transaction_model.dart';

// ═══════════════════════════════════════════════════════════
// FUZZY FORECAST RESULT — single month output
// ═══════════════════════════════════════════════════════════
class FuzzyForecastResult {
  final double predictedAmount;
  final double confidenceScore;
  final String trendLabel;
  final String volatilityLabel;
  final String utilizationLabel;
  final double adjustmentFactor;

  // ── Per-category breakdown ──
  final double predictedCommitments;
  final double predictedSpending;
  final double predictedSavings;

  FuzzyForecastResult({
    required this.predictedAmount,
    required this.confidenceScore,
    required this.trendLabel,
    required this.volatilityLabel,
    required this.utilizationLabel,
    required this.adjustmentFactor,
    this.predictedCommitments = 0,
    this.predictedSpending = 0,
    this.predictedSavings = 0,
  });
}

// ═══════════════════════════════════════════════════════════
// FUZZY SPENDING PREDICTOR
// Mamdani-style FIS with per-bucket category breakdown
// ═══════════════════════════════════════════════════════════
class FuzzySpendingPredictor {
  // ─────────────────────────────────────────
  // PUBLIC: 1-month forecast
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
        predictedCommitments: 0,
        predictedSpending: 0,
        predictedSavings: 0,
      );
    }

    final average = _average(monthlyTotals);
    final trendSlope = _trendSlope(monthlyTotals);
    final volatility = _coefficientOfVariation(monthlyTotals, average);
    final double utilization = currentMonthLimit > 0
        ? (monthlyTotals.last / currentMonthLimit)
        : 0.0;

    // ── Per-bucket totals ──
    final commitmentTotals = _aggregateByMonthAndBucket(
      transactions,
      monthsOfHistory,
      'commitment',
    );
    final spendingTotals = _aggregateByMonthAndBucket(
      transactions,
      monthsOfHistory,
      'spending',
    );
    final savingsTotals = _aggregateByMonthAndBucket(
      transactions,
      monthsOfHistory,
      'savings',
    );

    final commitmentAvg = _average(commitmentTotals);
    final spendingAvg = _average(spendingTotals);
    final savingsAvg = _average(savingsTotals);

    // Run inference on each bucket independently
    final commitmentSlope = _trendSlope(commitmentTotals);
    final commitmentVol = _coefficientOfVariation(
      commitmentTotals,
      commitmentAvg,
    );
    final commitmentUtil = currentMonthLimit > 0
        ? (commitmentTotals.isNotEmpty ? commitmentTotals.last : 0) /
              (currentMonthLimit * 0.5)
        : 0.0;

    final spendingSlope = _trendSlope(spendingTotals);
    final spendingVol = _coefficientOfVariation(spendingTotals, spendingAvg);
    final spendingUtil = currentMonthLimit > 0
        ? (spendingTotals.isNotEmpty ? spendingTotals.last : 0) /
              (currentMonthLimit * 0.3)
        : 0.0;

    final savingsSlope = _trendSlope(savingsTotals);
    final savingsVol = _coefficientOfVariation(savingsTotals, savingsAvg);
    final savingsUtil = currentMonthLimit > 0
        ? (savingsTotals.isNotEmpty ? savingsTotals.last : 0) /
              (currentMonthLimit * 0.2)
        : 0.0;

    // Overall inference
    final overall = _runInference(
      historicalAverage: average,
      trendSlope: trendSlope,
      volatility: volatility,
      utilization: utilization,
    );

    // Per-bucket inference
    final commitmentResult = commitmentTotals.isNotEmpty
        ? _runInference(
            historicalAverage: commitmentAvg,
            trendSlope: commitmentSlope,
            volatility: commitmentVol,
            utilization: commitmentUtil,
          )
        : null;

    final spendingResult = spendingTotals.isNotEmpty
        ? _runInference(
            historicalAverage: spendingAvg,
            trendSlope: spendingSlope,
            volatility: spendingVol,
            utilization: spendingUtil,
          )
        : null;

    final savingsResult = savingsTotals.isNotEmpty
        ? _runInference(
            historicalAverage: savingsAvg,
            trendSlope: savingsSlope,
            volatility: savingsVol,
            utilization: savingsUtil,
          )
        : null;

    return FuzzyForecastResult(
      predictedAmount: overall.predictedAmount,
      confidenceScore: overall.confidenceScore,
      trendLabel: overall.trendLabel,
      volatilityLabel: overall.volatilityLabel,
      utilizationLabel: overall.utilizationLabel,
      adjustmentFactor: overall.adjustmentFactor,
      predictedCommitments: commitmentResult?.predictedAmount ?? 0,
      predictedSpending: spendingResult?.predictedAmount ?? 0,
      predictedSavings: savingsResult?.predictedAmount ?? 0,
    );
  }

  // ─────────────────────────────────────────
  // PUBLIC: 6-month forecast
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

    final workingHistory = List<double>.from(monthlyTotals);
    double workingLimit = currentMonthLimit;

    for (int month = 1; month <= 6; month++) {
      final average = _average(workingHistory);
      final trendSlope = _trendSlope(workingHistory);
      final volatility = _coefficientOfVariation(workingHistory, average);
      final double utilization = workingLimit > 0
          ? (workingHistory.last / workingLimit)
          : 0.0;

      final horizonDecay = 1.0 - (month - 1) * 0.08;

      final overall = _runInference(
        historicalAverage: average,
        trendSlope: trendSlope,
        volatility: volatility,
        utilization: utilization,
        confidenceMultiplier: horizonDecay.clamp(0.4, 1.0),
      );

      // Per-bucket for each future month (simplified proportional split
      // based on next-month bucket ratios, since we don't re-aggregate
      // per bucket for all 6 months to keep performance reasonable)
      final nextMonth = predictNextMonth(
        transactions: transactions,
        currentMonthLimit: currentMonthLimit,
        monthsOfHistory: monthsOfHistory,
      );
      final totalNext = nextMonth.predictedAmount > 0
          ? nextMonth.predictedAmount
          : overall.predictedAmount;
      final ratio = totalNext > 0 ? overall.predictedAmount / totalNext : 1.0;

      results.add(
        FuzzyForecastResult(
          predictedAmount: overall.predictedAmount,
          confidenceScore: overall.confidenceScore,
          trendLabel: overall.trendLabel,
          volatilityLabel: overall.volatilityLabel,
          utilizationLabel: overall.utilizationLabel,
          adjustmentFactor: overall.adjustmentFactor,
          predictedCommitments: nextMonth.predictedCommitments * ratio,
          predictedSpending: nextMonth.predictedSpending * ratio,
          predictedSavings: nextMonth.predictedSavings * ratio,
        ),
      );

      workingHistory.add(overall.predictedAmount);
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
    // 1. FUZZIFICATION
    final double trendRatio = historicalAverage > 0
        ? trendSlope / historicalAverage
        : 0.0;
    final trendMembership = _fuzzifyTrend(trendRatio);
    final volatilityMembership = _fuzzifyVolatility(volatility);
    final utilizationMembership = _fuzzifyUtilization(utilization);

    // 2. RULE EVALUATION (Mamdani min for AND)
    final rules = <_FuzzyRule>[
      _FuzzyRule(
        strength: _min([trendMembership.increasing, volatilityMembership.low]),
        outputValue: 0.22,
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
        outputValue: 0.10,
      ),
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
      _FuzzyRule(
        strength: _min([utilizationMembership.high, trendMembership.stable]),
        outputValue: 0.08,
      ),
    ];

    // 3. DEFUZZIFICATION (Weighted Centroid)
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

    // 4. CONFIDENCE SCORE
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
  // MEMBERSHIP FUNCTIONS (triangular)
  // ═══════════════════════════════════════════════════════════
  static _TrendMembership _fuzzifyTrend(double ratio) {
    final decreasing = _triangular(ratio, -1.0, -0.5, 0.0);
    final stable = _triangular(ratio, -0.15, 0.0, 0.15);
    final increasing = _triangular(ratio, 0.0, 0.5, 1.0);
    return _TrendMembership(decreasing, stable, increasing);
  }

  static _VolatilityMembership _fuzzifyVolatility(double cv) {
    final low = _triangular(cv, 0.0, 0.0, 0.25);
    final medium = _triangular(cv, 0.10, 0.30, 0.50);
    final high = _triangular(cv, 0.35, 0.6, 1.0);
    return _VolatilityMembership(low, medium, high);
  }

  static _UtilizationMembership _fuzzifyUtilization(double ratio) {
    final low = _triangular(ratio, 0.0, 0.0, 0.5);
    final moderate = _triangular(ratio, 0.3, 0.7, 1.0);
    final high = _triangular(ratio, 0.8, 1.2, 1.6);
    return _UtilizationMembership(low, moderate, high);
  }

  static double _triangular(double x, double a, double b, double c) {
    if (x <= a || x >= c) return 0.0;
    if (x == b) return 1.0;
    if (x < b) return (x - a) / (b - a);
    return (c - x) / (c - b);
  }

  static double _min(List<double> values) =>
      values.reduce((a, b) => a < b ? a : b);

  // ═══════════════════════════════════════════════════════════
  // AGGREGATION HELPERS
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

  // ── Aggregate by month AND bucket category ──
  static List<double> _aggregateByMonthAndBucket(
    List<TransactionModel> transactions,
    int monthsOfHistory,
    String bucket,
  ) {
    final Map<String, double> totals = {};

    for (final tx in transactions) {
      if (tx.type != TransactionType.expense) continue;
      if (tx.budgetCategory.name != bucket) continue;
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
// INTERNAL HELPERS
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
