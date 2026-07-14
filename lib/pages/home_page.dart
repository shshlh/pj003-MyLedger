import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/book.dart';
import 'record_page.dart';
import 'transaction_list_page.dart';
import 'statistics_page.dart';

/// 首页：底部导航切换记账/流水/统计三个tab
class HomePage extends StatefulWidget {
  final Book book;
  const HomePage({super.key, required this.book});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _txnKey = GlobalKey<TransactionListPageState>();
  final _statsKey = GlobalKey<StatisticsPageState>();

  static const _titles = ['记账', '流水', '统计'];

  @override
  void initState() {
    super.initState();
    // 启动时自动执行到期周期账单
    DatabaseHelper().runDueBills();
  }

  @override
  Widget build(BuildContext context) {
    // 用 unique key 确保 IndexedStack 能区分子页面
    final pages = <Widget>[
      RecordPage(book: widget.book, embedded: true),
      TransactionListPage(key: _txnKey, book: widget.book),
      StatisticsPage(key: _statsKey, book: widget.book),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabChanged,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: '记账'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '流水'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: '统计'),
        ],
      ),
    );
  }

  void _onTabChanged(int i) {
    setState(() => _currentIndex = i);
    // 切到流水/统计 tab 时自动刷新数据
    if (i == 1) _txnKey.currentState?.refresh();
    if (i == 2) _statsKey.currentState?.refresh();
  }
}
