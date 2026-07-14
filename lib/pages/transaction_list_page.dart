import 'package:flutter/material.dart';
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
      case 'income':   return Icons.arrow_downward;
      case 'transfer': return Icons.swap_horiz;
      default:         return Icons.arrow_upward;
    }
  }

  Color _amountColor(String type) {
    switch (type) {
      case 'income':   return Colors.green;
      case 'transfer': return Colors.blue;
      default:         return Colors.red;
    }
  }

  String _amountPrefix(String type) {
    switch (type) {
      case 'income': return '+';
      case 'transfer': return '↔';
      default: return '-';
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
            Text('暂无交易记录', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
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
          final toAccount = t.toAccountId != null ? _accountMap[t.toAccountId] : null;
          final category = _categoryMap[t.categoryId];

          final title = t.type == 'transfer'
              ? '${account?.name ?? "?"} → ${toAccount?.name ?? "?"}'
              : category?.name ?? '未分类';
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
                child: Icon(_typeIcon(t.type), color: _amountColor(t.type), size: 20),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(
                '${_formatDate(t.datetime)} · $subtitle',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              trailing: Text(
                '${_amountPrefix(t.type)}¥${t.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _amountColor(t.type),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
