import 'dart:core';
import 'dart:io';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class DBHelper {
  // Singleton pattern
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "rent_in_addis.db");

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Enable foreign keys support
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT,
        password TEXT NOT NULL
      )
    ''');

    // Apartments table
    await db.execute('''
      CREATE TABLE apartments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        bedrooms INTEGER,
        bathrooms INTEGER,
        location TEXT NOT NULL,
        rent REAL
      )
    ''');

    // Tenants table
    await db.execute('''
      CREATE TABLE tenants(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        apartment_id INTEGER UNIQUE,
        lease_start TEXT,
        FOREIGN KEY(apartment_id) REFERENCES apartments(id) ON DELETE SET NULL
      )
    ''');

    // Rent Payments table
    await db.execute('''
      CREATE TABLE rent_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenant_id INTEGER NOT NULL,
        amount_paid REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_for_month TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
      )
    ''');

    // Insert sample apartments
    await db.insert('apartments', {
      'name': 'Goro Deluxe Apt',
      'bedrooms': 3,
      'bathrooms': 2,
      'location': 'Goro',
      'rent': 15000.0
    });
    await db.insert('apartments', {
      'name': 'Kazanchis Studio',
      'bedrooms': 1,
      'bathrooms': 1,
      'location': 'Kazanchis',
      'rent': 8000.0
    });
    await db.insert('apartments', {
      'name': 'Bole Road Family Home',
      'bedrooms': 4,
      'bathrooms': 3,
      'location': 'Bole',
      'rent': 25000.0
    });
  }

  // ------------------------
  // User Authentication APIs
  // ------------------------

  /// Register user. Returns the inserted user's id, or -1 if email already exists.
  Future<int> registerUser(
      String fullName, String email, String phone, String password) async {
    final db = await database;
    final hashedPassword = sha256.convert(utf8.encode(password)).toString();

    try {
      final id = await db.insert('users', {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': hashedPassword,
      });
      return id;
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (msg.contains('UNIQUE constraint failed') ||
          msg.contains('unique constraint failed')) {
        // Return -1 to indicate duplicate email / unique constraint failure
        return -1;
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Login user. Returns user row map if credentials match, otherwise null.
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await database;
    final hashedPassword = sha256.convert(utf8.encode(password)).toString();

    final result = await db.query('users',
        where: 'email = ?', whereArgs: [email], limit: 1);
    if (result.isEmpty) return null;
    final user = result.first;
    if (user['password'] == hashedPassword) {
      return user;
    }
    return null;
  }

  // ------------------------
  // Apartments / Tenants APIs
  // ------------------------

  Future<List<Map<String, dynamic>>> getApartments() async {
    final db = await database;
    return await db.query('apartments', orderBy: 'name');
  }

  Future<int> addApartment(Map<String, Object?> apartment) async {
    final db = await database;
    return await db.insert('apartments', apartment);
  }

  /// Updates an existing apartment record.
  Future<int> updateApartment(int id, Map<String, Object?> apartment) async {
    final db = await database;
    return await db.update(
      'apartments',
      apartment,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteApartment(int id) async {
    final db = await database;
    return await db.delete('apartments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getTenants() async {
    final db = await database;
    return await db.query('tenants', orderBy: 'fullName');
  }

  Future<int> addTenant(Map<String, Object?> tenant) async {
    final db = await database;
    return await db.insert('tenants', tenant);
  }

  /// Close DB if open
  Future<void> closeDB() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
