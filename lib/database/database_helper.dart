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
    return openDatabase(path, version: 2, onCreate: _createTables, onUpgrade: _upgradeDb);
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
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [amount, now, accountId]);
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
    String? note,
  }) async {
    final fee = feeType == 'A' ? amount * 0.0015 : 0.0;
    final netAmount = amount - fee;
    final shares = nav > 0 ? netAmount / nav : 0;
    final now = _fmt.format(DateTime.now());
    final d = await db;
    await d.transaction((txn) async {
      await txn.insert('transactions', {
        'id': _uuid.v4(), 'book_id': bookId,
        'account_id': fromAccountId, 'to_account_id': accountId,
        'type': 'invest', 'amount': amount,
        'datetime': now, 'note': note ?? code,
        'is_investment': 1, 'created_at': now,
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
      if (existing.isNotEmpty) {
        final old = existing.first;
        final oldShares = (old['total_shares'] as num).toDouble();
        final oldCost = (old['total_cost'] as num).toDouble();
        await txn.update('investment_holdings', {
          'total_shares': oldShares + shares,
          'total_cost': oldCost + amount,
          'latest_nav': nav, 'nav_date': now, 'updated_at': now,
        }, where: 'id=?', whereArgs: [old['id']]);
      } else {
        await txn.insert('investment_holdings', {
          'id': _uuid.v4(), 'book_id': bookId,
          'account_id': accountId, 'code': code, 'name': name,
          'inv_type': invType, 'total_cost': amount,
          'total_shares': shares, 'latest_nav': nav,
          'nav_date': now, 'fee_type': feeType,
          'is_liquidated': 0, 'created_at': now, 'updated_at': now,
        });
      }
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
    await (await db).update('investment_holdings',
      {'latest_nav': nav, 'nav_date': navDate, 'updated_at': now},
      where: 'id=?', whereArgs: [id]);
  }

  /// 卖出部分份额：资金回到指定账户
  Future<void> sellInvestment({
    required String id,
    required String toAccountId,
    required double shares,
    required double nav,
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
    final bookId = h['book_id'] as String;
    final accountId = h['account_id'] as String;
    final costSold = totalCost * (shares / totalShares);
    final remainingShares = totalShares - shares;
    final remainingCost = totalCost - costSold;

    await d.transaction((txn) async {
      await txn.insert('transactions', {
        'id': _uuid.v4(), 'book_id': bookId,
        'account_id': accountId, 'to_account_id': toAccountId,
        'type': 'invest', 'amount': sellAmount,
        'datetime': now, 'note': '卖出 ${h['code']}',
        'is_investment': 1, 'created_at': now,
      });
      // 投资账户市值减少
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
        [sellAmount, now, accountId]);
      // 资金回到日常账户
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [sellAmount, now, toAccountId]);
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

}