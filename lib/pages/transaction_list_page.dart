import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/category.dart';

/// 交易流水列表页
class TransactionListPage extends StatefulWidget {
  final Book book;
  const TransactionListPage({super.key, required this.book});

  @override
  State<TransactionListPage> createState() => TransactionListPageState();
}

class TransactionListPageState extends State<TransactionListPage> {
  List<Transaction> _transactions = [];
  Map<String, Account> _accountMap = {};
  Map<String, Category> _categoryMap = {};
  bool _loading = true;
  Map<int, Map<int, List<Transaction>>> _grouped = {};
  final Set<String> _expandedMonths = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// 从数据库重新加载数据（供外部调用）
  Future<void> refresh() async {
    setState(() => _loading = true);
    final db = DatabaseHelper();
    final txns = await db.getTransactions(widget.book.id);
    final accounts = await db.getAccounts(widget.book.id);
    final cats = await db.getCategories(widget.book.id);
    if (!mounted) return;
    final grouped = <int, Map<int, List<Transaction>>>{};
    for (final t in txns) {
      final dt = DateTime.parse(t.datetime);
      grouped.putIfAbsent(dt.year, () => {});
      grouped[dt.year]!.putIfAbsent(dt.month, () => []);
      grouped[dt.year]![dt.month]!.add(t);
    }
    setState(() {
      _transactions = txns;
      _grouped = grouped;
      _accountMap = {for (final a in accounts) a.id: a};
      _categoryMap = {for (final c in cats) c.id: c};
      _loading = false;
    });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward;
      case 'transfer':
       return Icons.swap_horiz;
      case 'invest':
        return Icons.trending_up;
     default:
        return Icons.arrow_upward;
    }
  }

 Color _amountColor(String type) {
   switch (type) {
     case 'income':   return Colors.red;
     case 'transfer': return Colors.blue;
     default:         return Colors.green;
   }
 }

  String _amountPrefix(String type) {
    switch (type) {
      case 'income':
        return '+';
      case 'transfer':
        return '↔';
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('暂无交易记录',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        children: _buildGroupedList(),
      ),
    );
  }

  List<Widget> _buildGroupedList() {
    final widgets = <Widget>[];
    final years = _grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final year in years) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
        child: Text('$year年', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ));
      final months = _grouped[year]!.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final month in months) {
        final key = '$year-$month';
        final isExpanded = _expandedMonths.contains(key);
        final txns = _grouped[year]![month]!;
        widgets.add(
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) { _expandedMonths.remove(key); }
              else { _expandedMonths.add(key); }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(children: [
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${month}月 (${txns.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
        if (isExpanded) {
          for (final t in txns) {
            widgets.add(_buildTransactionCard(t));
            widgets.add(const SizedBox(height: 4));
          }
        }
      }
    }
    return widgets;
  }

  Widget _buildTransactionCard(Transaction t) {
    final account = _accountMap[t.accountId];
    final toAccount = t.toAccountId != null ? _accountMap[t.toAccountId] : null;
    final category = _categoryMap[t.categoryId];

          String title;
          if (t.type == 'transfer') {
            title = '${account?.name ?? "?"} → ${toAccount?.name ?? "?"}';
         } else if (t.type == 'invest') {
            final p = t.note?.split(' ') ?? [];
            title = p.length >= 2 ? '\u4e70\u5165 ${p[1]}' : '\u8d4e\u56de\u672c\u91d1';
         } else if (t.isInvestment == 1 && (t.type == 'income' || t.type == 'expense')) {
            title = t.note ?? '投资收益';
          } else {
            title = category?.name ?? '未分类';
          }
         final subtitle = [
           account?.name,
            if (t.type == 'invest') _investDetail(t) ?? '' else if (t.note != null && t.note!.isNotEmpty) t.note,
         ].where((e) => e != null).join(' · ');

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _amountColor(t.type).withValues(alpha: 0.1),
                child: Icon(_typeIcon(t.type),
                    color: _amountColor(t.type), size: 20),
              ),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(
                '${_formatDate(t.datetime)} · $subtitle',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_amountPrefix(t.type)}¥${t.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: _amountColor(t.type),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: Colors.grey),
                    onSelected: (v) {
                      if (v == 'edit') _editTransaction(t);
                      if (v == 'remove') _deleteTransaction(t);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(
                          value: 'remove',
                          child:
                              Text('删除', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ),
          );
    }

    String? _investDetail(Transaction t) {
      if (t.type != 'invest' || t.note == null) return null;
      final parts = t.note!.split(' ');
      if (parts.length < 5) return null;
      return '${parts[2]} ${parts[3]} ${parts[4]}';
    }

  void _editTransaction(Transaction t) {
    final amountCtrl = TextEditingController(text: t.amount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: t.note ?? '');
    // 投资交易解析
    String _nav = '', _shares = '', _fee = '';
    if (t.type == 'invest' && t.note != null) {
      final p = t.note!.split(' ');
      if (p.length >= 3) _nav = p[2].replaceFirst('净值', '');
      if (p.length >= 4) _shares = p[3].replaceFirst('份额', '');
      if (p.length >= 5) _fee = p[4].replaceFirst('手续费', '');
    }
    final navCtrl = TextEditingController(text: _nav);
    final sharesCtrl = TextEditingController(text: _shares);
    final feeCtrl = TextEditingController(text: _fee);
    DateTime editDate = DateTime.parse(t.datetime);
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 24, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('编辑记录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: '金额', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              if (t.type == 'invest') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: navCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '净值', border: OutlineInputBorder(), isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: sharesCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '份额', border: OutlineInputBorder(), isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: feeCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '手续费', border: OutlineInputBorder(), isDense: true))),
                ]),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                    labelText: '备注', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                      context: ctx,
                      initialDate: editDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)));
                  if (date == null) return;
                  final time = await showTimePicker(
                      // ignore: use_build_context_synchronously
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(editDate));
                  if (time == null) return;
                  setSheetState(() {
                    editDate = DateTime(date.year, date.month, date.day,
                        time.hour, time.minute);
                  });
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: '日期时间',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time)),
                  child: Text(fmt.format(editDate)),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final newAmount = double.tryParse(amountCtrl.text);
                  if (newAmount == null || newAmount <= 0) return;
                  final db = DatabaseHelper();
                  await db.deleteTransaction(t.id);
                  if (t.type == 'invest') {
                    final p = t.note?.split(' ') ?? [];
                    final code = p.length >= 2 ? p[1] : '';
                    await db.recordInvestment(
                      bookId: t.bookId,
                      accountId: t.toAccountId ?? t.accountId,
                      fromAccountId: t.accountId,
                      code: code,
                      invType: 'fund',
                      amount: newAmount,
                      nav: double.tryParse(navCtrl.text) ?? 0,
                      extraFee: double.tryParse(feeCtrl.text),
                      extraShares: double.tryParse(sharesCtrl.text),
                      note: noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
                      datetime: fmt.format(editDate),
                    );
                  } else {
                    await db.recordTransaction(
                      bookId: t.bookId,
                      accountId: t.accountId,
                      toAccountId: t.toAccountId,
                      categoryId: t.categoryId,
                      type: t.type,
                      amount: newAmount,
                      note: noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
                      isInvestment: t.isInvestment,
                      relatedInvestmentId: t.relatedInvestmentId,
                      datetime: fmt.format(editDate),
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) refresh();
                },
                child: const Text('保存修改'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(Transaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除记录'),
        content: Text(
            '确定要删除吗？余额将自动回滚。\n\n${t.note ?? ""} ¥${t.amount.toStringAsFixed(2)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper().deleteTransaction(t.id);
      await refresh();
    }
  }
}
