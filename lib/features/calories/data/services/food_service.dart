import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/di/service_locator.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/food_item.dart';

class FoodService {
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

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$apiKey',
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
