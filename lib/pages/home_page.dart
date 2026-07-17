import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/book.dart';
import 'record_page.dart';
import 'transaction_list_page.dart';
import 'statistics_page.dart';
import 'accounts_page.dart';
import 'investment_page.dart';

/// 首页：顶部月度概览 + 信用卡总览 + 底部导航切换四个 tab
class HomePage extends StatefulWidget {
  final Book book;
  const HomePage({super.key, required this.book});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _txnKey = GlobalKey<TransactionListPageState>();
  final _statsKey = GlobalKey<StatisticsPageState>();
  final _acctKey = GlobalKey<AccountsPageState>();
  final _investKey = GlobalKey<InvestmentPageState>();
  final _recordKey = GlobalKey<RecordPageState>();

  DateTime _overviewMonth = DateTime.now();
  Map<String, double> _monthlySummary = {'expense': 0, 'income': 0};
  List<Map<String, dynamic>> _creditCards = [];
 bool _overviewLoading = true;


 @override
  void initState() {
    super.initState();
    DatabaseHelper().runDueBills();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    final db = DatabaseHelper();
    final y = _overviewMonth.year;
    final m = _overviewMonth.month;
    final summary = await db.getMonthlySummary(widget.book.id, y, m);
    final cards = await db.getCreditCardSummary(widget.book.id);
    if (!mounted) return;
    setState(() {
      _monthlySummary = summary;
      _creditCards = cards;
      _overviewLoading = false;
    });
  }

  void _prevMonth() {
    setState(() {
      _overviewMonth = DateTime(_overviewMonth.year, _overviewMonth.month - 1);
      _overviewLoading = true;
    });
    _loadOverview();
  }

  void _nextMonth() {
    setState(() {
      _overviewMonth = DateTime(_overviewMonth.year, _overviewMonth.month + 1);
      _overviewLoading = true;
    });
    _loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      RecordPage(key: _recordKey, book: widget.book, embedded: true),
      TransactionListPage(key: _txnKey, book: widget.book),
      StatisticsPage(key: _statsKey, book: widget.book),
      AccountsPage(key: _acctKey, book: widget.book),
      InvestmentPage(key: _investKey, book: widget.book),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('记账App'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildOverview(),
          const Divider(height: 1),
          Expanded(child: IndexedStack(index: _currentIndex, children: pages)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabChanged,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: '记账'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '流水'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: '统计'),
         BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: '账户'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: '投资'),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    final fmt = DateFormat('yyyy年M月');
    final expense = _monthlySummary['expense'] ?? 0;
    final income = _monthlySummary['income'] ?? 0;
    final balance = income - expense;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: _prevMonth, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              Text(fmt.format(_overviewMonth),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _nextMonth, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          ),
          const SizedBox(height: 8),
          if (_overviewLoading)
            const SizedBox(height: 24,
                child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem('支出', expense, Colors.red),
                _statItem('收入', income, Colors.green),
                _statItem('结余', balance, balance >= 0 ? Colors.blue : Colors.red),
              ],
            ),
            if (_creditCards.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 4),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _creditCards.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _creditCardChip(_creditCards[i]),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statItem(String label, double amount, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text('¥${NumberFormat('#,##0.00').format(amount)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

 Widget _creditCardChip(Map<String, dynamic> card) {
    final due = (card['amount_due'] as num).toDouble();
    final current = (card['current_spent'] as num).toDouble();
   final days = card['days_until_repay'] as int?;
    final useColor = due > 0 ? Colors.orange : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: useColor.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: useColor.withAlpha(80)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         Text(card['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
         const SizedBox(height: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('应还 ¥${NumberFormat('#,##0.00').format(due)}',
                    style: TextStyle(fontSize: 12, color: useColor, fontWeight: FontWeight.w600)),
                if (days != null) ...[
                  const SizedBox(width: 8),
                  Text(days >= 0 ? '$days天后还' : '已过${-days}天',
                      style: TextStyle(fontSize: 11, color: days >= 0 ? Colors.grey : Colors.red)),
                ],
              ]),
              if (current > 0)
                Text('在途 ¥${NumberFormat('#,##0.00').format(current)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  void _onTabChanged(int i) {
    setState(() => _currentIndex = i);
    if (i == 1) _txnKey.currentState?.refresh();
    if (i == 2) _statsKey.currentState?.refresh();
    if (i == 3) _acctKey.currentState?.refresh();
    if (i == 4) _investKey.currentState?.refresh();
    if (i == 0) _loadOverview();
    if (i == 0) _recordKey.currentState?.refresh();
  }
}
