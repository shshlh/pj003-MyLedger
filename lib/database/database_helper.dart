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

  /// 测试专用：注入内存数据库，替代单例的生产数据库
  static Database? _testDb;
  static void useTestDatabase(Database? db) { _testDb = db; }

  Database? _db;
  final _uuid = const Uuid();
  final _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  final _dayFmt = DateFormat('yyyy-MM-dd');

  Future<Database> get db async {
    if (_testDb != null) return _testDb!;
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'account_book.db');
    return openDatabase(path, version: 4, onCreate: _createTables, onUpgrade: _upgradeDb);
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
        batch_id TEXT,
       created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
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
        updated_at TEXT,
        FOREIGN KEY (book_id) REFERENCES books(id),
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
   ''');
    await db.execute('''
      CREATE TABLE investment_holdings (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        code TEXT NOT NULL,
        name TEXT,
        inv_type TEXT NOT NULL,
        total_cost REAL DEFAULT 0,
        total_shares REAL DEFAULT 0,
        latest_nav REAL,
        nav_date TEXT,
        fee_type TEXT DEFAULT 'A',
        is_liquidated INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id),
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
    ''');
  }

 Future<void> _upgradeDb(Database db, int oldV, int newV) async {
    if (oldV < 4) {
      await db.execute("ALTER TABLE periodic_bills ADD COLUMN updated_at TEXT");
    }
   if (oldV < 3) {
      await db.execute("ALTER TABLE transactions ADD COLUMN batch_id TEXT");
    }
    if (oldV < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS investment_holdings (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          account_id TEXT NOT NULL,
          code TEXT NOT NULL,
          name TEXT,
          inv_type TEXT NOT NULL,
          total_cost REAL DEFAULT 0,
          total_shares REAL DEFAULT 0,
          latest_nav REAL,
          nav_date TEXT,
          fee_type TEXT DEFAULT 'A',
          is_liquidated INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (book_id) REFERENCES books(id),
          FOREIGN KEY (account_id) REFERENCES accounts(id)
        )
      ''');
    }
  }

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
   String? datetime,
    int isInvestment = 0,
    String? relatedInvestmentId,
  }) async {
    final now = _fmt.format(DateTime.now());
    final txnDatetime = datetime ?? now;
    final t = Transaction(
      id: _uuid.v4(), bookId: bookId, accountId: accountId,
      toAccountId: toAccountId, categoryId: categoryId,
      type: type, amount: amount,
      datetime: txnDatetime, note: note,
      isInvestment: isInvestment,
      relatedInvestmentId: relatedInvestmentId,
      createdAt: now,
      updatedAt: now,
    );
    final d = await db;
    await d.transaction((txn) async {
      await txn.insert('transactions', t.toMap());
      if (type == 'expense' || type == 'invest') {
        final acctRows = await txn.query('accounts',
          columns: ['type'], where: 'id=?', whereArgs: [accountId]);
        final isCredit = acctRows.isNotEmpty && acctRows.first['type'] == 'credit';
        if (isCredit) {
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
            [amount, now, accountId]);
        } else {
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
            [amount, now, accountId]);
        }
     } else if (type == 'income') {
        final incRows = await txn.query('accounts',
          columns: ['type'], where: 'id=?', whereArgs: [accountId]);
        final isCredit = incRows.isNotEmpty && incRows.first['type'] == 'credit';
        if (isCredit) {
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
            [amount, now, accountId]);
        } else {
         await txn.rawUpdate(
           'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
           [amount, now, accountId]);
        }
     } else if (type == 'transfer') {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
          [amount, now, accountId]);
        if (toAccountId != null) {
          final toRows = await txn.query('accounts',
            columns: ['type'], where: 'id=?', whereArgs: [toAccountId]);
          final isCredit = toRows.isNotEmpty && toRows.first['type'] == 'credit';
          if (isCredit) {
            await txn.rawUpdate(
              'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
              [amount, now, toAccountId]);
          } else {
            await txn.rawUpdate(
              'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
              [amount, now, toAccountId]);
          }
        }
      }
   });
 }

  /// 直接修改交易金额/备注/日期（delta 调余额，不再删重建）
  Future<void> updateTransactionAmount({
    required String id,
    required double amount,
    String? note,
    String? datetime,
    String? categoryId,
  }) async {
    final d = await db;
    final rows = await d.query('transactions', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final t = Transaction.fromMap(rows.first);
    final delta = amount - t.amount;
    final now = _fmt.format(DateTime.now());
    final txnDatetime = datetime ?? t.datetime;

    if (delta == 0 && note == null && datetime == null && categoryId == null) return;

    await d.transaction((txn) async {
      if (delta != 0) {
        final fromRows = await txn.query('accounts',
          columns: ['type'], where: 'id=?', whereArgs: [t.accountId]);
        final isCredit = fromRows.isNotEmpty && fromRows.first['type'] == 'credit';

        if (t.type == 'expense' || t.type == 'invest') {
          await txn.rawUpdate(
            isCredit
              ? 'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?'
              : 'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
            [delta, now, t.accountId]);
        } else if (t.type == 'income') {
          await txn.rawUpdate(
            isCredit
              ? 'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?'
              : 'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
            [delta, now, t.accountId]);
        } else if (t.type == 'transfer') {
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
            [delta, now, t.accountId]);
          if (t.toAccountId != null) {
            final toRows = await txn.query('accounts',
              columns: ['type'], where: 'id=?', whereArgs: [t.toAccountId]);
            final isToCredit = toRows.isNotEmpty && toRows.first['type'] == 'credit';
            await txn.rawUpdate(
              isToCredit
                ? 'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?'
                : 'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
              [delta, now, t.toAccountId!]);
          }
        }
      }

      final updates = <String, dynamic>{'updated_at': now, 'datetime': txnDatetime};
      if (amount != t.amount) updates['amount'] = amount;
      if (note != null) updates['note'] = note;
      if (categoryId != null) updates['category_id'] = categoryId;
      await txn.update('transactions', updates, where: 'id=?', whereArgs: [id]);
    });
  }

Future<List<Transaction>> getTransactions(String bookId, {int? limit, int? offset, String? startDate, String? accountId}) async {
   String where = 'book_id=?';
   List args = [bookId];
   if (startDate != null) {
     where += ' AND datetime >= ?';
     args.add(startDate);
   }
    if (accountId != null) {
      where += ' AND (account_id=? OR to_account_id=?)';
      args.addAll([accountId, accountId]);
    }
   final list = await (await db).query('transactions',
      where: where, whereArgs: args,
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
    final todayStr = _dayFmt.format(DateTime.now());
   for (final bill in bills) {
      // 去重：检查今天是否已生成过此账单
      final dup = await (await db).query('transactions',
        where: "book_id=? AND account_id=? AND amount=? AND note=? AND datetime LIKE ?",
        whereArgs: [bill.bookId, bill.accountId, bill.amount, bill.name, '$todayStr%']);
      if (dup.isNotEmpty) {
        final next = _calcNextRun(bill);
        final now = _fmt.format(DateTime.now());
        await (await db).update('periodic_bills',
          {'next_run_date': _dayFmt.format(next), 'updated_at': now},
          where: 'id=?', whereArgs: [bill.id]);
        continue;
      }
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

  /// 按月 + 类型 汇总各分类金额（用于统计图表）
  Future<List<Map<String, dynamic>>> getCategorySummary(
    String bookId, int year, int month, String type) async {
    final ym =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    return (await db).rawQuery(
      """SELECT c.id, c.name, COALESCE(SUM(t.amount), 0) AS total
         FROM transactions t
         LEFT JOIN categories c ON t.category_id = c.id
         WHERE t.book_id = ? AND t.type = ? AND t.is_investment = 0
           AND t.datetime LIKE ?
         GROUP BY t.category_id
         ORDER BY total DESC""",
      [bookId, type, '$ym%'],
    );
  }

  Future<void> updateAccount(Account a) async {
    await (await db).update('accounts', a.toMap(), where: 'id=?', whereArgs: [a.id]);
  }

  Future<List<Account>> getAllAccounts(String bookId) async {
    final list = await (await db).query('accounts',
      where: "book_id=? AND status!='deleted'",
      whereArgs: [bookId], orderBy: 'sort_order, name');
    return list.map((m) => Account.fromMap(m)).toList();
  }

  static List<DateTime> getBillingCycle(int billingDay, {DateTime? forDate}) {
    final date = forDate ?? DateTime.now();
    final year = date.year;
    final month = date.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final effectiveDay = billingDay > daysInMonth ? daysInMonth : billingDay;
    DateTime start, end;
    if (date.day <= effectiveDay) {
      final prevMonth = month == 1 ? 12 : month - 1;
      final prevYear = month == 1 ? year - 1 : year;
      final prevDays = DateTime(prevYear, prevMonth + 1, 0).day;
      final prevEffective = billingDay > prevDays ? prevDays : billingDay;
      start = DateTime(prevYear, prevMonth, prevEffective);
      end = DateTime(year, month, effectiveDay);
    } else {
      start = DateTime(year, month, effectiveDay);
      final nextMonth = month == 12 ? 1 : month + 1;
      final nextYear = month == 12 ? year + 1 : year;
      final nextDays = DateTime(nextYear, nextMonth + 1, 0).day;
      final nextEffective = billingDay > nextDays ? nextDays : billingDay;
      end = DateTime(nextYear, nextMonth, nextEffective);
    }
    return [start, end];
  }

  static DateTime _nextRepayDay(int repayDay, DateTime after) {
    final m = after.month;
    final y = after.year;
    final maxDays = DateTime(y, m + 1, 0).day;
    final effective = repayDay > maxDays ? maxDays : repayDay;
    final candidate = DateTime(y, m, effective);
    if (candidate.isAfter(after)) return candidate;
    final nextM = m == 12 ? 1 : m + 1;
    final nextY = m == 12 ? y + 1 : y;
    final nextMax = DateTime(nextY, nextM + 1, 0).day;
    final nextEff = repayDay > nextMax ? nextMax : repayDay;
    return DateTime(nextY, nextM, nextEff);
  }

  Future<List<Map<String, dynamic>>> getCreditCardSummary(String bookId) async {
    final d = await db;
    final cards = await d.query('accounts',
      where: "book_id=? AND type='credit' AND status='active'",
      whereArgs: [bookId]);
    final results = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (final card in cards) {
      final billingDay = card['billing_day'] as int? ?? 1;
      final repayDay = card['repayment_day'] as int?;
      final curCycle = getBillingCycle(billingDay, forDate: now);
      final curStart = _fmt.format(curCycle[0]);
      final curEnd = _fmt.format(curCycle[1]);
      final prevStartDt = DateTime(curCycle[0].year, curCycle[0].month - 1, curCycle[0].day);
      final prevEndDt = curCycle[0];
      final prevStart = _fmt.format(prevStartDt);
     final prevEnd = _fmt.format(prevEndDt);

      final curSpent = await d.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) AS total FROM transactions "
        "WHERE book_id=? AND account_id=? AND type='expense' "
        "AND is_investment=0 AND datetime >= ? AND datetime < ?",
        [bookId, card['id'], curStart, curEnd]);
      final currentSpent = (curSpent.first['total'] as num).toDouble();

      final due = await d.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) AS total FROM transactions "
        "WHERE book_id=? AND account_id=? AND type='expense' "
        "AND is_investment=0 AND datetime >= ? AND datetime < ?",
        [bookId, card['id'], prevStart, prevEnd]);
      final dueRepaid = await d.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) AS total FROM transactions "
        "WHERE book_id=? AND to_account_id=? AND type='transfer' "
        "AND datetime >= ? AND datetime < ?",
       [bookId, card['id'], prevEnd, curEnd]);
      final dueRepaidTotal = (dueRepaid.first['total'] as num).toDouble();
      double amountDue = ((due.first['total'] as num).toDouble() - dueRepaidTotal).clamp(0, double.infinity);

      int? daysUntilRepay;
      String? repayDateStr;
      if (repayDay != null) {
        final dueDate = _nextRepayDay(repayDay, prevEndDt);
        repayDateStr = _dayFmt.format(dueDate);
        daysUntilRepay = dueDate.difference(now).inDays;
      }
      results.add({
        'account_id': card['id'],
        'name': card['name'],
        'balance': (card['balance'] as num).toDouble(),
        'billing_day': billingDay,
        'repayment_day': repayDay,
        'cycle_start': curStart,
        'cycle_end': curEnd,
        'current_spent': currentSpent,
        'amount_due': amountDue,
        'repay_date': repayDateStr,
        'days_until_repay': daysUntilRepay,
      });
    }
    return results;
  }

 Future<void> recordChainTransfer({
   required String bookId,
   required List<Map<String, dynamic>> nodes,
    String? datetime,
 }) async {
   final d = await db;
   final now = _fmt.format(DateTime.now());
    final txnDatetime = datetime ?? now;
   await d.transaction((txn) async {
      for (final node in nodes) {
        final fromId = node['from_id'] as String;
        final toId = node['to_id'] as String;
        final amount = (node['amount'] as num).toDouble();
        await txn.insert('transactions', {
          'id': _uuid.v4(),
          'book_id': bookId,
          'account_id': fromId,
          'to_account_id': toId,
         'type': 'transfer',
         'amount': amount,
          'datetime': txnDatetime,
         'is_investment': 0,
          'updated_at': now,
         'created_at': now,
        });
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
          [amount, now, fromId]);
        final toRows = await txn.query('accounts',
          columns: ['type'], where: 'id=?', whereArgs: [toId]);
        final isCredit = toRows.isNotEmpty && toRows.first['type'] == 'credit';
        if (isCredit) {
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
            [amount, now, toId]);
        } else {
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
            [amount, now, toId]);
        }
      }
    });
  }

  /// 删除交易记录并回滚余额
  Future<void> deleteTransaction(String id) async {
    final d = await db;
    await d.transaction((txn) async {
      final rows = await txn.query('transactions', where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final t = Transaction.fromMap(rows.first);

      // 查来源账户类型
      final fromRows = await txn.query('accounts',
        columns: ['type'], where: 'id=?', whereArgs: [t.accountId]);
      final isFromCredit = fromRows.isNotEmpty && fromRows.first['type'] == 'credit';

      void reverseFrom() {
        if (isFromCredit) {
          txn.rawUpdate('UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
            [t.amount, t.createdAt, t.accountId]);
        } else {
          txn.rawUpdate('UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
            [t.amount, t.createdAt, t.accountId]);
        }
      }

     if (t.type == 'expense') {
       reverseFrom();
      } else if (t.type == 'invest' && t.relatedInvestmentId != null) {
        final isFromInvest = fromRows.isNotEmpty && (fromRows.first['type'] == 'fund' || fromRows.first['type'] == 'stock');
        final hRows = await txn.query('investment_holdings',
          where: 'id=?', whereArgs: [t.relatedInvestmentId]);
        if (isFromInvest) {
          // 卖出方向：持仓被减少，需要加回
          if (hRows.isNotEmpty) {
            final h = hRows.first;
            final oldShares = (h['total_shares'] as num).toDouble();
            final oldCost = (h['total_cost'] as num).toDouble();
            if (oldCost <= 0.001) {
              final estNav = (h['latest_nav'] as num?)?.toDouble() ?? 1.0;
              final estimatedShares = estNav > 0 ? t.amount / estNav : 0;
              await txn.update('investment_holdings', {
                'total_shares': estimatedShares, 'total_cost': t.amount,
                'is_liquidated': 0, 'updated_at': t.createdAt,
              }, where: 'id=?', whereArgs: [t.relatedInvestmentId]);
            } else {
              final sharesToAdd = oldShares * (t.amount / oldCost);
              await txn.update('investment_holdings', {
                'total_shares': oldShares + sharesToAdd,
                'total_cost': oldCost + t.amount,
                'updated_at': t.createdAt,
              }, where: 'id=?', whereArgs: [t.relatedInvestmentId]);
            }
          }
          // 计算卖出总金额 = 成本 + 关联盈亏
          final plRows = await txn.query('transactions',
            where: "batch_id=? AND type IN ('income','expense')",
            whereArgs: [t.batchId]);
          double profitAmount = 0;
          for (final pl in plRows) {
            final plAmt = (pl['amount'] as num).toDouble();
            if (pl['type'] == 'income') profitAmount += plAmt;
            else profitAmount -= plAmt;
          }
          final totalAmount = (t.amount + profitAmount).clamp(0, double.infinity);
          // 回滚余额：投资账户 +totalAmount，日常账户 -totalAmount
          if (t.toAccountId != null) {
            await txn.rawUpdate(
              'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
              [totalAmount, t.createdAt, t.toAccountId!]);
          }
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
            [totalAmount, t.createdAt, t.accountId]);
          // 删除关联盈亏记录
          for (final pl in plRows) {
            await txn.delete('transactions', where: 'id=?', whereArgs: [pl['id']]);
          }
        } else {
          // 买入方向：持仓被增加，需要减回
          if (hRows.isNotEmpty) {
            final h = hRows.first;
           final oldShares = (h['total_shares'] as num).toDouble();
           final oldCost = (h['total_cost'] as num).toDouble();
            // 优先从 note 解析份额（精确值），失败时按金额比例估算
            double sharesToRemove;
            final noteParts = t.note?.split(' ');
            if (noteParts != null && noteParts.length >= 5 && noteParts[0] == '买入') {
              sharesToRemove = double.tryParse(noteParts[3].replaceFirst('份额', '')) ?? oldShares * (oldCost > 0 ? (t.amount / oldCost).clamp(0, 1) : 0);
            } else {
              sharesToRemove = oldShares * (oldCost > 0 ? (t.amount / oldCost).clamp(0, 1) : 0);
            }
           double newShares = (oldShares - sharesToRemove).clamp(0, double.infinity);
            double newCost = (oldCost - t.amount).clamp(0, double.infinity);
            if (newShares <= 0.001) {
              await txn.update('investment_holdings',
                {'total_shares': 0, 'total_cost': 0, 'is_liquidated': 1, 'updated_at': t.createdAt},
                where: 'id=?', whereArgs: [t.relatedInvestmentId]);
            } else {
              await txn.update('investment_holdings',
                {'total_shares': newShares, 'total_cost': newCost, 'updated_at': t.createdAt},
                where: 'id=?', whereArgs: [t.relatedInvestmentId]);
            }
          }
          // 回滚余额：来源账户 +amount（日常加回），目标账户 -amount（投资扣回）
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
            [t.amount, t.createdAt, t.accountId]);
          if (t.toAccountId != null) {
            await txn.rawUpdate(
              'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
             [t.amount, t.createdAt, t.toAccountId!]);
         }
          // 重算投资账户市值（覆盖简单减法带来的手续费误差）
          if (t.toAccountId != null) {
            final allH = await txn.query('investment_holdings',
              where: "account_id=? AND is_liquidated=0",
              whereArgs: [t.toAccountId]);
            double tv = 0;
            for (final h2 in allH) {
              final s = (h2['total_shares'] as num).toDouble();
              final n = (h2['latest_nav'] as num?)?.toDouble();
              if (n != null) tv += s * n;
            }
            await txn.rawUpdate(
              'UPDATE accounts SET balance = ?, updated_at = ? WHERE id = ?',
              [tv, t.createdAt, t.toAccountId!]);
          }
       }
     } else if (t.type == 'income') {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
          [t.amount, t.createdAt, t.accountId]);
      } else if (t.type == 'transfer') {
        // 回滚 from
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [t.amount, t.createdAt, t.accountId]);
        // 回滚 to
        if (t.toAccountId != null) {
          final toRows = await txn.query('accounts',
            columns: ['type'], where: 'id=?', whereArgs: [t.toAccountId]);
          final isToCredit = toRows.isNotEmpty && toRows.first['type'] == 'credit';
          if (isToCredit) {
            await txn.rawUpdate(
              'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
              [t.amount, t.createdAt, t.toAccountId!]);
          } else {
            await txn.rawUpdate(
              'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
              [t.amount, t.createdAt, t.toAccountId!]);
          }
        }
      }
      await txn.delete('transactions', where: 'id=?', whereArgs: [id]);
    });
  }

  /// 基金/股票买入：扣款 + 到投资账户 + 持仓记录（一个事务）
  Future<void> recordInvestment({
    required String bookId,
    required String accountId,
    required String fromAccountId,
    required String code,
    String? name,
    required String invType,
    required double amount,
    required double nav,
   String feeType = 'A',
    double? extraFee,
    double? extraShares,
   String? note,
    String? datetime,
  }) async {
    final fee = extraFee ?? (feeType == 'A' ? amount * 0.0015 : 0.0);
    final netAmount = amount - fee;
    final shares = extraShares ?? (nav > 0 ? netAmount / nav : 0);
    final now = _fmt.format(DateTime.now());
    final txnDatetime = datetime ?? now;
    final d = await db;
    await d.transaction((txn) async {
      final txnId = _uuid.v4();
      final detailNote = '买入 ' + (note ?? code) + ' 净值$nav 份额${shares.toStringAsFixed(2)} 手续费${fee.toStringAsFixed(2)}';
      await txn.insert('transactions', {
        'id': txnId, 'book_id': bookId,
        'account_id': fromAccountId, 'to_account_id': accountId,
        'type': 'invest', 'amount': amount,
        'datetime': txnDatetime, 'note': detailNote,
       'is_investment': 1, 'updated_at': now, 'created_at': now,
      });
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
        [amount, now, fromAccountId]);
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [amount, now, accountId]);
      final existing = await txn.query('investment_holdings',
        where: "book_id=? AND account_id=? AND code=? AND is_liquidated=0",
        whereArgs: [bookId, accountId, code]);
      String? holdingId;
      if (existing.isNotEmpty) {
        final old = existing.first;
        holdingId = old['id'] as String;
        final oldShares = (old['total_shares'] as num).toDouble();
        final oldCost = (old['total_cost'] as num).toDouble();
        await txn.update('investment_holdings', {
          'total_shares': oldShares + shares,
          'total_cost': oldCost + amount,
          'latest_nav': nav, 'nav_date': now, 'updated_at': now,
        }, where: 'id=?', whereArgs: [holdingId]);
      } else {
        holdingId = _uuid.v4();
        await txn.insert('investment_holdings', {
          'id': holdingId, 'book_id': bookId,
          'account_id': accountId, 'code': code, 'name': name,
          'inv_type': invType, 'total_cost': amount,
          'total_shares': shares, 'latest_nav': nav,
          'nav_date': now, 'fee_type': feeType,
          'is_liquidated': 0, 'created_at': now, 'updated_at': now,
        });
      }
      // 关联交易与持仓
      await txn.rawUpdate(
        'UPDATE transactions SET related_investment_id = ? WHERE id = ?',
        [holdingId, txnId]);
      // 按市值重算投资账户余额
      final allH = await txn.query('investment_holdings',
        where: "account_id=? AND is_liquidated=0",
        whereArgs: [accountId]);
      double tv = 0;
      for (final h in allH) {
        final s = (h['total_shares'] as num).toDouble();
        final n = (h['latest_nav'] as num?)?.toDouble();
        if (n != null) tv += s * n;
      }
      await txn.rawUpdate(
        'UPDATE accounts SET balance = ?, updated_at = ? WHERE id = ?',
        [tv, now, accountId]);
    });
  }

  /// 获取持仓列表
  Future<List<Map<String, dynamic>>> getInvestments(String bookId) async {
    return (await db).query('investment_holdings',
      where: 'book_id=?', whereArgs: [bookId], orderBy: 'created_at DESC');
  }

  /// 获取单个持仓
  Future<Map<String, dynamic>?> getInvestment(String id) async {
    final list = await (await db).query('investment_holdings',
      where: 'id=?', whereArgs: [id]);
    return list.isNotEmpty ? list.first : null;
  }

  /// 更新净值
 Future<void> updateNav(String id, double nav, String navDate) async {
   final now = _fmt.format(DateTime.now());
    final d = await db;
    await d.transaction((txn) async {
      await txn.update('investment_holdings',
        {'latest_nav': nav, 'nav_date': navDate, 'updated_at': now},
        where: 'id=?', whereArgs: [id]);
      // 查找此持仓所在的投资账户
      final hRows = await txn.query('investment_holdings',
        columns: ['account_id'], where: 'id=?', whereArgs: [id]);
      if (hRows.isEmpty) return;
      final accountId = hRows.first['account_id'] as String;
      // 查询该账户下所有持仓，按最新净值重算市值
      final all = await txn.query('investment_holdings',
        where: "account_id=? AND is_liquidated=0",
        whereArgs: [accountId]);
      double totalValue = 0;
      for (final h in all) {
        final shares = (h['total_shares'] as num).toDouble();
        final n = (h['latest_nav'] as num?)?.toDouble();
        if (n != null) totalValue += shares * n;
      }
      await txn.rawUpdate(
        'UPDATE accounts SET balance = ?, updated_at = ? WHERE id = ?',
        [totalValue, now, accountId]);
    });
  }

  /// 卖出部分份额：资金回到指定账户
  Future<void> sellInvestment({
    required String id,
    required String toAccountId,
    required double shares,
    required double nav,
    String? datetime,
  }) async {
    final d = await db;
    final rows = await d.query('investment_holdings',
      where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final h = rows.first;
    final totalShares = (h['total_shares'] as num).toDouble();
    final totalCost = (h['total_cost'] as num).toDouble();
    if (shares > totalShares) throw Exception('卖出份额超过持仓');
    final sellAmount = shares * nav;
    final now = _fmt.format(DateTime.now());
    final txnDatetime = datetime ?? now;
    final bookId = h['book_id'] as String;
    final accountId = h['account_id'] as String;
    final costSold = totalCost * (shares / totalShares);
    final profit = sellAmount - costSold;
    final remainingShares = totalShares - shares;
    final remainingCost = totalCost - costSold;

    await d.transaction((txn) async {
      final batchId = _uuid.v4();
      // 1. 记录本金赎回
      await txn.insert('transactions', {
        'id': _uuid.v4(), 'book_id': bookId,
        'account_id': accountId, 'to_account_id': toAccountId,
        'type': 'invest', 'amount': costSold,
        'datetime': txnDatetime, 'note': '赎回本金 ' + (h['code'] as String),
        'is_investment': 1, 'related_investment_id': id, 'batch_id': batchId, 'updated_at': now, 'created_at': now,
      });
      // 2. 记录投资收益/亏损
      if (profit.abs() > 0.01) {
        final plType = profit >= 0 ? 'income' : 'expense';
        final plNote = profit >= 0 ? '投资收益' : '投资亏损';
        // 查找投资收益分类
        final cats = await txn.query('categories',
          where: "book_id=? AND name=? AND type='income'",
          whereArgs: [bookId, '投资收益']);
        final catId = cats.isNotEmpty ? cats.first['id'] as String : null;
        await txn.insert('transactions', {
          'id': _uuid.v4(), 'book_id': bookId,
          'account_id': toAccountId, 'category_id': catId,
          'type': plType, 'amount': profit.abs(),
          'datetime': txnDatetime,
          'note': '$plNote ' + (h['code'] as String),
          'is_investment': 1, 'related_investment_id': id, 'batch_id': batchId, 'updated_at': now, 'created_at': now,
        });
      }
      // 3. 投资账户市值减少
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
        [sellAmount, now, accountId]);
      // 4. 资金回到日常账户
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [sellAmount, now, toAccountId]);
      // 5. 更新持仓
      if (remainingShares <= 0.001) {
        await txn.update('investment_holdings',
          {'total_shares': 0, 'total_cost': 0, 'is_liquidated': 1, 'updated_at': now},
          where: 'id=?', whereArgs: [id]);
      } else {
        await txn.update('investment_holdings',
          {'total_shares': remainingShares, 'total_cost': remainingCost,
           'latest_nav': nav, 'nav_date': now, 'updated_at': now},
          where: 'id=?', whereArgs: [id]);
      }
    });
  }


  /// 基金转换：卖出A + 买入B + 手续费 + 退回
  Future<void> switchFund({
    required String bookId,
    required String fromAccountId,
    required String fromHoldingId,
    required double fromShares,
    required double fromNav,
    required String toCode,
    String? toName,
    required double toShares,
    required double toNav,
    required double fee,
    required double refund,
    required String? refundAccountId,
    String? datetime,
  }) async {
    final d = await db;
    final now = _fmt.format(DateTime.now());
    final txnD = datetime ?? now;
    final rows = await d.query('investment_holdings',
      where: 'id=?', whereArgs: [fromHoldingId]);
    if (rows.isEmpty) return;
    final h = rows.first;
    final totalShares = (h['total_shares'] as num).toDouble();
    final totalCost = (h['total_cost'] as num).toDouble();
    if (fromShares > totalShares) return;
    final costSold = totalCost * (fromShares / totalShares);
    final remainingShares = totalShares - fromShares;
    final remainingCost = totalCost - costSold;
    final fromAmount = fromShares * fromNav;

    await d.transaction((txn) async {
      final batchId = _uuid.v4();
      // 卖出A
      await txn.insert('transactions', {
        'id': _uuid.v4(), 'book_id': bookId,
        'account_id': fromAccountId,
        'type': 'invest', 'amount': fromAmount,
        'datetime': txnD, 'note': '转换转出 ' + (h['code'] as String),
        'is_investment': 1, 'related_investment_id': fromHoldingId, 'batch_id': batchId, 'updated_at': now, 'created_at': now,
      });
      if (remainingShares <= 0.001) {
        await txn.update('investment_holdings',
          {'total_shares': 0, 'total_cost': 0, 'is_liquidated': 1, 'updated_at': now},
          where: 'id=?', whereArgs: [fromHoldingId]);
      } else {
        await txn.update('investment_holdings',
          {'total_shares': remainingShares, 'total_cost': remainingCost, 'updated_at': now},
          where: 'id=?', whereArgs: [fromHoldingId]);
      }
      // 买入B
      final existing = await txn.query('investment_holdings',
        where: "book_id=? AND account_id=? AND code=? AND is_liquidated=0",
        whereArgs: [bookId, fromAccountId, toCode]);
      if (existing.isNotEmpty) {
        final o = existing.first;
        final oldShares = (o['total_shares'] as num).toDouble();
        final oldCost = (o['total_cost'] as num).toDouble();
        await txn.update('investment_holdings',
          {'total_shares': oldShares + toShares, 'total_cost': oldCost + fromAmount,
           'latest_nav': toNav, 'nav_date': txnD, 'updated_at': now},
          where: 'id=?', whereArgs: [o['id']]);
      } else {
        await txn.insert('investment_holdings', {
          'id': _uuid.v4(), 'book_id': bookId, 'account_id': fromAccountId,
          'code': toCode, 'name': toName, 'inv_type': 'fund',
          'total_cost': fromAmount, 'total_shares': toShares,
          'latest_nav': toNav, 'nav_date': txnD, 'fee_type': 'custom',
          'is_liquidated': 0, 'created_at': now, 'updated_at': now,
        });
      }
      // 手续费
      if (fee > 0) {
        await txn.insert('transactions', {
          'id': _uuid.v4(), 'book_id': bookId,
          'account_id': fromAccountId,
          'type': 'expense', 'amount': fee,
          'datetime': txnD, 'note': '转换手续费',
          'is_investment': 1, 'related_investment_id': fromHoldingId, 'batch_id': batchId, 'updated_at': now, 'created_at': now,
        });
      }
      // 退回
      if (refund > 0 && refundAccountId != null) {
        await txn.insert('transactions', {
          'id': _uuid.v4(), 'book_id': bookId,
          'account_id': refundAccountId,
          'type': 'income', 'amount': refund,
          'datetime': txnD, 'note': '转换退回',
          'is_investment': 1, 'related_investment_id': fromHoldingId, 'batch_id': batchId, 'updated_at': now, 'created_at': now,
        });
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [refund, now, refundAccountId]);
      }
      // 更新投资账户余额
      final allH = await txn.query('investment_holdings',
        where: "account_id=? AND is_liquidated=0",
        whereArgs: [fromAccountId]);
      double tv = 0;
      for (final h2 in allH) {
        final s = (h2['total_shares'] as num).toDouble();
        final n = (h2['latest_nav'] as num?)?.toDouble();
        if (n != null) tv += s * n;
      }
      await txn.rawUpdate(
        'UPDATE accounts SET balance = ?, updated_at = ? WHERE id = ?',
        [tv, now, fromAccountId]);
    });
  }

}
