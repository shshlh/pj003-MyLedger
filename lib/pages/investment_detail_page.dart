import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../database/database_helper.dart";
import "../models/account.dart";
import "../models/transaction.dart";

class InvestmentDetailPage extends StatefulWidget {
  final Map<String, dynamic> holding;
  final Map<String, Account> accountMap;
  const InvestmentDetailPage({super.key, required this.holding, required this.accountMap});
  @override
  State<InvestmentDetailPage> createState() => _InvestmentDetailPageState();
}

class _InvestmentDetailPageState extends State<InvestmentDetailPage> {
  List<Transaction> _transactions = [];
  bool _loading = true;
  double _totalInvested = 0;
  double _totalReturned = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

 Future<void> _load() async {
    try {
    final db = DatabaseHelper();
    final txns = await db.getHoldingTransactions(widget.holding["id"]);
    double invested = 0, returned = 0;
    for (final t in txns) {
      final p = t.note?.split(" ") ?? [];
     if (p.isNotEmpty && p[0] == "买入") invested += t.amount;
      if (p.isNotEmpty && p[0] == "转换转入") invested += t.amount;
     if (p.isNotEmpty && p[0] == "赎回本金") returned += t.amount;
    }
   if (!mounted) return;
   setState(() {
     _transactions = txns;
     _totalInvested = invested;
     _totalReturned = returned;
     _loading = false;
   });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
 }

  @override
  Widget build(BuildContext context) {
    final h = widget.holding;
    final shares = (h["total_shares"] as num).toDouble();
    final cost = (h["total_cost"] as num).toDouble();
    final num? nav = h['latest_nav'] is num ? h['latest_nav'] as num : null;
    final double? navDbl = nav?.toDouble();
    final marketValue = navDbl != null ? shares * navDbl : cost;
    final profit = marketValue - cost;
    final profitRate = cost > 0 ? (profit / cost * 100) : 0.0;
    final isLiquidated = (h["is_liquidated"] as int? ?? 0) == 1;
    final account = widget.accountMap[h["account_id"]];
    final avgCost = shares > 0 ? cost / shares : 0.0;
    final totalPL = marketValue + _totalReturned - _totalInvested;
    final invName = h["name"] as String? ?? h["code"];

    return Scaffold(
      appBar: AppBar(title: Text(invName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCard(invName, (h["code"] as String?) ?? "", account?.name ?? "?", shares, cost, marketValue, profit, profitRate, avgCost, nav, isLiquidated),
                const SizedBox(height: 16),
                _plSection(_totalInvested, _totalReturned, marketValue, totalPL),
                const SizedBox(height: 20),
                Text("交易历史", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                const SizedBox(height: 8),
                if (_transactions.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("暂无交易记录", style: TextStyle(color: Colors.grey[600]))))
                else
                  ..._transactions.map((t) => _txnCard(t)),
              ],
            ),
    );
  }

  Widget _summaryCard(String name, String code, String acctName, double shares, double cost, double mv, double profit, double pRate, double avgCost, num? nav, bool isLiquidated) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text("$code · $acctName", style: TextStyle(color: Colors.grey[600], fontSize: 13))),
              if (isLiquidated) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.withAlpha(30), borderRadius: BorderRadius.circular(4)), child: const Text("已清仓", style: TextStyle(fontSize: 11, color: Colors.grey))),
            ]),
            const SizedBox(height: 12),
            _row3("成本", "¥${NumberFormat("#,##0.00").format(cost)}", "市值", "¥${NumberFormat("#,##0.00").format(mv)}"),
            const SizedBox(height: 8),
            _row3("份额", NumberFormat("#,##0.00").format(shares), "均价", "¥${NumberFormat("#,##0.0000").format(avgCost)}"),
            const SizedBox(height: 8),
            if (nav != null) _row3("最新净值", nav.toDouble().toStringAsFixed(4), "净值日期", (widget.holding["nav_date"] as String?) ?? "-"),
            if (nav != null) const SizedBox(height: 8),
            Row(children: [
              Text("盈亏: ", style: TextStyle(color: Colors.grey[700])),
              Text("${profit >= 0 ? "+" : ""}¥${NumberFormat("#,##0.00").format(profit)} (${pRate >= 0 ? "+" : ""}${pRate.toStringAsFixed(2)}%)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: profit >= 0 ? Colors.green : Colors.red)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _plSection(double invested, double returned, double currentValue, double totalPL) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("盈亏明细", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
            const SizedBox(height: 12),
            _row2("累计投入", "¥${NumberFormat("#,##0.00").format(invested)}"),
            _row2("累计回款", "¥${NumberFormat("#,##0.00").format(returned)}"),
            _row2("当前市值", "¥${NumberFormat("#,##0.00").format(currentValue)}"),
            const Divider(height: 16),
            _row2("总盈亏", "¥${NumberFormat("#,##0.00").format(totalPL)}", valueColor: totalPL >= 0 ? Colors.green : Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _row2(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor ?? Colors.black87)),
      ]),
    );
  }

  Widget _row3(String l1, String v1, String l2, String v2) {
    return Row(children: [
      Expanded(child: Text("$l1: $v1", style: TextStyle(fontSize: 14, color: Colors.grey[700]))),
      Expanded(child: Text("$l2: $v2", style: TextStyle(fontSize: 14, color: Colors.grey[700]))),
    ]);
  }

  Widget _txnCard(Transaction t) {
    final parts = t.note?.split(" ") ?? [];
    final typeLabel = parts.isNotEmpty ? (parts[0] == "买入" ? "买入" : parts[0] == "赎回本金" ? "赎回" : parts[0] == "转换转出" ? "转出" : parts[0] == "投资收益" ? "收益" : parts[0] == "投资亏损" ? "亏损" : t.type) : t.type;
    final Color iconColor = typeLabel == "买入" ? Colors.blue : typeLabel == "收益" ? Colors.green : typeLabel == "亏损" ? Colors.red : Colors.orange;
    final IconData icon = typeLabel == "买入" ? Icons.shopping_cart : typeLabel == "赎回" || typeLabel == "转出" ? Icons.sell : Icons.trending_up;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: iconColor.withValues(alpha: 0.1), child: Icon(icon, color: iconColor, size: 20)),
        title: Text(t.note ?? t.type, style: const TextStyle(fontSize: 14)),
        subtitle: Text(_formatDate(t.datetime), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: Text("¥${NumberFormat("#,##0.00").format(t.amount)}", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return "${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")} ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}";
    } catch (_) {
      return iso;
    }
  }
}
