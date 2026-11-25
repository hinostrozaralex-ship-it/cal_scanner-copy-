import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../data/datasources/open_food_facts_datasource.dart';
import '../repositories/food_repository.dart';

class LookupFoodByBarcode {
  final FoodRepository _repo;
  LookupFoodByBarcode(this._repo);

  Future<Either<Failure, BarcodeLookupResult>> call(String barcode) {
    return _repo.lookupFoodByBarcode(barcode);
  }
}
