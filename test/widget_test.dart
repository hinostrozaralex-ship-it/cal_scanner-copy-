import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cal_scanner/core/storage/local_storage_service.dart';
import 'package:cal_scanner/features/calories/data/datasources/food_local_datasource.dart';
import 'package:cal_scanner/features/calories/data/datasources/food_remote_datasource.dart';
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

  group('FoodRemoteDataSource — Gemini API & Error Handling', () {
    test('1. Respuesta correcta de Gemini parsea Food y asigna imageUrl', () async {
      final storage = await createStorageWithKey('user_test_key_123');
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;

      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return http.Response(
          buildGeminiSuccessBody({
            'name': 'Pollo a la plancha',
            'calories': 320,
            'protein': 42.5,
            'carbs': 3,
            'fat': 14.2,
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
      expect(food.name, 'Pollo a la plancha');
      expect(food.calories, 320.0);
      expect(food.protein, 42.5);
      expect(food.carbs, 3.0);
      expect(food.fat, 14.2);
      expect(food.imageUrl, testImageFile.path);
    });

    test('2. Modelo no disponible (404) hace fallback a modelo alternativo válido', () async {
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
                'message': 'models/gemini-flash-latest is not found',
                'status': 'NOT_FOUND',
              },
            }),
            404,
          );
        }

        return http.Response(
          buildGeminiSuccessBody({
            'name': 'Ensalada César',
            'calories': 250,
            'protein': 18,
            'carbs': 12,
            'fat': 15,
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

    test('3. Si todos los modelos devuelven 404, muestra mensaje comprensible de modelo no disponible', () async {
      final storage = await createStorageWithKey('user_test_key_123');

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 404,
              'message': 'Model not found for API version v1beta',
              'status': 'NOT_FOUND',
            },
          }),
          404,
        );
      });

      final dataSource = FoodRemoteDataSource(
        storage,
        client: client,
        delay: (_) async {},
      );

      final result = await dataSource.detectFoodAndCalories(testImageFile);
      expect(result.isLeft(), isTrue);
      final errorMsg = result.fold((l) => l.message, (_) => '');
      expect(errorMsg, FoodRemoteDataSource.modelUnavailableErrorMessage);
      expect(errorMsg, isNot(contains('NOT_FOUND')));
    });

    test('4. API Key inválida (400 API_KEY_INVALID o 403) falla sin hacer fallback indiscriminado ni exponer JSON', () async {
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
      expect(callCount, 1); // No reintenta con otros modelos ante clave inválida
      final errorMsg = result.fold((l) => l.message, (_) => '');
      expect(errorMsg, FoodRemoteDataSource.invalidApiKeyErrorMessage);
      expect(errorMsg, isNot(contains('INVALID_ARGUMENT')));
      expect(errorMsg, isNot(contains('invalid_key_999')));
    });

    test('5. HTTP 503 y 429 hacen un único fallback y devuelven mensaje claro si persiste', () async {
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
      expect(callCount, 2); // Principal + 1 alternativo máximo
      final errorMsg = result.fold((l) => l.message, (_) => '');
      expect(errorMsg, FoodRemoteDataSource.highDemandErrorMessage);
    });

    test('6. HTTP 429 con cuota agotada (limit: 0) informa límite de cuota sin bucle infinito', () async {
      final storage = await createStorageWithKey('user_test_key_123');
      var callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'error': {
              'code': 429,
              'message': 'Quota exceeded for quota metric and limit: 0',
              'status': 'RESOURCE_EXHAUSTED',
            },
          }),
          429,
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
      expect(errorMsg, FoodRemoteDataSource.quotaExceededErrorMessage);
    });

    test('7. Timeout y SocketException devuelven mensajes en español comprensibles', () async {
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

    test('8. JSON incompleto, nulo o malformado no lanza TypeError y devuelve mensaje amigable', () async {
      final storage = await createStorageWithKey('user_test_key_123');

      final incompleteClient = MockClient((request) async {
        return http.Response(
          buildGeminiSuccessBody({
            'name': 'Manzana',
            'calories': null, // Campo nulo que antes lanzaba TypeError
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
  });

  group('FoodLogCubit — Escaneo, guardado único y manejo de estado isScanning', () {
    test('9. Escaneo correcto guarda el alimento una sola vez y desactiva isScanning', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      await storage.saveApiKey('user_test_key_123');

      final client = MockClient((request) async {
        return http.Response(
          buildGeminiSuccessBody({
            'name': 'Salmón al horno',
            'calories': 410,
            'protein': 38,
            'carbs': 2,
            'fat': 26,
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

      await cubit.addMealFromImage(testImageFile);

      expect(cubit.state.isScanning, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.scannedMeal, isNotNull);
      expect(cubit.state.scannedMeal!.name, 'Salmón al horno');
      expect(cubit.state.meals.length, 1);
      expect(cubit.state.totalCalories, 410.0);

      // Verificar que en LocalStorageService también hay exactamente 1 registro sin duplicados
      final savedRecords = await storage.getMealsByDate(DateTime.now());
      expect(savedRecords.length, 1);
      expect(savedRecords.first.name, 'Salmón al horno');

      await cubit.close();
    });

    test('10. Error de escaneo limpia isScanning y registra el mensaje de error', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      // Sin API Key configurada

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
}
