import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

import '../../../../core/error/failure.dart';
import '../../../../core/storage/api_key_storage.dart';
import '../../domain/entities/food.dart';

class FoodRemoteDataSource {
  final ApiKeyStorage _apiKeyStorage;
  FoodRemoteDataSource(this._apiKeyStorage);

  Future<Either<Failure, Food>> detectFoodAndCalories(File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        return left(CacheFailure('File not found', cause: imageFile.path));
      }

      final apiKey = await _apiKeyStorage.getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return left(
          const NetworkFailure(
            'Por favor, ingresa tu Gemini API Key en los Ajustes',
          ),
        );
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  },
                },
                {
                  'text':
                      'Analyze this image and identify the food. '
                      'Estimate its calories, protein, carbs, and fat. '
                      'Return JSON only, no markdown, no explanation, in this exact format: '
                      '{"name": "food name", "calories": 100, "protein": 10, "carbs": 20, "fat": 5}',
                },
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
          },
        }),
      );

      if (response.statusCode != 200) {
        return left(
          NetworkFailure(
            'Error API ${response.statusCode}: ${response.body}',
            cause: response.body,
          ),
        );
      }

      final data = jsonDecode(response.body);
      final output =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (output is! String) {
        return left(
          NetworkFailure('Invalid API response: ${response.body}', cause: data),
        );
      }

      final cleanedOutput = output
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();

      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleanedOutput);
      if (match == null) {
        return left(
          NetworkFailure('No JSON found in response: $output', cause: output),
        );
      }

      final foodData = jsonDecode(match.group(0)!);
      if (foodData is! Map) {
        return left(
          NetworkFailure('Invalid JSON in response: $output', cause: output),
        );
      }

      return right(
        Food(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: foodData['name'] as String,
          calories: (foodData['calories'] as num).toDouble(),
          protein: (foodData['protein'] as num).toDouble(),
          carbs: (foodData['carbs'] as num).toDouble(),
          fat: (foodData['fat'] as num).toDouble(),
          quantity: 100.0,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      return left(NetworkFailure('Failed to detect food: $e', cause: e));
    }
  }
}
