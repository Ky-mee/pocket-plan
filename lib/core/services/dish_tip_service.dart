import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_plan/models/dish_tip_model.dart';

/// Fetches and manages community cheap-dish tips in Firestore (`dish_tips`).
class DishTipService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tips =>
      _db.collection('dish_tips');

  /// Fetches dish tips within ~[radiusKm] of ([lat], [lon]).
  ///
  /// Uses a single-field `lat` bounding query so no composite Firestore index
  /// is required, and filters `lon` in memory. Errors return an empty list so
  /// Food Nearby keeps working seamlessly offline.
  Future<List<DishTipModel>> fetchNearbyTips({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
  }) async {
    try {
      final latDelta = radiusKm / 111.0;
      final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.1, 1.0);
      final lonDelta = radiusKm / (111.0 * cosLat);

      final snap = await _tips
          .where('lat', isGreaterThanOrEqualTo: lat - latDelta)
          .where('lat', isLessThanOrEqualTo: lat + latDelta)
          .limit(150)
          .get();

      final results = snap.docs
          .map((d) => DishTipModel.fromFirestore(d))
          .where((t) => (t.lon - lon).abs() <= lonDelta)
          .toList();

      results.sort((a, b) => a.price.compareTo(b.price));
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<DishTipModel> addTip(DishTipModel tip) async {
    final doc = await _tips.add(tip.toFirestore());
    return DishTipModel(
      id: doc.id,
      userId: tip.userId,
      authorName: tip.authorName,
      placeId: tip.placeId,
      placeName: tip.placeName,
      dishName: tip.dishName,
      price: tip.price,
      currency: tip.currency,
      lat: tip.lat,
      lon: tip.lon,
      createdAt: tip.createdAt,
    );
  }

  Future<void> deleteTip(String tipId) async {
    await _tips.doc(tipId).delete();
  }
}
