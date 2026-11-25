import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../data/datasources/open_food_facts_datasource.dart';
import '../entities/food.dart';

abstract class FoodRepository {
  Future<Either<Failure, List<Food>>> getDailyFoodLog(DateTime date);
  Future<Either<Failure, Unit>> addFood(Food food);
  Future<Either<Failure, Unit>> deleteFood(Food food);
  Future<Either<Failure, Unit>> updateFood(Food food);

  Future<Either<Failure, Food>> detectFoodFromImage(
    File image, {
    String? userHint,
    bool labelOnlyMode = false,
  });

  Future<Either<Failure, BarcodeLookupResult>> lookupFoodByBarcode(
    String barcode,
  );

  Future<void> cacheBarcodeProduct(String barcode, Food product);

  Future<Either<Failure, Food>> estimateFoodFromText(String description);

  Future<Either<Failure, List<double>>> getWeeklyCalories({
    required DateTime endDate,
  });
}

