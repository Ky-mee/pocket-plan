import 'package:cloud_firestore/cloud_firestore.dart';

/// Community-contributed affordable dish tip linked to an OpenStreetMap venue.
class DishTipModel {
  final String id;
  final String userId;
  final String authorName;
  final String placeId;
  final String placeName;
  final String dishName;
  final double price;
  final String currency;
  final double lat;
  final double lon;
  final DateTime createdAt;

  const DishTipModel({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.placeId,
    required this.placeName,
    required this.dishName,
    required this.price,
    required this.currency,
    required this.lat,
    required this.lon,
    required this.createdAt,
  });

  factory DishTipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DishTipModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      authorName: data['authorName'] ?? 'Community member',
      placeId: data['placeId'] ?? '',
      placeName: data['placeName'] ?? '',
      dishName: data['dishName'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'MYR',
      lat: (data['lat'] ?? 0.0).toDouble(),
      lon: (data['lon'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'authorName': authorName,
      'placeId': placeId,
      'placeName': placeName,
      'dishName': dishName,
      'price': price,
      'currency': currency,
      'lat': lat,
      'lon': lon,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Returns the lowest-priced tip for [placeId], or `null` if none exists.
  static DishTipModel? cheapestForPlace(
    List<DishTipModel> tips,
    String placeId,
  ) {
    DishTipModel? best;
    for (final tip in tips) {
      if (tip.placeId != placeId) continue;
      if (best == null || tip.price < best.price) {
        best = tip;
      }
    }
    return best;
  }

  /// True when [price] fits comfortably within a non-null positive [dailyBudget].
  static bool fitsDailyBudget(double price, double? dailyBudget) {
    if (dailyBudget == null || dailyBudget <= 0) return false;
    return price <= dailyBudget;
  }
}
