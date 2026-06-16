import 'package:cloud_firestore/cloud_firestore.dart';

class PredictionModel {
  final String userId;
  final String month; // "2026-05" (next month)
  final double predictedTotal;
  final double confidence; // 0.0 to 1.0
  final Map<String, double> breakdown; // category -> predicted amount
  final String method; // "moving_average" or "regression"
  final DateTime generatedAt;

  PredictionModel({
    required this.userId,
    required this.month,
    required this.predictedTotal,
    required this.confidence,
    required this.breakdown,
    required this.method,
    required this.generatedAt,
  });

  factory PredictionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PredictionModel(
      userId: doc.id,
      month: data['month'] ?? '',
      predictedTotal: (data['predictedTotal'] ?? 0.0).toDouble(),
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      breakdown: Map<String, double>.from(
        (data['breakdown'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
      ),
      method: data['method'] ?? 'moving_average',
      generatedAt: (data['generatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'month': month,
      'predictedTotal': predictedTotal,
      'confidence': confidence,
      'breakdown': breakdown,
      'method': method,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }
}

// Simple moving average predictor (runs locally, no API needed)
class SpendingPredictor {
  // Takes last N months of totals and returns predicted next month
  static double movingAverage(List<double> monthlyTotals, {int window = 3}) {
    if (monthlyTotals.isEmpty) return 0;
    final recent = monthlyTotals.length > window
        ? monthlyTotals.sublist(monthlyTotals.length - window)
        : monthlyTotals;
    final sum = recent.fold(0.0, (a, b) => a + b);
    return sum / recent.length;
  }

  // Confidence score: higher when data is consistent
  static num confidenceScore(List<double> monthlyTotals) {
    if (monthlyTotals.length < 2) return 0.4;
    final avg = movingAverage(monthlyTotals);
    if (avg == 0) return 0.4;
    final variance =
        monthlyTotals
            .map((v) => (v - avg) * (v - avg))
            .fold(0.0, (a, b) => a + b) /
        monthlyTotals.length;
    final stdDev = variance > 0 ? variance : 1;
    final cv = stdDev / avg; // Coefficient of variation
    return (1 - cv.clamp(0, 1)).clamp(0.4, 0.95);
  }
}
