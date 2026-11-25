import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../../core/models/meal_record.dart';
import '../../domain/entities/food.dart';

abstract class BarcodeCacheDataSource {
  Future<Food?> getProduct(String barcode);
  Future<void> saveProduct(String barcode, Food product);
}

class SqliteBarcodeCacheDataSource implements BarcodeCacheDataSource {
  static const String _dbName = 'cal_scanner_barcodes.db';
  static const String _tableName = 'barcode_products';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> _getDatabase() async {
    if (_db != null && _db!.isOpen) return _db!;

    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            barcode TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  @override
  Future<Food?> getProduct(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    try {
      final db = await _getDatabase();
      final rows = await db.query(
        _tableName,
        columns: ['payload'],
        where: 'barcode = ?',
        whereArgs: [cleanCode],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final payload = rows.first['payload'] as String?;
      if (payload == null || payload.isEmpty) return null;

      final food = MealRecord.fromJson(payload).toFood();
      return food.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        barcode: cleanCode,
      );
    } catch (e) {
      debugPrint('[SqliteBarcodeCacheDataSource] getProduct error: $e');
      return null;
    }
  }

  @override
  Future<void> saveProduct(String barcode, Food product) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return;

    try {
      final db = await _getDatabase();
      final record = MealRecord.fromFood(product.copyWith(barcode: cleanCode));
      await db.insert(
        _tableName,
        {
          'barcode': cleanCode,
          'payload': record.toJson(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[SqliteBarcodeCacheDataSource] saveProduct error: $e');
    }
  }
}

class InMemoryBarcodeCacheDataSource implements BarcodeCacheDataSource {
  final Map<String, String> _store = {};

  @override
  Future<Food?> getProduct(String barcode) async {
    final cleanCode = barcode.trim();
    final raw = _store[cleanCode];
    if (raw == null) return null;
    return MealRecord.fromJson(raw).toFood().copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      barcode: cleanCode,
    );
  }

  @override
  Future<void> saveProduct(String barcode, Food product) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return;
    _store[cleanCode] =
        MealRecord.fromFood(product.copyWith(barcode: cleanCode)).toJson();
  }
}
