import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/di/service_locator.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/food_item.dart';

const String primaryModel = 'gemini-3.8-flash';
const String fallbackModel = 'gemini-2.5-flash';
const String highDemandErrorMessage =
    "Los servidores de IA están experimentando alta demanda en este momento. Por favor, pulsa 'Retake' y prueba de nuevo en unos segundos.";

class FoodService {
  static const String primaryModel = 'gemini-3.8-flash';
  static const String fallbackModel = 'gemini-2.5-flash';
  static const String highDemandErrorMessage =
      "Los servidores de IA están experimentando alta demanda en este momento. Por favor, pulsa 'Retake' y prueba de nuevo en unos segundos.";

  Future<String?> _resolveApiKey() async {
    if (sl.isRegistered<LocalStorageService>()) {
      final storage = sl<LocalStorageService>();
      final profile = await storage.getUserProfile();
      final profileKey = profile?.apiKey?.trim();
      if (profileKey != null && profileKey.isNotEmpty) {
        return profileKey;
      }
      final storedKey = await storage.getApiKey();
      if (storedKey != null && storedKey.isNotEmpty) {
        return storedKey;
      }
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

  Future<http.Response> _sendGenerateContentRequest({
    required String model,
    required String apiKey,
    required String base64Image,
  }) {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final generationConfig = <String, dynamic>{
      'responseMimeType': 'application/json',
    };

    if (model.contains('3.')) {
      generationConfig['thinkingConfig'] = {
        'thinkingLevel': 'LOW',
      };
    }

    return http
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
                    'text':
                        'Analyze this food item. Return ONLY a valid raw JSON object with keys: name (string), calories (number), protein (number), carbs (number), fat (number). Do not include markdown codeblocks or extra text.',
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
            'generationConfig': generationConfig,
          }),
        )
        .timeout(const Duration(seconds: 60));
  }

  Future<Either<String, FoodItem>> detectFoodAndCalories(File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        return Left('File not found: ${imageFile.path}');
      }

      final apiKey = await _resolveApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return const Left(
          'Por favor, ingresa tu Gemini API Key en los Ajustes',
        );
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      http.Response response = await _sendGenerateContentRequest(
        model: primaryModel,
        apiKey: apiKey,
        base64Image: base64Image,
      );

      // Si el modelo principal responde con 503 (alta demanda) o 429 (rate limit),
      // reintenta inmediatamente con el modelo de respaldo.
      if (response.statusCode == 503 || response.statusCode == 429) {
        response = await _sendGenerateContentRequest(
          model: fallbackModel,
          apiKey: apiKey,
          base64Image: base64Image,
        );

        if (response.statusCode == 503 || response.statusCode == 429) {
          return const Left(highDemandErrorMessage);
        }
      }

      if (response.statusCode != 200) {
        return Left('Error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final output =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (output == null) {
        return Left('Invalid API response: ${response.body}');
      }

      final cleanedOutput = output
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();

      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleanedOutput);
      if (match == null) {
        return Left('No valid JSON found in response: $output');
      }

      final foodData = jsonDecode(match.group(0)!);

      return Right(
        FoodItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: foodData['name'],
          calories: (foodData['calories'] as num).toDouble(),
          protein: (foodData['protein'] as num).toDouble(),
          carbs: (foodData['carbs'] as num).toDouble(),
          fat: (foodData['fat'] as num).toDouble(),
          quantity: 100.0,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      return Left('Failed to detect food: ${e.toString()}');
    }
  }
}
