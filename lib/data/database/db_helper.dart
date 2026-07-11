import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/price_entry.dart';
import '../models/store.dart';

/// All price data lives only on-device. Nothing here ever talks to a network
/// endpoint belonging to Zepto/Blinkit/Instamart/BigBasket — prices arrive
/// exclusively via the manual screen-recording + OCR + user-confirm flow.
class DbHelper {
  DbHelper._internal();
  static final DbHelper instance = DbHelper._internal();
  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_grocery.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE price_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_name_ta TEXT NOT NULL,
            product_name_en TEXT NOT NULL,
            quantity TEXT NOT NULL,
            store TEXT NOT NULL,
            price REAL NOT NULL,
            discount REAL,
            captured_at TEXT NOT NULL,
            verified INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_product_en ON price_entries(product_name_en)
        ''');
      },
    );
  }

  Future<int> insertEntry(PriceEntry entry) async {
    final db = await database;
    return db.insert('price_entries', entry.toMap());
  }

  Future<List<PriceEntry>> allEntries() async {
    final db = await database;
    final rows = await db.query('price_entries', orderBy: 'captured_at DESC');
    return rows.map(PriceEntry.fromMap).toList();
  }

  /// Latest verified price per store for a given product name (English key).
  Future<List<PriceEntry>> comparePrices(String productNameEnglish) async {
    final db = await database;
    final rows = await db.query(
      'price_entries',
      where: 'product_name_en = ? AND verified = 1',
      whereArgs: [productNameEnglish],
      orderBy: 'captured_at DESC',
    );
    final entries = rows.map(PriceEntry.fromMap).toList();

    // Keep only the most recent entry per store.
    final latestByStore = <Store, PriceEntry>{};
    for (final e in entries) {
      if (!latestByStore.containsKey(e.store)) {
        latestByStore[e.store] = e;
      }
    }
    final result = latestByStore.values.toList()
      ..sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    return result;
  }

  Future<List<String>> distinctProductNames() async {
    final db = await database;
    final rows = await db.query(
      'price_entries',
      columns: ['DISTINCT product_name_en'],
      where: 'verified = 1',
    );
    return rows.map((r) => r['product_name_en'] as String).toList();
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('price_entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Wipes every saved price entry. Meant for clearing out junk data saved
  /// during testing/tuning, not something to expose without a confirmation.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('price_entries');
  }
}
