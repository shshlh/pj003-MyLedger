import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/book.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/periodic_bill.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._();

  Database? _db;
  final _uuid = const Uuid();
  final _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  final _dayFmt = DateFormat('yyyy-MM-dd');

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'account_book.db');
    return openDatabase(path, version: 1, onCreate: _createTables, onUpgrade: _upgradeDb);
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cover TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'CNY',
        status TEXT NOT NULL DEFAULT 'active',
        billing_day INTEGER,
        repayment_day INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        parent_id TEXT,
        icon TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        to_account_id TEXT,
        category_id TEXT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        datetime TEXT NOT NULL,
        note TEXT,
        is_investment INTEGER NOT NULL DEFAULT 0,
        related_investment_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id),
        FOREIGN KEY (account_id) REFERENCES accounts(id),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE periodic_bills (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        account_id TEXT NOT NULL,
        category_id TEXT,
        frequency TEXT NOT NULL,
        interval_days INTEGER,
        start_date TEXT NOT NULL,
        end_date TEXT,
        next_run_date TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id),
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
    ''');
  }

  Future<void> _upgradeDb(Database db, int oldV, int newV) async {}

  Future<Book> initDefaultBook() async {
    final now = _fmt.format(DateTime.now());
    final book = Book(id: _uuid.v4(), name: '我的账本', createdAt: now, updatedAt: now);
    final db = await this.db;
    await db.insert('books', book.toMap());
    await _initDefaultCategories(db, book.id);
    return book;
  }

  Future<void> _initDefaultCategories(Database db, String bookId) async {
    final now = _fmt.format(DateTime.now());
    final expenseCats = ['餐饮', '交通', '住房', '购物', '医疗', '教育', '娱乐', '人情'];
    final incomeCats = ['工资', '奖金', '投资收益', '兼职', '红包', '其他'];
    for (final name in expenseCats) {
      await db.insert('categories', {
        'id': _uuid.v4(), 'book_id': bookId, 'name': name,
        'type': 'expense', 'sort_order': 0, 'created_at': now,
      });
    }
    for (final name in incomeCats) {
      await db.insert('categories', {
        'id': _uuid.v4(), 'book_id': bookId, 'name': name,
        'type': 'income', 'sort_order': 0, 'created_at': now,
      });
    }
  }

  Future<Book?> getBook(String id) async {
    final list = await (await db).query('books', where: 'id=?', whereArgs: [id]);
    return list.isEmpty ? null : Book.fromMap(list.first);
  }

  Future<List<Account>> getAccounts(String bookId) async {
    final list = await (await db).query('accounts',
      where: "book_id=? AND status!='deleted'", whereArgs: [bookId],
      orderBy: 'sort_order, name');
    return list.map((m) => Account.fromMap(m)).toList();
  }

  Future<void> saveAccount(Account a) async {
    await (await db).insert('accounts', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> archiveAccount(String id) async {
    final now = _fmt.format(DateTime.now());
    await (await db).update('accounts', {'status': 'archived', 'updated_at': now}, where: 'id=?', whereArgs: [id]);
  }

  Future<List<Category>> getCategories(String bookId, {String? type}) async {
    String where = 'book_id=?';
    List args = [bookId];
    if (type != null) { where += ' AND type=?'; args.add(type); }
    final list = await (await db).query('categories', where: where, whereArgs: args, orderBy: 'sort_order, name');
    return list.map((m) => Category.fromMap(m)).toList();
  }

  Future<void> recordTransaction({
    required String bookId,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required String type,
    required double amount,
    String? note,
    int isInvestment = 0,
    String? relatedInvestmentId,
  }) async {
    final now = _fmt.format(DateTime.now());
    final t = Transaction(
      id: _uuid.v4(), bookId: bookId, accountId: accountId,
      toAccountId: toAccountId, categoryId: categoryId,
      type: type, amount: amount,
      datetime: now, note: note,
      isInvestment: isInvestment,
      relatedInvestmentId: relatedInvestmentId,
      createdAt: now,
    );
    final d = await db;
    await d.transaction((txn) async {
      await txn.insert('transactions', t.toMap());
      if (type == 'expense' || type == 'invest') {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
          [amount, now, accountId]);
      } else if (type == 'income') {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [amount, now, accountId]);
      } else if (type == 'transfer') {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
          [amount, now, accountId]);
        if (toAccountId != null) {
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
            [amount, now, toAccountId]);
        }
      }
    });
  }

  Future<List<Transaction>> getTransactions(String bookId, {int? limit, int? offset}) async {
    final list = await (await db).query('transactions',
      where: 'book_id=?', whereArgs: [bookId],
      orderBy: 'datetime DESC',
      limit: limit, offset: offset);
    return list.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<Map<String, double>> getMonthlySummary(String bookId, int year, int month) async {
    final d = await db;
    final ym = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final expense = await d.rawQuery(
      "SELECT COALESCE(SUM(amount),0) AS total FROM transactions WHERE book_id=? AND type='expense' AND is_investment=0 AND datetime LIKE ?",
      [bookId, '$ym%']);
    final income = await d.rawQuery(
      "SELECT COALESCE(SUM(amount),0) AS total FROM transactions WHERE book_id=? AND type='income' AND is_investment=0 AND datetime LIKE ?",
      [bookId, '$ym%']);
    return {
      'expense': (expense.first['total'] as num).toDouble(),
      'income': (income.first['total'] as num).toDouble(),
    };
  }

  Future<List<PeriodicBill>> getDueBills() async {
    final today = _dayFmt.format(DateTime.now());
    final list = await (await db).query('periodic_bills',
      where: 'enabled=1 AND next_run_date<=?', whereArgs: [today]);
    return list.map((m) => PeriodicBill.fromMap(m)).toList();
  }

  Future<void> savePeriodicBill(PeriodicBill bill) async {
    await (await db).insert('periodic_bills', bill.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> runDueBills() async {
    final bills = await getDueBills();
    for (final bill in bills) {
      await recordTransaction(
        bookId: bill.bookId, accountId: bill.accountId,
        categoryId: bill.categoryId, type: bill.type,
        amount: bill.amount, note: bill.name,
      );
      final next = _calcNextRun(bill);
      final now = _fmt.format(DateTime.now());
      await (await db).update('periodic_bills',
        {'next_run_date': _dayFmt.format(next), 'updated_at': now},
        where: 'id=?', whereArgs: [bill.id]);
    }
    return bills.length;
  }

  DateTime _calcNextRun(PeriodicBill bill) {
    final current = DateTime.parse(bill.nextRunDate);
    switch (bill.frequency) {
      case 'daily':   return current.add(const Duration(days: 1));
      case 'weekly':  return current.add(const Duration(days: 7));
      case 'monthly': return DateTime(current.year, current.month + 1, current.day);
      case 'yearly':  return DateTime(current.year + 1, current.month, current.day);
      case 'custom':  return current.add(Duration(days: bill.intervalDays ?? 30));
      default:        return current.add(const Duration(days: 30));
    }
  }
}
