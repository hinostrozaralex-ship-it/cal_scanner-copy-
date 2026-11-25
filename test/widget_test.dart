import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cal_scanner/core/storage/local_storage_service.dart';
import 'package:cal_scanner/features/calories/data/datasources/barcode_cache_datasource.dart';
import 'package:cal_scanner/features/calories/data/datasources/food_local_datasource.dart';
import 'package:cal_scanner/features/calories/data/datasources/food_remote_datasource.dart';
import 'package:cal_scanner/features/calories/data/datasources/open_food_facts_datasource.dart';
import 'package:cal_scanner/features/calories/data/repositories/food_repository_impl.dart';
import 'package:cal_scanner/features/calories/domain/entities/food.dart';
import 'package:cal_scanner/features/calories/domain/usecases/add_food.dart';
import 'package:cal_scanner/features/calories/domain/usecases/delete_food.dart';
import 'package:cal_scanner/features/calories/domain/usecases/detect_food_from_image.dart';
import 'package:cal_scanner/features/calories/domain/usecases/get_daily_food_log.dart';
import 'package:cal_scanner/features/calories/domain/usecases/get_weekly_calories.dart';
import 'package:cal_scanner/features/calories/domain/usecases/update_food.dart';
import 'package:cal_scanner/features/calories/presentation/cubit/food_log_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;
  late File testImageFile;

  setUp(() async {
    FoodRemoteDataSource.resetCachedModelForTesting();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('cal_scanner_test_');
    testImageFile = File('${tempDir.path}/meal.jpg');
    await testImageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<LocalStorageService> createStorageWithKey([String? apiKey]) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    if (apiKey != null) {
      await storage.saveApiKey(apiKey);
    }
    return storage;
  }

  String buildGeminiSuccessBody(Map<String, dynamic> payload) {
    return jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(payload)},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    });
  }

  group('FoodRemoteDataSource — Gemini API, Schema & Error Handling', () {
    test('1. Edible food response parses is_food, serving_size, serving_unit and base macros', () async {
      final storage = await createStorageWithKey('user_test_key_123');
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;

      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return http.Response(
          buildGeminiSuccessBody({
            'is_food': true,
            'name': 'Grilled Chicken Breast',
            'serving_size': 100,
            'serving_unit': 'g',
            'calories': 320,
            'protein': 42.5,
            'carbs': 3,
            'fat': 14.2,
            'non_food_message': null,
          }),
          200,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);

      expect(result.isRight(), isTrue);
      expect(
        capturedUri.toString(),
        contains('models/${FoodRemoteDataSource.primaryModel}:generateContent'),
      );
      expect(capturedHeaders?['x-goog-api-key'], 'user_test_key_123');

      final food = result.getOrElse((_) => throw StateError('Expected Right'));
      expect(food.isFood, isTrue);
      expect(food.name, 'Grilled Chicken Breast');
      expect(food.servingSize, 100.0);
      expect(food.servingUnit, 'g');
      expect(food.baseCalories, 320.0);
      expect(food.baseProtein, 42.5);
      expect(food.baseCarbs, 3.0);
      expect(food.baseFat, 14.2);
      expect(food.nonFoodMessage, isNull);
      expect(food.imageUrl, testImageFile.path);
    });

    test('2. Non-edible item response parses is_food == false and witty non_food_message', () async {
      final storage = await createStorageWithKey('user_test_key_123');

      final client = MockClient((request) async {
        return http.Response(
          buildGeminiSuccessBody({
            'is_food': false,
            'name': 'Domestic Cat',
            'serving_size': 1,
            'serving_unit': 'piece',
            'calories': 0,
            'protein': 0,
            'carbs': 0,
            'fat': 0,
            'non_food_message':
                'Cats are friends, not food! Please do not consume your pets.',
          }),
          200,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);
      expect(result.isRight(), isTrue);

      final food = result.getOrElse((_) => throw StateError('Expected Right'));
      expect(food.isFood, isFalse);
      expect(food.name, 'Domestic Cat');
      expect(food.calories, 0.0);
      expect(
        food.nonFoodMessage,
        'Cats are friends, not food! Please do not consume your pets.',
      );
    });

    test('3. Model unavailable (404) falls back to fallbackModel', () async {
      final storage = await createStorageWithKey('user_test_key_123');
      final requestedModels = <String>[];

      final client = MockClient((request) async {
        final path = request.url.path;
        requestedModels.add(path);

        if (path.contains(FoodRemoteDataSource.primaryModel)) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 404,
                'message': 'models/gemini-3.8-flash is not found',
                'status': 'NOT_FOUND',
              },
            }),
            404,
          );
        }

        return http.Response(
          buildGeminiSuccessBody({
            'is_food': true,
            'name': 'Caesar Salad',
            'serving_size': 1,
            'serving_unit': 'serving',
            'calories': 250,
            'protein': 18,
            'carbs': 12,
            'fat': 15,
            'non_food_message': null,
          }),
          200,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);
      expect(result.isRight(), isTrue);
      expect(requestedModels.length, 2);
      expect(requestedModels[0], contains(FoodRemoteDataSource.primaryModel));
      expect(requestedModels[1], contains(FoodRemoteDataSource.fallbackModel));
    });

    test('4. Invalid API Key (400 API_KEY_INVALID) fails immediately without fallback', () async {
      final storage = await createStorageWithKey('invalid_key_999');
      var callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'error': {
              'code': 400,
              'message': 'API key not valid. Please pass a valid API key.',
              'status': 'INVALID_ARGUMENT',
              'details': [
                {'reason': 'API_KEY_INVALID'},
              ],
            },
          }),
          400,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);
      expect(result.isLeft(), isTrue);
      expect(callCount, 1);
      final errorMsg = result.fold((l) => l.message, (_) => '');
      expect(errorMsg, FoodRemoteDataSource.invalidApiKeyErrorMessage);
    });

    test('5. HTTP 503 and 429 perform single fallback and return clear English message', () async {
      final storage = await createStorageWithKey('user_test_key_123');
      var callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'error': {
              'code': 503,
              'message': 'The model is overloaded. Please try again later.',
              'status': 'UNAVAILABLE',
            },
          }),
          503,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);
      expect(result.isLeft(), isTrue);
      expect(callCount, 2);
      final errorMsg = result.fold((l) => l.message, (_) => '');
      expect(errorMsg, FoodRemoteDataSource.highDemandErrorMessage);
    });

    test('6. Timeout and SocketException return clear English messages', () async {
      final storage = await createStorageWithKey('user_test_key_123');

      final timeoutClient = MockClient((request) async {
        throw TimeoutException('Future not completed');
      });

      final dsTimeout = FoodRemoteDataSource(
        storage,
        client: timeoutClient,
        delay: (_) async {},
      );
      final timeoutRes = await dsTimeout.detectFoodAndCalories(testImageFile);
      expect(timeoutRes.isLeft(), isTrue);
      expect(
        timeoutRes.fold((l) => l.message, (_) => ''),
        FoodRemoteDataSource.timeoutErrorMessage,
      );

      final offlineClient = MockClient((request) async {
        throw const SocketException('Failed host lookup');
      });

      final dsOffline = FoodRemoteDataSource(
        storage,
        client: offlineClient,
        delay: (_) async {},
      );
      final offlineRes = await dsOffline.detectFoodAndCalories(testImageFile);
      expect(offlineRes.isLeft(), isTrue);
      expect(
        offlineRes.fold((l) => l.message, (_) => ''),
        FoodRemoteDataSource.noConnectionErrorMessage,
      );
    });

    test('7. Incomplete or malformed JSON returns friendly English error without TypeError', () async {
      final storage = await createStorageWithKey('user_test_key_123');

      final incompleteClient = MockClient((request) async {
        return http.Response(
          buildGeminiSuccessBody({
            'is_food': true,
            'name': 'Apple',
            'calories': null,
            'protein': 'invalid_number',
          }),
          200,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: incompleteClient,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);
      expect(result.isLeft(), isTrue);
      expect(
        result.fold((l) => l.message, (_) => ''),
        FoodRemoteDataSource.invalidResponseErrorMessage,
      );
    });

    test('11. New schema: per-100 values are scaled by the app to the package amount', () async {
      final storage = await createStorageWithKey('user_test_key_123');

      final client = MockClient((request) async {
        return http.Response(
          buildGeminiSuccessBody({
            'is_food': true,
            'name': 'Bifrutas Mediterranean',
            'label_visible': true,
            'non_food_message': null,
            'ingredients': [
              {
                'name': 'Bifrutas Mediterranean',
                'amount': 330,
                'amount_unit': 'ml',
                'per_100_calories': 25,
                'per_100_protein': 0.5,
                'per_100_carbs': 5.4,
                'per_100_fat': 0,
              },
            ],
          }),
          200,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);
      expect(result.isRight(), isTrue);

      final food = result.getOrElse((_) => throw StateError('Expected Right'));
      expect(food.servingSize, 330.0);
      expect(food.servingUnit, 'ml');
      expect(food.calories, closeTo(82.5, 0.06));
      expect(food.carbs, closeTo(17.8, 0.06));
      expect(food.protein, closeTo(1.65, 0.06));
      expect(food.fat, 0.0);
      expect(food.baseCalories, food.calories);
      expect(food.ingredients.length, 1);
      expect(food.ingredients.first.servingSize, 330.0);
    });

    test('12. New schema: root totals are the sum of the ingredients computed by the app', () async {
      final storage = await createStorageWithKey('user_test_key_123');

      final client = MockClient((request) async {
        return http.Response(
          buildGeminiSuccessBody({
            'is_food': true,
            'name': 'Chicken with Rice',
            'label_visible': false,
            'non_food_message': null,
            'ingredients': [
              {
                'name': 'Cooked Rice',
                'amount': 200,
                'amount_unit': 'g',
                'per_100_calories': 130,
                'per_100_protein': 2.7,
                'per_100_carbs': 28,
                'per_100_fat': 0.3,
              },
              {
                'name': 'Grilled Chicken',
                'amount': 150,
                'amount_unit': 'g',
                'per_100_calories': 165,
                'per_100_protein': 31,
                'per_100_carbs': 0,
                'per_100_fat': 3.6,
              },
            ],
          }),
          200,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);
      expect(result.isRight(), isTrue);

      final food = result.getOrElse((_) => throw StateError('Expected Right'));
      expect(food.ingredients.length, 2);
      expect(food.servingSize, 350.0);
      expect(food.servingUnit, 'g');
      expect(food.calories, closeTo(507.5, 0.11));
      expect(food.protein, closeTo(51.9, 0.11));
      expect(food.carbs, closeTo(56.0, 0.11));
      expect(food.fat, closeTo(6.0, 0.11));
    });
  });

  group('FoodLogCubit — Interactive Scan, Log Meal & Edit Meal Flow', () {
    test('8. Scan detects meal without auto-saving, Log Meal saves with scaled portion, and updateMeal refreshes daily totals', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      await storage.saveApiKey('user_test_key_123');

      final client = MockClient((request) async {
        return http.Response(
          buildGeminiSuccessBody({
            'is_food': true,
            'name': 'Orange Juice',
            'serving_size': 100,
            'serving_unit': 'ml',
            'calories': 45,
            'protein': 0.7,
            'carbs': 10.4,
            'fat': 0.2,
            'non_food_message': null,
          }),
          200,
        );
      });

      final localDs = FoodLocalDataSource(prefs, storage);
      final remoteDs = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );
      final repo = FoodRepositoryImpl(localDs, remoteDs);

      final cubit = FoodLogCubit(
        GetDailyFoodLog(repo),
        GetWeeklyCalories(repo),
        AddFood(repo),
        DeleteFood(repo),
        UpdateFood(repo),
        DetectFoodFromImage(repo),
      );

      // Step 1: Scan image (only detects, does not save yet)
      await cubit.addMealFromImage(testImageFile);

      expect(cubit.state.isScanning, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.scannedMeal, isNotNull);
      expect(cubit.state.scannedMeal!.name, 'Orange Juice');
      expect(cubit.state.scannedMeal!.servingSize, 100.0);
      expect(cubit.state.scannedMeal!.servingUnit, 'ml');
      expect(cubit.state.meals, isEmpty);

      // Step 2: User adjusts portion to 250 ml and taps "Log Meal"
      final detected = cubit.state.scannedMeal!;
      const currentQty = 250.0;
      final ratio = currentQty / detected.servingSize;
      final loggedMeal = detected.copyWith(
        quantity: currentQty,
        calories: detected.baseCalories * ratio,
        protein: detected.baseProtein * ratio,
        carbs: detected.baseCarbs * ratio,
        fat: detected.baseFat * ratio,
      );

      await cubit.addMeal(loggedMeal);

      expect(cubit.state.meals.length, 1);
      expect(cubit.state.totalCalories, closeTo(112.5, 0.01));
      expect(cubit.state.totalCarbs, closeTo(26.0, 0.01));

      // Step 3: User edits registered meal in Edit Meal BottomSheet to 300 ml
      final editedRatio = 300.0 / detected.servingSize;
      final editedMeal = loggedMeal.copyWith(
        quantity: 300.0,
        calories: detected.baseCalories * editedRatio,
        protein: detected.baseProtein * editedRatio,
        carbs: detected.baseCarbs * editedRatio,
        fat: detected.baseFat * editedRatio,
      );

      await cubit.updateMeal(editedMeal);

      expect(cubit.state.meals.length, 1);
      expect(cubit.state.meals.first.quantity, 300.0);
      expect(cubit.state.totalCalories, closeTo(135.0, 0.01));

      final storedMeals = await storage.getMealsByDate(DateTime.now());
      expect(storedMeals.length, 1);
      expect(storedMeals.first.calories, closeTo(135.0, 0.01));

      // Step 4: User deletes the meal — verify it does not resurrect from legacy storage
      await cubit.deleteMeal(editedMeal);
      expect(cubit.state.meals, isEmpty);
      expect(cubit.state.totalCalories, 0.0);
      final afterDelete = await storage.getMealsByDate(DateTime.now());
      expect(afterDelete, isEmpty);

      await cubit.close();
    });

    test('9. Thought parts in Gemini 3 response are skipped and real JSON part is extracted', () async {
      final storage = await createStorageWithKey('user_test_key_123');

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'thought': true,
                      'text': 'Let me analyze the plate and estimate macros...',
                    },
                    {
                      'text': jsonEncode({
                        'is_food': true,
                        'name': 'Avocado Toast',
                        'serving_size': 1,
                        'serving_unit': 'piece',
                        'calories': 290,
                        'protein': 8,
                        'carbs': 28,
                        'fat': 16,
                        'non_food_message': null,
                      }),
                    },
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);
      expect(result.isRight(), isTrue);
      final food = result.getOrElse((_) => throw StateError('Expected Right'));
      expect(food.name, 'Avocado Toast');
      expect(food.calories, 290.0);
      expect(food.servingUnit, 'piece');
    });

    test('10. Scan error clears isScanning and sets English error message', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final localDs = FoodLocalDataSource(prefs, storage);
      final remoteDs = FoodRemoteDataSource(storage, delay: (_) async {});
      final repo = FoodRepositoryImpl(localDs, remoteDs);

      final cubit = FoodLogCubit(
        GetDailyFoodLog(repo),
        GetWeeklyCalories(repo),
        AddFood(repo),
        DeleteFood(repo),
        UpdateFood(repo),
        DetectFoodFromImage(repo),
      );

      final emittedStates = <bool>[];
      final sub = cubit.stream.listen((s) => emittedStates.add(s.isScanning));

      await cubit.addMealFromImage(testImageFile);
      await sub.cancel();

      expect(emittedStates.first, isTrue);
      expect(cubit.state.isScanning, isFalse);
      expect(
        cubit.state.error,
        FoodRemoteDataSource.missingApiKeyErrorMessage,
      );
      expect(cubit.state.scannedMeal, isNull);
      expect(cubit.state.meals, isEmpty);

      await cubit.close();
    });
  });

  group('Barcode Lookup, SQLite Cache & Hybrid Open Food Facts Match', () {
    test('13. Barcode lookup parses Open Food Facts product and caches it for subsequent offline hits', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      var offCalls = 0;

      final offClient = MockClient((request) async {
        offCalls++;
        expect(request.url.path, contains('8410128750215.json'));
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'product_name_es': 'Bifrutas Mediterráneo',
              'brands': 'Pascual',
              'product_quantity': 330,
              'product_quantity_unit': 'ml',
              'nutriments': {
                'energy-kcal_100g': 25,
                'proteins_100g': 0.5,
                'carbohydrates_100g': 5.4,
                'fat_100g': 0,
              },
            },
          }),
          200,
        );
      });

      final localDs = FoodLocalDataSource(prefs, storage);
      final remoteDs = FoodRemoteDataSource(storage, delay: (_) async {});
      final offDs = OpenFoodFactsDataSource(client: offClient);
      final cacheDs = InMemoryBarcodeCacheDataSource();
      final repo = FoodRepositoryImpl(
        localDs,
        remoteDs,
        openFoodFacts: offDs,
        barcodeCache: cacheDs,
      );

      // First scan hits Open Food Facts
      final first = await repo.lookupFoodByBarcode('8410128750215');
      expect(first.isRight(), isTrue);
      final firstResult = first.getOrElse((_) => throw StateError('Right'));
      expect(firstResult.isFound, isTrue);
      expect(firstResult.food!.source, FoodSource.barcode);
      expect(firstResult.food!.servingSize, 330.0);
      expect(firstResult.food!.servingUnit, 'ml');
      expect(firstResult.food!.calories, closeTo(82.5, 0.1));
      expect(offCalls, 1);

      // Second scan hits local cache (0 additional HTTP calls)
      final second = await repo.lookupFoodByBarcode('8410128750215');
      expect(second.isRight(), isTrue);
      final secondResult = second.getOrElse((_) => throw StateError('Right'));
      expect(secondResult.isFound, isTrue);
      expect(secondResult.food!.calories, closeTo(82.5, 0.1));
      expect(offCalls, 1);
    });

    test('14. Barcode with missing nutriments returns not-found with partialName', () async {
      final offClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'product_name': 'Local Artisan Yogurt',
              'brands': 'Granja Local',
              'nutriments': {},
            },
          }),
          200,
        );
      });

      final offDs = OpenFoodFactsDataSource(client: offClient);
      final result = await offDs.getProductByBarcode('1234567890123');
      expect(result.isRight(), isTrue);
      final lookup = result.getOrElse((_) => throw StateError('Right'));
      expect(lookup.isFound, isFalse);
      expect(lookup.partialName, 'Local Artisan Yogurt');
    });

    test('15. Hybrid match replaces AI estimate with Open Food Facts data for packaged product without visible label', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      await storage.saveApiKey('user_test_key_123');

      final geminiClient = MockClient((request) async {
        return http.Response(
          buildGeminiSuccessBody({
            'is_food': true,
            'name': 'Bifrutas Mediterranean',
            'brand': 'Pascual',
            'is_packaged': true,
            'label_visible': false,
            'non_food_message': null,
            'ingredients': [
              {
                'name': 'Bifrutas Mediterranean',
                'amount': 330,
                'amount_unit': 'ml',
                'per_100_calories': 45,
                'per_100_protein': 1.0,
                'per_100_carbs': 10.0,
                'per_100_fat': 0.5,
              },
            ],
          }),
          200,
        );
      });

      final offClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'products': [
              {
                'product_name': 'Bifrutas Mediterranean',
                'brands': 'Pascual',
                'product_quantity': 330,
                'product_quantity_unit': 'ml',
                'nutriments': {
                  'energy-kcal_100g': 25,
                  'proteins_100g': 0.5,
                  'carbohydrates_100g': 5.4,
                  'fat_100g': 0,
                },
              },
            ],
          }),
          200,
        );
      });

      final localDs = FoodLocalDataSource(prefs, storage);
      final remoteDs = FoodRemoteDataSource(
        storage,
        client: geminiClient,
        delay: (_) async {},
      );
      final offDs = OpenFoodFactsDataSource(client: offClient);
      final repo = FoodRepositoryImpl(
        localDs,
        remoteDs,
        openFoodFacts: offDs,
        barcodeCache: InMemoryBarcodeCacheDataSource(),
      );

      final result = await repo.detectFoodFromImage(testImageFile);
      expect(result.isRight(), isTrue);
      final food = result.getOrElse((_) => throw StateError('Right'));
      expect(food.source, FoodSource.databaseMatch);
      expect(food.calories, closeTo(82.5, 0.1));
      expect(food.carbs, closeTo(17.8, 0.1));
    });
  });
}
