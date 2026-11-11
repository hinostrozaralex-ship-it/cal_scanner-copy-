import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

import '../../../../core/error/failure.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../domain/entities/food.dart';

const String primaryModel = 'gemini-3.8-flash';
const String fallbackModel = 'gemini-2.5-flash';
const String highDemandErrorMessage =
    "AI servers are experiencing high demand right now. Please tap 'Try Again' and retry in a few seconds.";

class FoodRemoteDataSource {
  static const String primaryModel = 'gemini-3.8-flash';
  static const String fallbackModel = 'gemini-2.5-flash';
  static const List<String> candidateModels = <String>[
    primaryModel,
    fallbackModel,
    'gemini-flash-latest',
    'gemini-2.0-flash',
    'gemini-3.5-flash-lite',
  ];

  static const Duration perAttemptTimeout = Duration(seconds: 60);
  static const Duration totalOperationTimeout = Duration(seconds: 120);
  static const Duration retryBaseDelay = Duration(milliseconds: 800);

  static const String missingApiKeyErrorMessage =
      'Please enter your Gemini API Key in Settings.';
  static const String invalidApiKeyErrorMessage =
      'Your Gemini API Key is invalid or lacks permissions. Please check your key in Settings.';
  static const String modelUnavailableErrorMessage =
      'The requested AI model is not available for your account or API key.';
  static const String quotaExceededErrorMessage =
      'Your Gemini API Key quota or rate limit has been reached. Please wait a moment or check your Google AI Studio account.';
  static const String highDemandErrorMessage =
      "AI servers are experiencing high demand right now. Please tap 'Try Again' and retry in a few seconds.";
  static const String noConnectionErrorMessage =
      'No internet connection. Please check your network and try again.';
  static const String timeoutErrorMessage =
      'The AI server took too long to respond. Please check your connection and try again.';
  static const String invalidResponseErrorMessage =
      'Could not interpret the nutritional information from this image. Please try taking a clearer photo.';
  static const String blockedResponseErrorMessage =
      'The image could not be processed due to safety policies. Please try another photo.';

  final LocalStorageService _localStorage;
  final http.Client _client;
  final Future<void> Function(Duration) _delay;
  String? _cachedDiscoveredModel;

  FoodRemoteDataSource(
    this._localStorage, {
    http.Client? client,
    Future<void> Function(Duration)? delay,
  }) : _client = client ?? http.Client(),
       _delay = delay ?? Future<void>.delayed;

  Future<String?> _resolveApiKey() async {
    final storedKey = await _localStorage.getApiKey();
    if (storedKey != null && storedKey.isNotEmpty) {
      return storedKey;
    }

    try {
      final envKey = dotenv.env['GEMINI_API_KEY']?.trim();
      if (envKey != null &&
          envKey.isNotEmpty &&
          envKey != 'tu_api_key_aqui' &&
          envKey != 'your_api_key_here') {
        return envKey;
      }
    } catch (_) {
      // dotenv may not be initialized
    }

    return null;
  }

  String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  String _sanitizeLog(String input, String apiKey) {
    if (apiKey.isEmpty) return input;
    return input.replaceAll(apiKey, '[REDACTED_API_KEY]');
  }

  void _logSafe(String message, String apiKey) {
    debugPrint('[FoodRemoteDataSource] ${_sanitizeLog(message, apiKey)}');
  }

  Future<http.Response> _sendGenerateContentRequest({
    required String model,
    required String apiKey,
    required String base64Image,
    required String mimeType,
    Duration timeout = const Duration(seconds: 60),
    bool includeThinkingConfig = true,
  }) {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    return _client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': '''
Analyze the provided image and return ONLY a valid raw JSON object (without markdown code blocks, backticks, or preamble) matching this schema:
{
  "is_food": boolean,
  "name": string,
  "serving_size": number,
  "serving_unit": string,
  "calories": number,
  "protein": number,
  "carbs": number,
  "fat": number,
  "non_food_message": string or null
}
Guidelines:
- All text fields must be in English.
- If the image shows a non-food item (person, pet, electronics, furniture), set is_food to false, set calories and macros to 0, and provide a humorous, clever non_food_message related to what is visible.
- If it is food, set is_food to true, non_food_message to null, and calculate realistic baseline nutritional values.
''',
                  },
                  {
                    'inline_data': {
                      'mime_type': 'image/jpeg',
                      'data': base64Image,
                    },
                  },
                ],
              },
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              if (includeThinkingConfig)
                'thinkingConfig': {
                  'thinkingLevel': 'LOW',
                },
              'maxOutputTokens': 800,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));
  }

  /// Consulta `GET /v1beta/models` usando la API Key del usuario únicamente
  /// si los modelos estáticos configurados devuelven 404.
  Future<String?> _discoverAvailableFlashModel({
    required String apiKey,
    required Set<String> triedModels,
    required Duration timeout,
  }) async {
    if (_cachedDiscoveredModel != null &&
        !triedModels.contains(_cachedDiscoveredModel)) {
      return _cachedDiscoveredModel;
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models',
      );
      final response = await _client
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['models'] is! List) {
        return null;
      }

      final models = decoded['models'] as List;
      final availableIds = <String>[];

      for (final item in models) {
        if (item is! Map) continue;
        final name = item['name']?.toString() ?? '';
        final methods = item['supportedGenerationMethods'];
        final supportsGenerate =
            methods is List &&
            methods.any((m) => m?.toString() == 'generateContent');
        if (!supportsGenerate || !name.startsWith('models/')) continue;

        final id = name.substring('models/'.length);
        final lower = id.toLowerCase();
        // Excluir modelos que no son de generación de texto/multimodal estándar
        if (lower.contains('embedding') ||
            lower.contains('imagen') ||
            lower.contains('veo') ||
            lower.contains('tts') ||
            lower.contains('audio') ||
            lower.contains('aqa') ||
            lower.contains('bisheng')) {
          continue;
        }
        if (lower.contains('gemini') && !triedModels.contains(id)) {
          availableIds.add(id);
        }
      }

      if (availableIds.isEmpty) return null;

      // Priorizar modelos flash
      final flashModels =
          availableIds
              .where((id) => id.toLowerCase().contains('flash'))
              .toList()
            ..sort((a, b) => b.compareTo(a));

      final selected = flashModels.isNotEmpty
          ? flashModels.first
          : availableIds.first;
      _cachedDiscoveredModel = selected;
      return selected;
    } catch (e) {
      _logSafe('Model discovery failed: $e', apiKey);
      return null;
    }
  }

  Map<String, dynamic>? _extractApiErrorObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is Map<String, dynamic>) {
          return err;
        }
      }
    } catch (_) {
      // Ignore non-JSON body
    }
    return null;
  }

  bool _isInvalidApiKeyError(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) return true;
    if (statusCode != 400) return false;

    final err = _extractApiErrorObject(body);
    final message = (err?['message']?.toString() ?? body).toLowerCase();
    final status = (err?['status']?.toString() ?? '').toUpperCase();

    if (message.contains('api_key_invalid') ||
        message.contains('api key not valid') ||
        message.contains('api key expired') ||
        message.contains('key invalid') ||
        status == 'UNAUTHENTICATED' ||
        status == 'PERMISSION_DENIED') {
      return true;
    }

    final details = err?['details'];
    if (details is List) {
      for (final d in details) {
        if (d is Map &&
            (d['reason']?.toString().toUpperCase().contains('API_KEY') ??
                false)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isModelNotAvailableError(int statusCode, String body) {
    if (statusCode == 404) return true;
    if (statusCode != 400) return false;

    final err = _extractApiErrorObject(body);
    final message = (err?['message']?.toString() ?? body).toLowerCase();
    return message.contains('is no longer available') ||
        message.contains('is not found') ||
        message.contains('is not supported for generatecontent') ||
        message.contains('model not found');
  }

  bool _isUnsupportedParameterError(int statusCode, String body) {
    if (statusCode != 400) return false;
    final err = _extractApiErrorObject(body);
    final message = (err?['message']?.toString() ?? body).toLowerCase();
    return message.contains('responseschema') ||
        message.contains('response_schema') ||
        message.contains('thinkingconfig') ||
        message.contains('unknown name');
  }

  bool _isPermanentQuotaZeroError(int statusCode, String body) {
    if (statusCode != 429) return false;
    final lower = body.toLowerCase();
    return lower.contains('limit: 0') ||
        lower.contains('quota_limit_value":"0"') ||
        lower.contains('billing');
  }

  double? _parseNonNegativeDouble(dynamic value) {
    if (value == null) return null;
    double? parsed;
    if (value is num) {
      parsed = value.toDouble();
    } else if (value is String) {
      final cleaned = value
          .trim()
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^0-9.\-]'), '');
      if (cleaned.isEmpty) return null;
      parsed = double.tryParse(cleaned);
    }
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      return null;
    }
    return parsed;
  }

  Either<Failure, Food> _parseGeminiResponse(
    String responseBody,
    String apiKey, {
    String? imagePath,
  }) {
    final dynamic data;
    try {
      data = jsonDecode(responseBody);
    } catch (e) {
      _logSafe('Failed to decode Gemini HTTP JSON: $e', apiKey);
      return left(
        NetworkFailure(invalidResponseErrorMessage, cause: responseBody),
      );
    }

    if (data is! Map<String, dynamic>) {
      return left(
        NetworkFailure(invalidResponseErrorMessage, cause: responseBody),
      );
    }

    final promptFeedback = data['promptFeedback'];
    if (promptFeedback is Map && promptFeedback['blockReason'] != null) {
      _logSafe(
        'Prompt blocked by Gemini: ${promptFeedback['blockReason']}',
        apiKey,
      );
      return left(
        NetworkFailure(blockedResponseErrorMessage, cause: promptFeedback),
      );
    }

    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      _logSafe('Gemini response has no candidates: $responseBody', apiKey);
      return left(NetworkFailure(invalidResponseErrorMessage, cause: data));
    }

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map) {
      return left(NetworkFailure(invalidResponseErrorMessage, cause: data));
    }

    final finishReason = firstCandidate['finishReason']?.toString();
    if (finishReason == 'SAFETY' ||
        finishReason == 'BLOCKLIST' ||
        finishReason == 'PROHIBITED_CONTENT') {
      _logSafe('Candidate blocked with finishReason: $finishReason', apiKey);
      return left(NetworkFailure(blockedResponseErrorMessage, cause: data));
    }

    final parts = firstCandidate['content']?['parts'];
    String? outputText;
    if (parts is List) {
      for (final part in parts) {
        if (part is Map && part['text'] is String) {
          final text = (part['text'] as String).trim();
          if (text.isNotEmpty) {
            outputText = text;
            break;
          }
        }
      }
    }

    if (outputText == null || outputText.isEmpty) {
      _logSafe('No text part found in Gemini candidate: $responseBody', apiKey);
      return left(NetworkFailure(invalidResponseErrorMessage, cause: data));
    }

    final cleanedOutput = outputText
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();

    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleanedOutput);
    if (match == null) {
      _logSafe('No JSON object found in model output: $outputText', apiKey);
      return left(
        NetworkFailure(invalidResponseErrorMessage, cause: outputText),
      );
    }

    final dynamic foodData;
    try {
      foodData = jsonDecode(match.group(0)!);
    } catch (e) {
      _logSafe('Invalid JSON inside model output: $outputText ($e)', apiKey);
      return left(
        NetworkFailure(invalidResponseErrorMessage, cause: outputText),
      );
    }

    if (foodData is! Map) {
      return left(
        NetworkFailure(invalidResponseErrorMessage, cause: outputText),
      );
    }

    final rawIsFood = foodData['is_food'] ?? foodData['isFood'];
    final bool isFood = rawIsFood is bool
        ? rawIsFood
        : (rawIsFood?.toString().toLowerCase() != 'false');

    final rawName = foodData['name']?.toString().trim() ?? '';
    final parsedServingSize = _parseNonNegativeDouble(
      foodData['serving_size'] ?? foodData['servingSize'],
    );
    final servingSize = (parsedServingSize != null && parsedServingSize > 0)
        ? parsedServingSize
        : (isFood ? 100.0 : 1.0);

    final rawServingUnit =
        (foodData['serving_unit'] ?? foodData['servingUnit'])
            ?.toString()
            .trim() ??
        '';
    final servingUnit = rawServingUnit.isNotEmpty ? rawServingUnit : 'g';

    final calories = _parseNonNegativeDouble(foodData['calories']);
    final protein = _parseNonNegativeDouble(foodData['protein']);
    final carbs = _parseNonNegativeDouble(foodData['carbs']);
    final fat = _parseNonNegativeDouble(foodData['fat']);

    final rawNonFoodMsg =
        (foodData['non_food_message'] ?? foodData['nonFoodMessage'])
            ?.toString()
            .trim();

    if (!isFood) {
      final safeName = rawName.isNotEmpty ? rawName : 'Non-Food Object';
      final wittyMsg = (rawNonFoodMsg != null && rawNonFoodMsg.isNotEmpty)
          ? rawNonFoodMsg
          : '$safeName is great to look at, but it has zero nutritional value! Please scan an edible food or drink.';

      return right(
        Food(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: safeName,
          calories: 0.0,
          protein: 0.0,
          carbs: 0.0,
          fat: 0.0,
          quantity: servingSize,
          imageUrl: imagePath,
          timestamp: DateTime.now(),
          isFood: false,
          servingSize: servingSize,
          servingUnit: servingUnit,
          baseCalories: 0.0,
          baseProtein: 0.0,
          baseCarbs: 0.0,
          baseFat: 0.0,
          nonFoodMessage: wittyMsg,
        ),
      );
    }

    if (rawName.isEmpty ||
        calories == null ||
        protein == null ||
        carbs == null ||
        fat == null ||
        calories < 0 ||
        protein < 0 ||
        carbs < 0 ||
        fat < 0) {
      _logSafe('Incomplete or invalid nutritional fields: $foodData', apiKey);
      return left(
        NetworkFailure(invalidResponseErrorMessage, cause: foodData),
      );
    }

    return right(
      Food(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: rawName,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        quantity: servingSize,
        imageUrl: imagePath,
        timestamp: DateTime.now(),
        isFood: true,
        servingSize: servingSize,
        servingUnit: servingUnit,
        baseCalories: calories,
        baseProtein: protein,
        baseCarbs: carbs,
        baseFat: fat,
        nonFoodMessage: null,
      ),
    );
  }

  Future<Either<Failure, Food>> detectFoodAndCalories(File imageFile) async {
    String apiKey = '';
    try {
      if (!imageFile.existsSync()) {
        return left(
          CacheFailure(
            'Captured image file was not found.',
            cause: imageFile.path,
          ),
        );
      }

      final resolvedKey = await _resolveApiKey();
      if (resolvedKey == null || resolvedKey.isEmpty) {
        return left(const NetworkFailure(missingApiKeyErrorMessage));
      }
      apiKey = resolvedKey;

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final mimeType = _detectMimeType(imageFile.path);

      final stopwatch = Stopwatch()..start();
      final modelsQueue = List<String>.from(candidateModels);
      final triedModels = <String>{};
      bool discoveryAttempted = false;

      int? lastStatusCode;
      String? lastResponseBody;
      bool hadTimeout = false;

      var index = 0;
      while (index < modelsQueue.length) {
        final remaining = totalOperationTimeout - stopwatch.elapsed;
        if (remaining <= const Duration(seconds: 2)) {
          hadTimeout = true;
          break;
        }

        final model = modelsQueue[index];
        index++;
        triedModels.add(model);

        final attemptTimeout = remaining < perAttemptTimeout
            ? remaining
            : perAttemptTimeout;

        http.Response response;
        try {
          response = await _sendGenerateContentRequest(
            model: model,
            apiKey: apiKey,
            base64Image: base64Image,
            mimeType: mimeType,
            timeout: attemptTimeout,
          );
        } on TimeoutException catch (e) {
          hadTimeout = true;
          _logSafe('Timeout on model $model: $e', apiKey);
          return left(NetworkFailure(timeoutErrorMessage, cause: e));
        } on SocketException catch (e) {
          _logSafe('SocketException on model $model: $e', apiKey);
          return left(NetworkFailure(noConnectionErrorMessage, cause: e));
        } on http.ClientException catch (e) {
          _logSafe('ClientException on model $model: $e', apiKey);
          return left(NetworkFailure(noConnectionErrorMessage, cause: e));
        }

        lastStatusCode = response.statusCode;
        lastResponseBody = response.body;

        if (response.statusCode == 200) {
          return _parseGeminiResponse(
            response.body,
            apiKey,
            imagePath: imageFile.path,
          );
        }

        _logSafe(
          'Model $model returned HTTP ${response.statusCode}: ${response.body}',
          apiKey,
        );

        // 1. Clave API inválida o sin permisos -> fallo inmediato sin reintentar
        if (_isInvalidApiKeyError(response.statusCode, response.body)) {
          return left(
            NetworkFailure(invalidApiKeyErrorMessage, cause: response.body),
          );
        }

        // 2. Parámetro de configuración no soportado por ese modelo (p. ej. responseSchema)
        if (_isUnsupportedParameterError(response.statusCode, response.body)) {
          final retryRemaining = totalOperationTimeout - stopwatch.elapsed;
          if (retryRemaining > const Duration(seconds: 3)) {
            try {
              final plainResponse = await _sendGenerateContentRequest(
                model: model,
                apiKey: apiKey,
                base64Image: base64Image,
                mimeType: mimeType,
                timeout: retryRemaining < perAttemptTimeout
                    ? retryRemaining
                    : perAttemptTimeout,
                includeThinkingConfig: false,
              );
              lastStatusCode = plainResponse.statusCode;
              lastResponseBody = plainResponse.body;
              if (plainResponse.statusCode == 200) {
                return _parseGeminiResponse(
                  plainResponse.body,
                  apiKey,
                  imagePath: imageFile.path,
                );
              }
            } on TimeoutException catch (e) {
              return left(NetworkFailure(timeoutErrorMessage, cause: e));
            } on SocketException catch (e) {
              return left(NetworkFailure(noConnectionErrorMessage, cause: e));
            }
          }
        }

        // 3. Modelo no encontrado (404) o retirado para esta cuenta -> pasar al siguiente candidato
        if (_isModelNotAvailableError(lastStatusCode, lastResponseBody)) {
          if (index >= modelsQueue.length && !discoveryAttempted) {
            discoveryAttempted = true;
            final discRemaining = totalOperationTimeout - stopwatch.elapsed;
            if (discRemaining > const Duration(seconds: 4)) {
              final discovered = await _discoverAvailableFlashModel(
                apiKey: apiKey,
                triedModels: triedModels,
                timeout: const Duration(seconds: 6),
              );
              if (discovered != null && !triedModels.contains(discovered)) {
                modelsQueue.add(discovered);
              }
            }
          }
          continue;
        }

        // 4. Límite de cuota (429) o alta demanda / error temporal de servidor (500, 502, 503, 504)
        if (lastStatusCode == 429 ||
            lastStatusCode == 500 ||
            lastStatusCode == 502 ||
            lastStatusCode == 503 ||
            lastStatusCode == 504) {
          // No reintentar infinitamente: máximo 2 modelos intentados ante saturación/rate-limit
          if (triedModels.length >= 2) {
            break;
          }
          // Si es un 429 de cuota global 0 en el proyecto, cambiar de modelo si hay otro,
          // pero con una breve espera progresiva para no saturar la API.
          final waitRemaining = totalOperationTimeout - stopwatch.elapsed;
          if (waitRemaining > const Duration(seconds: 4) &&
              index < modelsQueue.length) {
            await _delay(retryBaseDelay * triedModels.length);
            continue;
          }
          break;
        }

        // 5. Otros errores HTTP 4xx de solicitud -> no hacer fallback indiscriminado
        break;
      }

      if (hadTimeout && lastStatusCode == null) {
        return left(const NetworkFailure(timeoutErrorMessage));
      }

      if (lastStatusCode == 429) {
        final message = _isPermanentQuotaZeroError(
              lastStatusCode!,
              lastResponseBody ?? '',
            )
            ? quotaExceededErrorMessage
            : highDemandErrorMessage;
        return left(NetworkFailure(message, cause: lastResponseBody));
      }

      if (lastStatusCode == 500 ||
          lastStatusCode == 502 ||
          lastStatusCode == 503 ||
          lastStatusCode == 504) {
        return left(
          NetworkFailure(highDemandErrorMessage, cause: lastResponseBody),
        );
      }

      if (lastStatusCode != null &&
          _isModelNotAvailableError(lastStatusCode, lastResponseBody ?? '')) {
        return left(
          NetworkFailure(modelUnavailableErrorMessage, cause: lastResponseBody),
        );
      }

      if (lastStatusCode != null &&
          _isInvalidApiKeyError(lastStatusCode, lastResponseBody ?? '')) {
        return left(
          NetworkFailure(invalidApiKeyErrorMessage, cause: lastResponseBody),
        );
      }

      return left(
        NetworkFailure(invalidResponseErrorMessage, cause: lastResponseBody),
      );
    } on TimeoutException catch (e) {
      _logSafe('Unhandled TimeoutException: $e', apiKey);
      return left(NetworkFailure(timeoutErrorMessage, cause: e));
    } on SocketException catch (e) {
      _logSafe('Unhandled SocketException: $e', apiKey);
      return left(NetworkFailure(noConnectionErrorMessage, cause: e));
    } on http.ClientException catch (e) {
      _logSafe('Unhandled ClientException: $e', apiKey);
      return left(NetworkFailure(noConnectionErrorMessage, cause: e));
    } catch (e) {
      _logSafe('Unexpected exception in detectFoodAndCalories: $e', apiKey);
      return left(NetworkFailure(invalidResponseErrorMessage, cause: e));
    }
  }
}
