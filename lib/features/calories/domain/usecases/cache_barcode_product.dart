import '../entities/food.dart';
import '../repositories/food_repository.dart';

class CacheBarcodeProduct {
  final FoodRepository _repo;
  CacheBarcodeProduct(this._repo);

  Future<void> call(String barcode, Food product) {
    return _repo.cacheBarcodeProduct(barcode, product);
  }
}
