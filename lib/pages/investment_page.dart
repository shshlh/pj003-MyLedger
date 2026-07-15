import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:uuid/uuid.dart";
import "../database/database_helper.dart";
import "../models/book.dart";
import "../models/account.dart";

class InvestmentPage extends StatefulWidget {
  final Book book;
  const InvestmentPage({super.key, required this.book});
  @override
  State<InvestmentPage> createState() => InvestmentPageState();
}

class InvestmentPageState extends State<InvestmentPage> {
  List<Map<String, dynamic>> _holdings = [];
  Map<String, Account> _accountMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => _loading = true);
    final db = DatabaseHelper();
    final accs = await db.getAccounts(widget.book.id);
    _accountMap = {for (final a in accs) a.id: a};
    _holdings = await db.getInvestments(widget.book.id);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _openBuy() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => _BuyForm(bookId: widget.book.id, onSaved: refresh),
    );
  }

  void _openSell(Map<String, dynamic> holding) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => _SellForm(holding: holding, bookId: widget.book.id, onSaved: refresh),
    );
  }

  void _openNavUpdate(Map<String, dynamic> holding) {
    final codeCtrl = TextEditingController(text: (holding["latest_nav"] ?? "").toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("更新净值 - ${holding["code"]}"),
        content: TextField(
          controller: codeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "最新净值"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          FilledButton(onPressed: () async {
            final nav = double.tryParse(codeCtrl.text);
            if (nav == null || nav <= 0) return;
            final today = DateFormat("yyyy-MM-dd").format(DateTime.now());
            await DatabaseHelper().updateNav(holding["id"], nav, today);
            if (ctx.mounted) Navigator.pop(ctx);
            await refresh();
          }, child: const Text("保存")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openBuy, child: const Icon(Icons.add),
      ),
      body: _holdings.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text("暂无持仓", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 16),
                  FilledButton.tonal(onPressed: _openBuy, child: const Text("买入第一笔")),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _holdings.length,
                itemBuilder: (_, i) => _buildCard(_holdings[i]),
              ),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> h) {
    final invName = h["name"] as String? ?? h["code"];
    final shares = (h["total_shares"] as num).toDouble();
    final cost = (h["total_cost"] as num).toDouble();
    final nav = (h["latest_nav"] as num?)?.toDouble();
    final marketValue = nav != null ? shares * nav : cost;
    final profit = marketValue - cost;
    final profitRate = cost > 0 ? (profit / cost * 100) : 0.0;
    final isLiquidated = (h["is_liquidated"] as int? ?? 0) == 1;
    final account = _accountMap[h["account_id"]];
    final avgCost = shares > 0 ? cost / shares : 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text("${h["code"]} · ${account?.name ?? "?"}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              if (isLiquidated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text("已清仓", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == "sell") _openSell(h);
                  if (v == "nav") _openNavUpdate(h);
                },
                itemBuilder: (_) => [
                  if (!isLiquidated) ...[
                    const PopupMenuItem(value: "sell", child: Text("卖出")),
                    const PopupMenuItem(value: "nav", child: Text("更新净值")),
                  ],
                ],
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _infoItem("份额", NumberFormat("#,##0.00").format(shares)),
              _infoItem("均价", "¥${NumberFormat("#,##0.0000").format(avgCost)}"),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              _infoItem("成本", "¥${NumberFormat("#,##0.00").format(cost)}"),
              _infoItem("市值", "¥${NumberFormat("#,##0.00").format(marketValue)}"),
              if (nav != null)
                Text(
                  "${profit >= 0 ? "+" : ""}¥${NumberFormat("#,##0.00").format(profit)} (${profitRate >= 0 ? "+" : ""}${profitRate.toStringAsFixed(1)}%)",
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: profit >= 0 ? Colors.green : Colors.red,
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// 买入表单
class _BuyForm extends StatefulWidget {
  final String bookId;
  final VoidCallback onSaved;
  const _BuyForm({required this.bookId, required this.onSaved});
  @override
  State<_BuyForm> createState() => _BuyFormState();
}

class _BuyFormState extends State<_BuyForm> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _navCtrl = TextEditingController();
  List<Account> _accounts = [];
  List<Account> _investAccounts = [];
  String? _fromAccountId;
  String? _toAccountId;
  String _feeType = "A";
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _nameCtrl.dispose();
    _amountCtrl.dispose(); _navCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accs = await DatabaseHelper().getAccounts(widget.bookId);
    setState(() {
      _accounts = accs.where((a) => a.status == "active").toList();
      _investAccounts = _accounts.where((a) => a.type == "fund").toList();
      _fromAccountId = _accounts.where((a) => a.type != "fund" && a.type != "credit").isNotEmpty
          ? _accounts.firstWhere((a) => a.type != "fund" && a.type != "credit").id
          : null;
      _toAccountId = _investAccounts.isNotEmpty ? _investAccounts.first.id : null;
    });
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text);
    final nav = double.tryParse(_navCtrl.text);
    if (code.isEmpty || amount == null || amount <= 0 || nav == null || nav <= 0) return;
    if (_fromAccountId == null || _toAccountId == null) return;
    setState(() => _saving = true);
    final note = _nameCtrl.text.trim();
    await DatabaseHelper().recordInvestment(
      bookId: widget.bookId,
      accountId: _toAccountId!,
      fromAccountId: _fromAccountId!,
      code: code,
      name: note.isNotEmpty ? note : null,
      invType: "fund",
      amount: amount,
      nav: nav,
      feeType: _feeType,
    );
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("买入基金", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: "基金代码", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "基金名称（可选）", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "买入金额", border: OutlineInputBorder()))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _navCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "当日净值", border: OutlineInputBorder()))),
          ]),
          if (_feeType != "custom") const SizedBox(height: 12),
          if (_feeType != "custom")
            DropdownButtonFormField<String>(
              value: _feeType,
              decoration: const InputDecoration(labelText: "费率类型", border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: "A", child: Text("A类（申购费0.15%）")),
                DropdownMenuItem(value: "C", child: Text("C类（无申购费）")),
              ],
              onChanged: (v) { if (v != null) setState(() => _feeType = v); },
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _fromAccountId,
            decoration: const InputDecoration(labelText: "扣款账户", border: OutlineInputBorder()),
            items: _accounts.where((a) => a.type != "fund" && a.type != "credit")
                .map((a) => DropdownMenuItem(value: a.id, child: Text("${a.name} (¥${a.balance.toStringAsFixed(2)})")))
                .toList(),
            onChanged: (v) { if (v != null) setState(() => _fromAccountId = v); },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _toAccountId,
            decoration: const InputDecoration(labelText: "投资账户", border: OutlineInputBorder()),
            items: _investAccounts
                .map((a) => DropdownMenuItem(value: a.id, child: Text("${a.name} (¥${a.balance.toStringAsFixed(2)})")))
                .toList(),
            onChanged: (v) { if (v != null) setState(() => _toAccountId = v); },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? "买入中..." : "确认买入", style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

/// 卖出表单
class _SellForm extends StatefulWidget {
  final Map<String, dynamic> holding;
  final String bookId;
  final VoidCallback onSaved;
  const _SellForm({required this.holding, required this.bookId, required this.onSaved});
  @override
  State<_SellForm> createState() => _SellFormState();
}

class _SellFormState extends State<_SellForm> {
  final _sharesCtrl = TextEditingController();
  final _navCtrl = TextEditingController();
  List<Account> _dailyAccounts = [];
  String? _toAccountId;
  bool _saving = false;
  bool _liquidateAll = false;

  @override
  void initState() {
    super.initState();
    _load();
    _liquidateAll = false;
  }

  @override
  void dispose() {
    _sharesCtrl.dispose(); _navCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accs = await DatabaseHelper().getAccounts(widget.bookId);
    setState(() {
      _dailyAccounts = accs.where((a) => a.status == "active" && a.type != "fund" && a.type != "credit").toList();
      _toAccountId = _dailyAccounts.isNotEmpty ? _dailyAccounts.first.id : null;
    });
  }

  Future<void> _save() async {
    final totalShares = (widget.holding["total_shares"] as num).toDouble();
    final shares = _liquidateAll ? totalShares : (double.tryParse(_sharesCtrl.text) ?? 0);
    final nav = double.tryParse(_navCtrl.text);
    if (shares <= 0 || shares > totalShares || nav == null || nav <= 0) return;
    if (_toAccountId == null) return;
    setState(() => _saving = true);
    try {
      await DatabaseHelper().sellInvestment(
        id: widget.holding["id"],
        toAccountId: _toAccountId!,
        shares: shares,
        nav: nav,
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalShares = (widget.holding["total_shares"] as num).toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("卖出 - ${widget.holding["code"]}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("持仓 ${NumberFormat("#,##0.00").format(totalShares)} 份", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(children: [
            Checkbox(value: _liquidateAll, onChanged: (v) => setState(() => _liquidateAll = v ?? false)),
            const Text("全部清仓"),
          ]),
          if (!_liquidateAll) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _sharesCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "卖出份额", border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _navCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: "卖出净值", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _toAccountId,
            decoration: const InputDecoration(labelText: "到账账户", border: OutlineInputBorder()),
            items: _dailyAccounts
                .map((a) => DropdownMenuItem(value: a.id, child: Text("${a.name} (¥${a.balance.toStringAsFixed(2)})")))
                .toList(),
            onChanged: (v) { if (v != null) setState(() => _toAccountId = v); },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_saving ? "处理中..." : (_liquidateAll ? "确认清仓" : "确认卖出"), style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
