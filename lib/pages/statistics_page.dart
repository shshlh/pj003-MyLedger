import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import '../models/book.dart';

/// 月度统计页：收支概览 + 分类饼图
class StatisticsPage extends StatefulWidget {
  final Book book;
  const StatisticsPage({super.key, required this.book});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  double _totalExpense = 0;
  double _totalIncome = 0;
  List<_CatData> _expenseCats = [];
  List<_CatData> _incomeCats = [];
  bool _loading = true;

  static const _pieColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
    Colors.amber, Colors.cyan, Colors.deepOrange, Colors.lightGreen,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper();
    final summary = await db.getMonthlySummary(widget.book.id, _year, _month);
    final expCats = await db.getCategorySummary(widget.book.id, _year, _month, 'expense');
    final incCats = await db.getCategorySummary(widget.book.id, _year, _month, 'income');
    if (!mounted) return;
    setState(() {
      _totalExpense = summary['expense'] ?? 0;
      _totalIncome = summary['income'] ?? 0;
      _expenseCats = expCats
          .map((m) => _CatData(m['name'] as String, (m['total'] as num).toDouble()))
          .where((c) => c.amount > 0)
          .toList();
      _incomeCats = incCats
          .map((m) => _CatData(m['name'] as String, (m['total'] as num).toDouble()))
          .where((c) => c.amount > 0)
          .toList();
      _loading = false;
    });
  }

  void _prevMonth() {
    if (_month == 1) { _month = 12; _year--; } else { _month--; }
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_year == now.year && _month == now.month) return;
    if (_month == 12) { _month = 1; _year++; } else { _month++; }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth =
        _year == DateTime.now().year && _month == DateTime.now().month;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 月份选择器
                _buildMonthSelector(isCurrentMonth),
                const SizedBox(height: 16),
                // 收支概览卡片
                _buildSummaryCards(),
                const SizedBox(height: 20),
                // 支出分类饼图
                if (_expenseCats.isNotEmpty) ...[
                  _buildPieSection('支出分类', _expenseCats, _totalExpense),
                  const SizedBox(height: 20),
                ],
                // 收入分类饼图
                if (_incomeCats.isNotEmpty) ...[
                  _buildPieSection('收入分类', _incomeCats, _totalIncome),
                  const SizedBox(height: 20),
                ],
                // 无数据提示
                if (_expenseCats.isEmpty && _incomeCats.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        '本月暂无数据',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          );
  }

  Widget _buildMonthSelector(bool isCurrentMonth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
        Text(
          '${_year}年${_month}月',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: isCurrentMonth ? null : _nextMonth,
          icon: Icon(Icons.chevron_right,
              color: isCurrentMonth ? Colors.grey[300] : null),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final balance = _totalIncome - _totalExpense;
    return Row(
      children: [
        _summaryCard('支出', _totalExpense, Colors.red),
        const SizedBox(width: 8),
        _summaryCard('收入', _totalIncome, Colors.green),
        const SizedBox(width: 8),
        _summaryCard('结余', balance, balance >= 0 ? Colors.blue : Colors.red),
      ],
    );
  }

  Widget _summaryCard(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              '¥${amount.toStringAsFixed(0)}',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieSection(String title, List<_CatData> data, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: PieChart(
                PieChartData(
                  sections: _buildPieSections(data),
                  centerSpaceRadius: 36,
                  sectionsSpace: 2,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: data.asMap().entries.map((e) {
                  final i = e.key;
                  final d = e.value;
                  final pct = total > 0 ? (d.amount / total * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _pieColors[i % _pieColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            d.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '¥${d.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections(List<_CatData> data) {
    final total = data.fold<double>(0, (s, d) => s + d.amount);
    return data.asMap().entries.map((e) {
      final i = e.key;
      final pct = total > 0 ? (e.value.amount / total * 100) : 0.0;
      return PieChartSectionData(
        color: _pieColors[i % _pieColors.length],
        value: e.value.amount,
        title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        radius: 60,
      );
    }).toList();
  }
}

/// 分类金额数据
class _CatData {
  final String name;
  final double amount;
  const _CatData(this.name, this.amount);
}
