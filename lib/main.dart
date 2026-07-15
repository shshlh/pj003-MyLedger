import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'models/book.dart';
import 'models/account.dart';
import 'pages/home_page.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const InitPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 启动页：初始化数据库，创建默认账本和账户
class InitPage extends StatefulWidget {
  const InitPage({super.key});
  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  Book? _book;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final db = DatabaseHelper();
      var book = await db.getBook('default');
      if (book == null) {
        book = await db.initDefaultBook();
        final now = DateTime.now().toIso8601String();
        const uuid = Uuid();
        await db.saveAccount(Account(
          id: uuid.v4(),
          bookId: book.id,
          name: '现金',
          type: 'cash',
          createdAt: now,
          updatedAt: now,
        ));
        await db.saveAccount(Account(
          id: uuid.v4(),
          bookId: book.id,
          name: '储蓄卡',
          type: 'debit',
          createdAt: now,
          updatedAt: now,
        ));
        await db.saveAccount(Account(
          id: uuid.v4(),
          bookId: book.id,
          name: '信用卡',
          type: 'credit',
          createdAt: now,
          updatedAt: now,
        ));
      }
      setState(() {
        _book = book;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: Center(child: Text('初始化失败: $_error')));
    }
    if (_book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return HomePage(book: _book!);
  }
}
