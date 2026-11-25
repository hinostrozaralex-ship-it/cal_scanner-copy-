import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/food.dart';
import '../../domain/repositories/food_repository.dart';
import '../datasources/barcode_cache_datasource.dart';
import '../datasources/food_local_datasource.dart';
import '../datasources/food_remote_datasource.dart';
import '../datasources/open_food_facts_datasource.dart';
import '../models/food_model.dart';

class FoodRepositoryImpl implements FoodRepository {
  final FoodLocalDataSource _local;
  final FoodRemoteDataSource _remote;
  final OpenFoodFactsDataSource? _openFoodFacts;
  final BarcodeCacheDataSource? _barcodeCache;

  FoodRepositoryImpl(
    this._local,
    this._remote, {
    OpenFoodFactsDataSource? openFoodFacts,
    BarcodeCacheDataSource? barcodeCache,
  }) : _openFoodFacts = openFoodFacts,
       _barcodeCache = barcodeCache;

  @override
  Future<Either<Failure, List<Food>>> getDailyFoodLog(DateTime date) async {
    try {
      final models = await _local.getDailyFoodLog(date);
      return right(models.map((e) => e.toDomain()).toList());
    } catch (e) {
      return left(CacheFailure('Failed to read daily log', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> addFood(Food food) async {
    try {
      final day = DateTime(food.timestamp.year, food.timestamp.month, food.timestamp.day);
      final current = await _local.getDailyFoodLog(day);
      final updated = [...current, FoodModel.fromDomain(food)];
      await _local.setDailyFoodLog(day, updated);
      return right(unit);
    } catch (e) {
      return left(CacheFailure('Failed to add food', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteFood(Food food) async {
    try {
      final day = DateTime(food.timestamp.year, food.timestamp.month, food.timestamp.day);
      final current = await _local.getDailyFoodLog(day);
      final updated = current.where((e) => e.id != food.id).toList();
      await _local.setDailyFoodLog(day, updated);
      return right(unit);
    } catch (e) {
      return left(CacheFailure('Failed to delete food', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateFood(Food food) async {
    try {
      final day = DateTime(food.timestamp.year, food.timestamp.month, food.timestamp.day);
      final current = await _local.getDailyFoodLog(day);
      final updated = current
          .map((e) => e.id == food.id ? FoodModel.fromDomain(food) : e)
          .toList();
      await _local.setDailyFoodLog(day, updated);
      return right(unit);
    } catch (e) {
      return left(CacheFailure('Failed to update food', cause: e));
    }
  }

  @override
  Future<Either<Failure, Food>> detectFoodFromImage(
    File image, {
    String? userHint,
    bool labelOnlyMode = false,
  }) async {
    final result = await _remote.detectFoodAndCalories(
      image,
      userHint: userHint,
      labelOnlyMode: labelOnlyMode,
    );

    if (labelOnlyMode || _openFoodFacts == null) {
      return result;
    }

    return result.fold(
      (failure) => left(failure),
      (food) async {
        // Hybrid match: if Gemini recognized a packaged product without a
        // visible nutrition label, cross-check against Open Food Facts.
        if (food.isFood && food.isPackaged && !food.labelVisible) {
          final dbMatch = await _openFoodFacts.searchProductByName(
            food.name,
            brand: food.brand,
            preferredAmount: food.servingSize,
            preferredUnit: food.servingUnit,
          );
          if (dbMatch != null) {
            return right(
              dbMatch.copyWith(
                imageUrl: food.imageUrl ?? dbMatch.imageUrl,
                timestamp: food.timestamp,
              ),
            );
          }
        }
        return right(food);
      },
    );
  }

  @override
  Future<Either<Failure, BarcodeLookupResult>> lookupFoodByBarcode(
    String barcode,
  ) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) {
      return left(const NetworkFailure('Invalid barcode.'));
    }

    if (_barcodeCache != null) {
      final cached = await _barcodeCache.getProduct(cleanCode);
      if (cached != null) {
        return right(
          BarcodeLookupResult(
            food: cached.copyWith(
              barcode: cleanCode,
              source: cached.source == FoodSource.aiEstimate
                  ? FoodSource.barcode
                  : cached.source,
            ),
            partialName: cached.name,
            brand: cached.brand,
          ),
        );
      }
    }

    final off = _openFoodFacts ?? OpenFoodFactsDataSource();
    final remoteResult = await off.getProductByBarcode(cleanCode);

    return remoteResult.fold(
      (failure) => left(failure),
      (lookup) async {
        if (lookup.food != null && _barcodeCache != null) {
          await _barcodeCache.saveProduct(cleanCode, lookup.food!);
        }
        return right(lookup);
      },
    );
  }

  @override
  Future<void> cacheBarcodeProduct(String barcode, Food product) async {
    if (_barcodeCache == null) return;
    await _barcodeCache.saveProduct(barcode, product);
  }

  @override
  Future<Either<Failure, Food>> estimateFoodFromText(String description) {
    return _remote.estimateFoodFromText(description);
  }

  @override
  Future<Either<Failure, List<double>>> getWeeklyCalories({
    required DateTime endDate,
  }) async {
    try {
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      final days = List.generate(7, (i) => end.subtract(Duration(days: 6 - i)));
      final results = await Future.wait(days.map(_local.getDailyFoodLog));
      final weekly = results
          .map((meals) => meals.fold<double>(0.0, (sum, m) => sum + m.calories))
          .toList();
      return right(weekly);
    } catch (e) {
      return left(CacheFailure('Failed to read weekly calories', cause: e));
    }
  }
}

