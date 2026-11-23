import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/models/dish_tip_model.dart';

void main() {
  DishTipModel makeTip({
    required String id,
    required String placeId,
    required double price,
    String dishName = 'Set Lunch',
  }) {
    return DishTipModel(
      id: id,
      userId: 'u1',
      authorName: 'Alex',
      placeId: placeId,
      placeName: 'Corner Cafe',
      dishName: dishName,
      price: price,
      currency: 'MYR',
      lat: 3.139,
      lon: 101.6869,
      createdAt: DateTime(2026, 4, 1),
    );
  }

  group('DishTipModel helpers', () {
    test('cheapestForPlace selects lowest price matching placeId', () {
      final tips = [
        makeTip(id: '1', placeId: 'node_10', price: 14.5, dishName: 'Curry Mee'),
        makeTip(id: '2', placeId: 'node_99', price: 3.0, dishName: 'Tea'),
        makeTip(id: '3', placeId: 'node_10', price: 7.5, dishName: 'Nasi Lemak'),
        makeTip(id: '4', placeId: 'node_10', price: 10.0, dishName: 'Laksa'),
      ];

      final cheapest = DishTipModel.cheapestForPlace(tips, 'node_10');
      expect(cheapest, isNotNull);
      expect(cheapest!.id, '3');
      expect(cheapest.dishName, 'Nasi Lemak');
      expect(cheapest.price, 7.5);

      expect(DishTipModel.cheapestForPlace(tips, 'node_missing'), isNull);
    });

    test('fitsDailyBudget checks positive daily budget threshold safely', () {
      expect(DishTipModel.fitsDailyBudget(10.0, null), isFalse);
      expect(DishTipModel.fitsDailyBudget(10.0, 0.0), isFalse);
      expect(DishTipModel.fitsDailyBudget(10.0, -5.0), isFalse);
      expect(DishTipModel.fitsDailyBudget(10.0, 10.0), isTrue);
      expect(DishTipModel.fitsDailyBudget(8.5, 12.0), isTrue);
      expect(DishTipModel.fitsDailyBudget(15.0, 12.0), isFalse);
    });
  });
}
