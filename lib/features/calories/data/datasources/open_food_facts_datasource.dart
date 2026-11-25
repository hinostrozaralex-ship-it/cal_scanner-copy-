import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

import '../../../../core/error/failure.dart';
import '../../domain/entities/food.dart';

class BarcodeLookupResult {
  final Food? food;
  final String? partialName;
  final String? brand;

  const BarcodeLookupResult({
    this.food,
    this.partialName,
    this.brand,
  });

  bool get isFound => food != null;
}

class OpenFoodFactsDataSource {
  static const String _userAgent =
      'CalScanner/1.0 (Flutter; https://github.com/cal_scanner)';
  static const Duration barcodeTimeout = Duration(seconds: 8);
  static const Duration searchTimeout = Duration(milliseconds: 3500);

  final http.Client _client;

  OpenFoodFactsDataSource({http.Client? client})
    : _client = client ?? http.Client();

  double _round1(double value) => double.parse(value.toStringAsFixed(1));

  double? _parseDouble(dynamic value) {
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

  String _extractProductName(Map<String, dynamic> product) {
    final candidates = [
      product['product_name_es'],
      product['product_name'],
      product['product_name_en'],
      product['generic_name'],
    ];
    for (final c in candidates) {
      final s = c?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String? _extractBrand(Map<String, dynamic> product) {
    final raw = product['brands']?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final first = raw.split(',').first.trim();
    return first.isNotEmpty ? first : null;
  }

  (double, String) _extractQuantityAndUnit(Map<String, dynamic> product) {
    final rawQty = _parseDouble(product['product_quantity']);
    final rawUnit =
        product['product_quantity_unit']?.toString().trim().toLowerCase() ?? '';
    if (rawQty != null && rawQty > 0) {
      final unit = (rawUnit == 'ml' || rawUnit == 'l' || rawUnit == 'cl')
          ? (rawUnit == 'l'
                ? 'ml'
                : rawUnit == 'cl'
                ? 'ml'
                : 'ml')
          : 'g';
      final normalizedQty = rawUnit == 'l'
          ? rawQty * 1000
          : rawUnit == 'cl'
          ? rawQty * 10
          : rawUnit == 'kg'
          ? rawQty * 1000
          : rawQty;
      return (normalizedQty, unit);
    }

    final quantityText =
        (product['quantity'] ?? product['serving_size'])?.toString() ?? '';
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(kg|g|ml|cl|l)\b',
      caseSensitive: false,
    ).firstMatch(quantityText);
    if (match != null) {
      final value = _parseDouble(match.group(1));
      final unitRaw = (match.group(2) ?? 'g').toLowerCase();
      if (value != null && value > 0) {
        if (unitRaw == 'kg') return (value * 1000, 'g');
        if (unitRaw == 'l') return (value * 1000, 'ml');
        if (unitRaw == 'cl') return (value * 10, 'ml');
        return (value, unitRaw == 'ml' ? 'ml' : 'g');
      }
    }

    return (100.0, 'g');
  }

  double? _extractPer100Calories(Map<String, dynamic> nutriments) {
    final kcal = _parseDouble(
      nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'],
    );
    if (kcal != null) return kcal;

    final kj = _parseDouble(nutriments['energy-kj_100g'] ?? nutriments['energy_100g']);
    if (kj != null) {
      return _round1(kj / 4.184);
    }
    return null;
  }

  Food? _buildFoodFromProduct(
    Map<String, dynamic> product, {
    String? barcode,
    required String source,
    double? overrideAmount,
    String? overrideUnit,
  }) {
    final name = _extractProductName(product);
    if (name.isEmpty) return null;

    final rawNutriments = product['nutriments'];
    if (rawNutriments is! Map) return null;
    final nutriments = Map<String, dynamic>.from(rawNutriments);

    final per100Cal = _extractPer100Calories(nutriments);
    if (per100Cal == null) return null;

    final per100Prot = _parseDouble(nutriments['proteins_100g']) ?? 0.0;
    final per100Carbs = _parseDouble(nutriments['carbohydrates_100g']) ?? 0.0;
    final per100Fat = _parseDouble(nutriments['fat_100g']) ?? 0.0;

    final (detectedAmount, detectedUnit) = _extractQuantityAndUnit(product);
    final amount = (overrideAmount != null && overrideAmount > 0)
        ? overrideAmount
        : detectedAmount;
    final unit = (overrideUnit != null && overrideUnit.trim().isNotEmpty)
        ? overrideUnit.trim()
        : detectedUnit;

    final factor = amount / 100.0;
    final calories = _round1(per100Cal * factor);
    final protein = _round1(per100Prot * factor);
    final carbs = _round1(per100Carbs * factor);
    final fat = _round1(per100Fat * factor);

    final brand = _extractBrand(product);
    final displayName = (brand != null &&
            !name.toLowerCase().contains(brand.toLowerCase()))
        ? '$name ($brand)'
        : name;
    final imageUrl = product['image_front_small_url']?.toString().trim();

    final ingredient = FoodIngredient(
      id: '${DateTime.now().microsecondsSinceEpoch}_0',
      name: displayName,
      quantity: amount,
      servingSize: amount,
      servingUnit: unit,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      baseCalories: calories,
      baseProtein: protein,
      baseCarbs: carbs,
      baseFat: fat,
    );

    return Food(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: displayName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      quantity: amount,
      servingSize: amount,
      servingUnit: unit,
      baseCalories: calories,
      baseProtein: protein,
      baseCarbs: carbs,
      baseFat: fat,
      imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      timestamp: DateTime.now(),
      isFood: true,
      ingredients: [ingredient],
      barcode: barcode,
      source: source,
      brand: brand,
      isPackaged: true,
      labelVisible: false,
    );
  }

  Future<Either<Failure, BarcodeLookupResult>> getProductByBarcode(
    String barcode,
  ) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) {
      return left(const NetworkFailure('Invalid barcode.'));
    }

    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$cleanCode.json'
        '?fields=product_name,product_name_es,product_name_en,generic_name,'
        'brands,quantity,product_quantity,product_quantity_unit,serving_size,'
        'nutriments,image_front_small_url',
      );

      final response = await _client
          .get(
            url,
            headers: const {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(barcodeTimeout);

      if (response.statusCode == 404) {
        return right(const BarcodeLookupResult());
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return left(
          NetworkFailure(
            'Could not query product database.',
            code: response.statusCode.toString(),
            cause: response.body,
          ),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return right(const BarcodeLookupResult());
      }

      final status = decoded['status'];
      final rawProduct = decoded['product'];
      if (status != 1 || rawProduct is! Map) {
        return right(const BarcodeLookupResult());
      }

      final product = Map<String, dynamic>.from(rawProduct);
      final food = _buildFoodFromProduct(
        product,
        barcode: cleanCode,
        source: FoodSource.barcode,
      );

      if (food != null) {
        return right(
          BarcodeLookupResult(
            food: food,
            partialName: food.name,
            brand: food.brand,
          ),
        );
      }

      final partialName = _extractProductName(product);
      final brand = _extractBrand(product);
      return right(
        BarcodeLookupResult(
          partialName: partialName.isNotEmpty ? partialName : null,
          brand: brand,
        ),
      );
    } on TimeoutException catch (e) {
      return left(
        NetworkFailure(
          'Product database took too long to respond.',
          cause: e,
        ),
      );
    } on SocketException catch (e) {
      return left(
        NetworkFailure(
          'No internet connection. Please check your network and try again.',
          cause: e,
        ),
      );
    } on http.ClientException catch (e) {
      return left(
        NetworkFailure(
          'No internet connection. Please check your network and try again.',
          cause: e,
        ),
      );
    } catch (e) {
      debugPrint('[OpenFoodFactsDataSource] getProductByBarcode error: $e');
      return left(
        NetworkFailure('Failed to read product information.', cause: e),
      );
    }
  }

  Set<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toSet();
  }

  Future<Food?> searchProductByName(
    String name, {
    String? brand,
    double? preferredAmount,
    String? preferredUnit,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    final query = (brand != null && brand.trim().isNotEmpty)
        ? '${brand.trim()} $trimmedName'
        : trimmedName;

    try {
      final url = Uri.https(
        'world.openfoodfacts.org',
        '/cgi/search.pl',
        {
          'search_terms': query,
          'search_simple': '1',
          'action': 'process',
          'json': '1',
          'page_size': '5',
          'fields':
              'product_name,product_name_es,product_name_en,generic_name,brands,quantity,product_quantity,product_quantity_unit,serving_size,nutriments,image_front_small_url',
        },
      );

      final response = await _client
          .get(
            url,
            headers: const {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(searchTimeout);

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final products = decoded['products'];
      if (products is! List || products.isEmpty) return null;

      final targetTokens = _tokenize(query);
      if (targetTokens.isEmpty) return null;

      Food? bestMatch;
      double bestScore = 0.0;

      for (final raw in products) {
        if (raw is! Map) continue;
        final product = Map<String, dynamic>.from(raw);
        final candidateFood = _buildFoodFromProduct(
          product,
          source: FoodSource.databaseMatch,
          overrideAmount: preferredAmount,
          overrideUnit: preferredUnit,
        );
        if (candidateFood == null) continue;

        final candidateTokens = _tokenize(
          '${candidateFood.name} ${candidateFood.brand ?? ''}',
        );
        if (candidateTokens.isEmpty) continue;

        final overlap = targetTokens.intersection(candidateTokens).length;
        final score = overlap / targetTokens.length;

        if (score > bestScore) {
          bestScore = score;
          bestMatch = candidateFood;
        }
      }

      // Require at least 50% token match so we never return an unrelated product.
      if (bestMatch != null && bestScore >= 0.5) {
        return bestMatch;
      }
      return null;
    } catch (e) {
      debugPrint('[OpenFoodFactsDataSource] searchProductByName ignored: $e');
      return null;
    }
  }
}
