import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:crypto/crypto.dart'; // Import for hashing
import 'dart:convert'; // Import for utf8 encoding

class DBHelper {
  // 1. Singleton pattern implementation
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _db;

  // 2. Database getter (initializes if null)
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  // 3. Database initialization
  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "rent_in_addis.db");
    
    // Open the database or create it if it doesn't exist
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // 4. Database table creation and sample data insertion
  Future _onCreate(Database db, int version) async {
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

    print("Database created and sample data inserted!");
  }

  ---

  ## 🔐 User Authentication Methods

  ### Register User

  This method securely **hashes the password** using SHA-256 before inserting the user record into the `users` table.

  * Returns the **ID** of the newly inserted user row, or an error code (like `-1` on unique constraint violation) depending on the `sqflite` implementation details.

  ```dart
  Future<int> registerUser(String fullName, String email, String phone, String password) async {
    final db = await database;
    
    // Hash the password using SHA-256
    String hashedPassword = sha256.convert(utf8.encode(password)).toString();

    return await db.insert('users', {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'password': hashedPassword,
    });
  }