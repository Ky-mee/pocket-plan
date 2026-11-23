import 'package:pocket_plan/core/utils/budget_calculator.dart';
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
    double? commitmentLimit,
    double? spendingLimit,
    double? savingsLimit,
    int monthsOfHistory = 6,
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();
    final monthlyTotals = _aggregateByMonth(
      transactions,
      monthsOfHistory,
      refNow,
    );

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

    final effectiveCommitmentLimit = commitmentLimit ?? currentMonthLimit * 0.5;
    final effectiveSpendingLimit = spendingLimit ?? currentMonthLimit * 0.3;
    final effectiveSavingsLimit = savingsLimit ?? currentMonthLimit * 0.2;

    // ── Per-bucket totals ──
    final commitmentTotals = _aggregateByMonthAndBucket(
      transactions,
      monthsOfHistory,
      'commitment',
      refNow,
    );
    final spendingTotals = _aggregateByMonthAndBucket(
      transactions,
      monthsOfHistory,
      'spending',
      refNow,
    );
    final savingsTotals = _aggregateByMonthAndBucket(
      transactions,
      monthsOfHistory,
      'savings',
      refNow,
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
    final commitmentUtil = effectiveCommitmentLimit > 0
        ? (commitmentTotals.isNotEmpty ? commitmentTotals.last : 0) /
              effectiveCommitmentLimit
        : 0.0;

    final spendingSlope = _trendSlope(spendingTotals);
    final spendingVol = _coefficientOfVariation(spendingTotals, spendingAvg);
    final spendingUtil = effectiveSpendingLimit > 0
        ? (spendingTotals.isNotEmpty ? spendingTotals.last : 0) /
              effectiveSpendingLimit
        : 0.0;

    final savingsSlope = _trendSlope(savingsTotals);
    final savingsVol = _coefficientOfVariation(savingsTotals, savingsAvg);
    final savingsUtil = effectiveSavingsLimit > 0
        ? (savingsTotals.isNotEmpty ? savingsTotals.last : 0) /
              effectiveSavingsLimit
        : 0.0;

    // Overall inference
    final overall = _runInference(
      historicalAverage: average,
      trendSlope: trendSlope,
      volatility: volatility,
      utilization: utilization,
      historyMonths: monthlyTotals.length,
    );

    // Per-bucket inference
    final commitmentResult = commitmentTotals.isNotEmpty
        ? _runInference(
            historicalAverage: commitmentAvg,
            trendSlope: commitmentSlope,
            volatility: commitmentVol,
            utilization: commitmentUtil,
            historyMonths: commitmentTotals.length,
          )
        : null;

    final spendingResult = spendingTotals.isNotEmpty
        ? _runInference(
            historicalAverage: spendingAvg,
            trendSlope: spendingSlope,
            volatility: spendingVol,
            utilization: spendingUtil,
            historyMonths: spendingTotals.length,
          )
        : null;

    final savingsResult = savingsTotals.isNotEmpty
        ? _runInference(
            historicalAverage: savingsAvg,
            trendSlope: savingsSlope,
            volatility: savingsVol,
            utilization: savingsUtil,
            historyMonths: savingsTotals.length,
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
    double? commitmentLimit,
    double? spendingLimit,
    double? savingsLimit,
    int monthsOfHistory = 6,
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();
    final results = <FuzzyForecastResult>[];
    final monthlyTotals = _aggregateByMonth(
      transactions,
      monthsOfHistory,
      refNow,
    );

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

    // Compute 1-month bucket breakdown once outside the 6-month loop.
    final nextMonth = predictNextMonth(
      transactions: transactions,
      currentMonthLimit: currentMonthLimit,
      commitmentLimit: commitmentLimit,
      spendingLimit: spendingLimit,
      savingsLimit: savingsLimit,
      monthsOfHistory: monthsOfHistory,
      now: refNow,
    );

    final workingHistory = List<double>.from(monthlyTotals);
    final double workingLimit = currentMonthLimit;

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
        historyMonths: monthlyTotals.length,
        confidenceMultiplier: horizonDecay.clamp(0.4, 1.0),
      );

      final double cappedConfidence = results.isNotEmpty &&
              overall.confidenceScore > results.last.confidenceScore
          ? results.last.confidenceScore
          : overall.confidenceScore;

      final totalNext = nextMonth.predictedAmount > 0
          ? nextMonth.predictedAmount
          : overall.predictedAmount;
      final ratio = totalNext > 0 ? overall.predictedAmount / totalNext : 1.0;

      results.add(
        FuzzyForecastResult(
          predictedAmount: overall.predictedAmount,
          confidenceScore: cappedConfidence,
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
    required int historyMonths,
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
        outputValue: 0.06,
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

    // 4. CONFIDENCE SCORE (data maturity x volatility stability x horizon)
    final double dataMaturity = switch (historyMonths) {
      1 => 0.45,
      2 => 0.65,
      3 => 0.78,
      _ => 0.90,
    };
    final double stability = 1.0 - volatility.clamp(0.0, 0.6) * 0.45;
    final double confidence =
        (dataMaturity * stability * confidenceMultiplier * 100.0).clamp(
          15.0,
          95.0,
        );

    return FuzzyForecastResult(
      predictedAmount: predictedAmount.toDouble(),
      confidenceScore: confidence,
      trendLabel: trendMembership.dominantLabel,
      volatilityLabel: volatilityMembership.dominantLabel,
      utilizationLabel: utilizationMembership.dominantLabel,
      adjustmentFactor: adjustmentFactor.toDouble(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MEMBERSHIP FUNCTIONS (open-ended shoulders + triangular)
  // ═══════════════════════════════════════════════════════════
  static _TrendMembership _fuzzifyTrend(double ratio) {
    final decreasing = _leftShoulder(ratio, -0.5, 0.0);
    final stable = _triangular(ratio, -0.15, 0.0, 0.15);
    final increasing = _rightShoulder(ratio, 0.0, 0.5);
    return _TrendMembership(decreasing, stable, increasing);
  }

  static _VolatilityMembership _fuzzifyVolatility(double cv) {
    final low = _leftShoulder(cv, 0.0, 0.25);
    final medium = _triangular(cv, 0.10, 0.30, 0.50);
    final high = _rightShoulder(cv, 0.35, 0.6);
    return _VolatilityMembership(low, medium, high);
  }

  static _UtilizationMembership _fuzzifyUtilization(double ratio) {
    final low = _leftShoulder(ratio, 0.0, 0.5);
    final moderate = _triangular(ratio, 0.3, 0.7, 1.0);
    final high = _rightShoulder(ratio, 0.8, 1.2);
    return _UtilizationMembership(low, moderate, high);
  }

  static double _leftShoulder(double x, double b, double c) {
    if (x <= b) return 1.0;
    if (x >= c) return 0.0;
    return (c - x) / (c - b);
  }

  static double _rightShoulder(double x, double a, double b) {
    if (x <= a) return 0.0;
    if (x >= b) return 1.0;
    return (x - a) / (b - a);
  }

  static double _triangular(double x, double a, double b, double c) {
    if (a == b && x <= b) return x < a ? 0.0 : 1.0;
    if (b == c && x >= b) return x > c ? 0.0 : 1.0;
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
  static bool _isCurrentMonthComplete(DateTime now) {
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    return now.day >= lastDayOfMonth;
  }

  static List<double> _aggregateByMonth(
    List<TransactionModel> transactions,
    int monthsOfHistory,
    DateTime now,
  ) {
    final Map<String, double> totals = {};

    for (final tx in transactions) {
      if (tx.type != TransactionType.expense) continue;
      final key = BudgetCalculator.monthKey(tx.date);
      totals[key] = (totals[key] ?? 0) + tx.amount;
    }

    final currentKey = BudgetCalculator.monthKey(now);
    if (!_isCurrentMonthComplete(now) &&
        totals.keys.any((k) => k != currentKey)) {
      totals.remove(currentKey);
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
    DateTime now,
  ) {
    final Map<String, double> totals = {};

    for (final tx in transactions) {
      if (tx.type != TransactionType.expense) continue;
      if (tx.budgetCategory.name != bucket) continue;
      final key = BudgetCalculator.monthKey(tx.date);
      totals[key] = (totals[key] ?? 0) + tx.amount;
    }

    final currentKey = BudgetCalculator.monthKey(now);
    if (!_isCurrentMonthComplete(now) &&
        totals.keys.any((k) => k != currentKey)) {
      totals.remove(currentKey);
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
