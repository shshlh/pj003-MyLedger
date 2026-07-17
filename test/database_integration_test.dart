
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../lib/database/database_helper.dart';

Future<Database> _createTestDb() async {
  final db = await databaseFactoryFfi.openDatabase(Uuid().v4(), options: OpenDatabaseOptions(onCreate: (db, v) async {
    await db.execute("CREATE TABLE books(id TEXT PRIMARY KEY,name TEXT NOT NULL,cover TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)");
    await db.execute("CREATE TABLE accounts(id TEXT PRIMARY KEY,book_id TEXT NOT NULL,name TEXT NOT NULL,type TEXT NOT NULL,balance REAL NOT NULL DEFAULT 0,currency TEXT NOT NULL DEFAULT 'CNY',status TEXT NOT NULL DEFAULT 'active',billing_day INTEGER,repayment_day INTEGER,sort_order INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,FOREIGN KEY(book_id) REFERENCES books(id))");
    await db.execute("CREATE TABLE categories(id TEXT PRIMARY KEY,book_id TEXT NOT NULL,name TEXT NOT NULL,type TEXT NOT NULL,parent_id TEXT,icon TEXT,sort_order INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL,FOREIGN KEY(book_id) REFERENCES books(id))");
    await db.execute("CREATE TABLE transactions(id TEXT PRIMARY KEY,book_id TEXT NOT NULL,account_id TEXT NOT NULL,to_account_id TEXT,category_id TEXT,type TEXT NOT NULL,amount REAL NOT NULL,datetime TEXT NOT NULL,note TEXT,is_investment INTEGER NOT NULL DEFAULT 0,related_investment_id TEXT,batch_id TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,FOREIGN KEY(book_id) REFERENCES books(id),FOREIGN KEY(account_id) REFERENCES accounts(id),FOREIGN KEY(category_id) REFERENCES categories(id))");
    await db.execute("CREATE TABLE periodic_bills(id TEXT PRIMARY KEY,book_id TEXT NOT NULL,name TEXT NOT NULL,type TEXT NOT NULL,amount REAL NOT NULL,account_id TEXT NOT NULL,category_id TEXT,frequency TEXT NOT NULL,interval_days INTEGER,start_date TEXT NOT NULL,end_date TEXT,next_run_date TEXT NOT NULL,enabled INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,updated_at TEXT,FOREIGN KEY(book_id) REFERENCES books(id),FOREIGN KEY(account_id) REFERENCES accounts(id))");
    await db.execute("CREATE TABLE investment_holdings(id TEXT PRIMARY KEY,book_id TEXT NOT NULL,account_id TEXT NOT NULL,code TEXT NOT NULL,name TEXT,inv_type TEXT NOT NULL,total_cost REAL DEFAULT 0,total_shares REAL DEFAULT 0,latest_nav REAL,nav_date TEXT,fee_type TEXT DEFAULT 'A',is_liquidated INTEGER DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,FOREIGN KEY(book_id) REFERENCES books(id),FOREIGN KEY(account_id) REFERENCES accounts(id))");
  }, version: 1));
  return db;
}

class _Fx {
  final Database db; final String bookId, debitId, creditId, investId, cashId, catFoodId, catSalaryId;
  _Fx(this.db, this.bookId, this.debitId, this.creditId, this.investId, this.cashId, this.catFoodId, this.catSalaryId);
}

Future<_Fx> _setup() async {
  final db = await _createTestDb();
  DatabaseHelper.useTestDatabase(db);
  final uuid = Uuid(); final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  final b = 'bk1'; final d = uuid.v4(); final cr = uuid.v4(); final iv = uuid.v4(); final ca = uuid.v4(); final cf = uuid.v4(); final cs = uuid.v4();
  await db.insert('books', {'id':b,'name':'T','created_at':now,'updated_at':now});
  await db.insert('categories', {'id':cf,'book_id':b,'name':'餐饮','type':'expense','sort_order':0,'created_at':now});
  await db.insert('categories', {'id':cs,'book_id':b,'name':'工资','type':'income','sort_order':0,'created_at':now});
  await db.insert('accounts', {'id':d,'book_id':b,'name':'储蓄卡','type':'debit','balance':10000,'created_at':now,'updated_at':now});
  await db.insert('accounts', {'id':cr,'book_id':b,'name':'信用卡','type':'credit','balance':0,'billing_day':5,'repayment_day':25,'created_at':now,'updated_at':now});
  await db.insert('accounts', {'id':iv,'book_id':b,'name':'投资账户','type':'fund','balance':0,'created_at':now,'updated_at':now});
  await db.insert('accounts', {'id':ca,'book_id':b,'name':'现金','type':'cash','balance':5000,'created_at':now,'updated_at':now});
  for (final a in [d, cr, iv, ca]) { await db.update('accounts', {'balance': a==d?10000.0:a==ca?5000.0:0.0}, where:'id=?', whereArgs:[a]); }
  return _Fx(db, b, d, cr, iv, ca, cf, cs);
}

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });
  tearDown(() { DatabaseHelper.useTestDatabase(null); });

  group('日常记账', () {
    test('支出后余额减少', () async {
      final fx = await _setup();
      await DatabaseHelper().recordTransaction(bookId:fx.bookId, accountId:fx.debitId, categoryId:fx.catFoodId, type:'expense', amount:120);
      expect((await fx.db.query('accounts', columns:['balance'], where:'id=?', whereArgs:[fx.debitId])).first['balance'], closeTo(9880, 0.01));
      await fx.db.close();
    });
    test('收入后余额增加', () async {
      final fx = await _setup();
      await DatabaseHelper().recordTransaction(bookId:fx.bookId, accountId:fx.debitId, categoryId:fx.catSalaryId, type:'income', amount:10000);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], closeTo(20000, 0.01));
      await fx.db.close();
    });
    test('转账后双方余额正确', () async {
      final fx = await _setup();
      await DatabaseHelper().recordTransaction(bookId:fx.bookId, accountId:fx.debitId, toAccountId:fx.cashId, type:'transfer', amount:2000);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], closeTo(8000, 0.01));
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.cashId])).first['balance'], closeTo(7000, 0.01));
      await fx.db.close();
    });
  });

  group('信用卡', () {
    test('消费时余额增加（债务增加）', () async {
      final fx = await _setup();
      await DatabaseHelper().recordTransaction(bookId:fx.bookId, accountId:fx.creditId, categoryId:fx.catFoodId, type:'expense', amount:300);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.creditId])).first['balance'], closeTo(300, 0.01));
      await fx.db.close();
    });
    test('还款时信用卡余额减少（债务减少）', () async {
      final fx = await _setup();
      await DatabaseHelper().recordTransaction(bookId:fx.bookId, accountId:fx.creditId, categoryId:fx.catFoodId, type:'expense', amount:2000);
      await DatabaseHelper().recordTransaction(bookId:fx.bookId, accountId:fx.debitId, toAccountId:fx.creditId, type:'transfer', amount:2000);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.creditId])).first['balance'], closeTo(0, 0.01));
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], closeTo(8000, 0.01));
      await fx.db.close();
    });
  });

  group('投资', () {
    test('买入后持仓和余额正确', () async {
      final fx = await _setup();
      await DatabaseHelper().recordInvestment(bookId:fx.bookId, accountId:fx.investId, fromAccountId:fx.debitId, code:'000001', invType:'fund', amount:5000, nav:1.2, feeType:'A');
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], closeTo(5000, 1));
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.investId])).first['balance'], closeTo(4992.5, 1));
      expect((await fx.db.query('investment_holdings')).length, 1);
      await fx.db.close();
    });
    test('卖出后持仓减少', () async {
      final fx = await _setup();
      await DatabaseHelper().recordInvestment(bookId:fx.bookId, accountId:fx.investId, fromAccountId:fx.debitId, code:'000001', invType:'fund', amount:5000, nav:1.0, feeType:'C');
      final h = await DatabaseHelper().getInvestments(fx.bookId);
      await DatabaseHelper().sellInvestment(id:h.first['id'], toAccountId:fx.debitId, shares:1000, nav:1.1);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], closeTo(6100, 0.5));
      expect((await fx.db.query('investment_holdings')).first['total_shares'], closeTo(4000, 1));
      await fx.db.close();
    });
    test('卖出超过持仓报错', () async {
      final fx = await _setup();
      await DatabaseHelper().recordInvestment(bookId:fx.bookId, accountId:fx.investId, fromAccountId:fx.debitId, code:'000001', invType:'fund', amount:1000, nav:1.0, feeType:'C');
      final h = await DatabaseHelper().getInvestments(fx.bookId);
      expect(() async => DatabaseHelper().sellInvestment(id:h.first['id'], toAccountId:fx.debitId, shares:99999, nav:1.0), throwsA(isA<Exception>()));
      await fx.db.close();
    });
    test('删除买入记录后余额回滚', () async {
      final fx = await _setup();
      await DatabaseHelper().recordInvestment(bookId:fx.bookId, accountId:fx.investId, fromAccountId:fx.debitId, code:'000001', invType:'fund', amount:3000, nav:1.0, feeType:'C');
      final txns = await DatabaseHelper().getTransactions(fx.bookId);
      await DatabaseHelper().deleteTransaction(txns.first.id);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], closeTo(10000, 0.5));
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.investId])).first['balance'], closeTo(0, 0.5));
      expect((await fx.db.query('investment_holdings')).first['is_liquidated'], 1);
      await fx.db.close();
    });
  });

  group('删除回滚', () {
    test('删除支出记录后余额回滚', () async {
      final fx = await _setup();
      final before = (await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'];
      await DatabaseHelper().recordTransaction(bookId:fx.bookId, accountId:fx.debitId, categoryId:fx.catFoodId, type:'expense', amount:200);
      await DatabaseHelper().deleteTransaction((await DatabaseHelper().getTransactions(fx.bookId)).first.id);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], before);
      await fx.db.close();
    });
    test('删除转账记录后余额回滚', () async {
      final fx = await _setup();
      await DatabaseHelper().recordTransaction(bookId:fx.bookId, accountId:fx.debitId, toAccountId:fx.cashId, type:'transfer', amount:1500);
      await DatabaseHelper().deleteTransaction((await DatabaseHelper().getTransactions(fx.bookId)).first.id);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], 10000);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.cashId])).first['balance'], 5000);
      await fx.db.close();
    });
    test('删除不存在记录不报错', () async {
      final fx = await _setup();
      await DatabaseHelper().deleteTransaction('no_such_id');
      await fx.db.close();
    });
  });

  group('周期账单去重', () {
    test('重复调用不生成重复交易', () async {
      final fx = await _setup();
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await fx.db.insert('periodic_bills', {'id':Uuid().v4(),'book_id':fx.bookId,'name':'房租','type':'expense','amount':3000,'account_id':fx.debitId,'frequency':'monthly','start_date':'2026-01-01','next_run_date':today,'enabled':1,'created_at':now});
      await DatabaseHelper().runDueBills();
      final n2 = await DatabaseHelper().runDueBills();
      expect(n2, 0);
      expect((await fx.db.rawQuery('SELECT COUNT(*) as c FROM transactions')).first['c'], 1);
      await fx.db.close();
    });
  });

  group('链式转账', () {
    test('多节点转账余额正确', () async {
      final fx = await _setup();
      await DatabaseHelper().recordChainTransfer(bookId:fx.bookId, nodes:[{'from_id':fx.debitId,'to_id':fx.cashId,'amount':500},{'from_id':fx.cashId,'to_id':fx.investId,'amount':300}]);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], closeTo(9500, 0.01));
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.cashId])).first['balance'], closeTo(5200, 0.01));
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.investId])).first['balance'], closeTo(300, 0.01));
      await fx.db.close();
    });
  });

  group('完整场景', () {
    test('一个月的生活记账', () async {
      final fx = await _setup();
      final h = DatabaseHelper();
      await h.recordTransaction(bookId:fx.bookId,accountId:fx.debitId,categoryId:fx.catFoodId,type:'expense',amount:150,note:'早餐',datetime:'2026-07-01 08:00');
      await h.recordTransaction(bookId:fx.bookId,accountId:fx.debitId,categoryId:fx.catSalaryId,type:'income',amount:15000,note:'工资',datetime:'2026-07-05 10:00');
      await h.recordTransaction(bookId:fx.bookId,accountId:fx.debitId,toAccountId:fx.cashId,type:'transfer',amount:3000,note:'取现',datetime:'2026-07-06 09:00');
      await h.recordTransaction(bookId:fx.bookId,accountId:fx.creditId,categoryId:fx.catFoodId,type:'expense',amount:200,note:'晚餐',datetime:'2026-07-07 18:00');
      await h.recordTransaction(bookId:fx.bookId,accountId:fx.debitId,categoryId:fx.catFoodId,type:'expense',amount:45,note:'咖啡',datetime:'2026-07-07 14:00');
      expect((await fx.db.rawQuery('SELECT COUNT(*) as c FROM transactions')).first['c'], 5);
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.debitId])).first['balance'], closeTo(21805, 0.01));
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.creditId])).first['balance'], closeTo(200, 0.01));
      expect((await fx.db.query('accounts',columns:['balance'],where:'id=?',whereArgs:[fx.cashId])).first['balance'], closeTo(8000, 0.01));
      await fx.db.close();
    });
  });
}
