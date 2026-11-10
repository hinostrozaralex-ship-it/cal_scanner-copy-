import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

import '../../../../core/error/failure.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../domain/entities/food.dart';

class FoodRemoteDataSource {
  final LocalStorageService _localStorage;

  FoodRemoteDataSource(this._localStorage);

  Future<String?> _resolveApiKey() async {
    final userProfile = await _localStorage.getUserProfile();
    final profileKey = userProfile?.apiKey?.trim();
    if (profileKey != null && profileKey.isNotEmpty) {
      return profileKey;
    }

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

  Future<Either<Failure, Food>> detectFoodAndCalories(File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        return left(CacheFailure('File not found', cause: imageFile.path));
      }

      final apiKey = await _resolveApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return left(
          const NetworkFailure(
            'Por favor, ingresa tu Gemini API Key en los Ajustes',
          ),
        );
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent',
      );

      final response = await http
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
              'generationConfig': {
                'responseMimeType': 'application/json',
                'thinkingConfig': {
                  'thinkingLevel': 'LOW',
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        return left(
          NetworkFailure(
            'Error ${response.statusCode}: ${response.body}',
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
