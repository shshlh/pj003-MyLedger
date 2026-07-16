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
    setState(() {
      _transactions = txns;
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
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, i) {
          final t = _transactions[i];
          final account = _accountMap[t.accountId];
          final toAccount =
              t.toAccountId != null ? _accountMap[t.toAccountId] : null;
          final category = _categoryMap[t.categoryId];

          String title;
          if (t.type == 'transfer') {
            title = '${account?.name ?? "?"} → ${toAccount?.name ?? "?"}';
          } else if (t.type == 'invest') {
            title = t.note ?? '赎回本金';
          } else if (t.isInvestment == 1 && (t.type == 'income' || t.type == 'expense')) {
            title = t.note ?? '投资收益';
          } else {
            title = category?.name ?? '未分类';
          }
          final subtitle = [
            account?.name,
            if (t.note != null && t.note!.isNotEmpty) t.note,
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
        },
      ),
    );
  }

  void _editTransaction(Transaction t) {
    final amountCtrl = TextEditingController(text: t.amount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: t.note ?? '');
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
