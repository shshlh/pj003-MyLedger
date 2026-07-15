import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/account.dart';

/// 账户管理页：按类型分组展示，支持新建、编辑、归档、恢复
class AccountsPage extends StatefulWidget {
  final Book book;
  const AccountsPage({super.key, required this.book});

  @override
  State<AccountsPage> createState() => AccountsPageState();
}

class AccountsPageState extends State<AccountsPage> {
  List<Account> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final accs = await DatabaseHelper().getAllAccounts(widget.book.id);
      if (!mounted) return;
      setState(() {
        _accounts = accs;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openEditor({Account? account}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountEditor(
        bookId: widget.book.id,
        account: account,
        onSaved: refresh,
      ),
    );
  }

  Future<void> _toggleArchive(Account account) async {
    if (account.status == 'active' && account.balance > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('账户余额不为零，不能归档。请先处理余额。')),
      );
      return;
    }

    final isArchiving = account.status == 'active';
    final action = isArchiving ? '归档' : '恢复';
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$action账户'),
        content: Text('确定要$action「${account.name}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action)),
        ],
      ),
    );
    if (ok != true) return;

    final updated = Account(
      id: account.id,
      bookId: account.bookId,
      name: account.name,
      type: account.type,
      balance: account.balance,
      status: isArchiving ? 'archived' : 'active',
      billingDay: account.billingDay,
      repaymentDay: account.repaymentDay,
      sortOrder: account.sortOrder,
      createdAt: account.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await DatabaseHelper().updateAccount(updated);
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('加载失败: $_error'));

    final active = _accounts.where((a) => a.status == 'active').toList();
    final archived = _accounts.where((a) => a.status == 'archived').toList();

    const typeLabels = {
      'cash': '现金',
      'debit': '储蓄卡',
      'credit': '信用卡',
      'fund': '投资账户',
      'stock': '投资账户',
      'virtual': '虚拟账户',
      'receivable': '应收',
      'payable': '应付',
    };

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTotalBalance(active),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('新建账户'),
            ),
          ),
          const SizedBox(height: 16),
          if (active.isNotEmpty) ...[
            for (final entry in _groupByType(active, typeLabels).entries)
              _buildGroup(entry.key, entry.value),
          ] else
            const Center(
                child: Text('暂无账户', style: TextStyle(color: Colors.grey))),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('已归档',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            for (final entry in _groupByType(archived, typeLabels).entries)
              _buildGroup(entry.key, entry.value),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalBalance(List<Account> active) {
    final net = active.fold(0.0, (sum, a) {
      if (a.type == 'credit') return sum - a.balance;
      return sum + a.balance;
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('净资产',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('¥${NumberFormat("#,##0.00").format(net)}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: net >= 0 ? Colors.green : Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(String typeLabel, List<Account> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
          child: Text(typeLabel,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey)),
        ),
        for (final a in accounts)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              title: Text(a.name),
              subtitle: Text(
                a.type == 'credit'
                    ? '待还 ¥${NumberFormat("#,##0.00").format(a.balance)}'
                    : '余额 ¥${NumberFormat("#,##0.00").format(a.balance)}',
              ),
              trailing: PopupMenuButton<String>(
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(a.status == 'active' ? '归档' : '恢复'),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'edit') _openEditor(account: a);
                  if (v == 'archive') _toggleArchive(a);
                },
              ),
            ),
          ),
      ],
    );
  }

  Map<String, List<Account>> _groupByType(
      List<Account> accounts, Map<String, String> labels) {
    final map = <String, List<Account>>{};
    for (final a in accounts) {
      final label = labels[a.type] ?? a.type;
      map.putIfAbsent(label, () => []).add(a);
    }
    return map;
  }
}

/// 账户编辑弹窗（新建/编辑）
class _AccountEditor extends StatefulWidget {
  final String bookId;
  final Account? account;
  final VoidCallback onSaved;
  const _AccountEditor(
      {required this.bookId, this.account, required this.onSaved});

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _billingCtrl = TextEditingController();
  final _repayCtrl = TextEditingController();
  late String _type;
  bool _saving = false;

  static const _types = {
    'cash': '现金',
    'debit': '储蓄卡',
    'credit': '信用卡',
    'fund': '投资账户',
    'virtual': '虚拟账户',
    'receivable': '应收',
    'payable': '应付',
  };

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _type = a?.type ?? 'debit';
    if (a != null) {
      _nameCtrl.text = a.name;
      _balanceCtrl.text = a.balance.toStringAsFixed(2);
      if (a.billingDay != null) _billingCtrl.text = a.billingDay.toString();
      if (a.repaymentDay != null) _repayCtrl.text = a.repaymentDay.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _billingCtrl.dispose();
    _repayCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final db = DatabaseHelper();
    final isNew = widget.account == null;
    final now = DateTime.now().toIso8601String();
    final balance = widget.account == null
        ? (double.tryParse(_balanceCtrl.text) ?? 0)
        : widget.account!.balance;

    final a = Account(
      id: isNew
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : widget.account!.id,
      bookId: widget.bookId,
      name: name,
      type: _type,
      balance: balance,
      status: 'active',
      billingDay: _type == 'credit' ? int.tryParse(_billingCtrl.text) : null,
      repaymentDay: _type == 'credit' ? int.tryParse(_repayCtrl.text) : null,
      sortOrder: widget.account?.sortOrder ?? 0,
      createdAt: isNew ? now : widget.account!.createdAt,
      updatedAt: now,
    );

    if (isNew) {
      await db.saveAccount(a);
    } else {
      await db.updateAccount(a);
    }

    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.account == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isNew ? '新建账户' : '编辑账户',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: '名称', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            key: ValueKey('acct_type_$_type'),
            decoration: const InputDecoration(
                labelText: '类型', border: OutlineInputBorder()),
            items: _types.entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
          if (isNew) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _balanceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: '初始余额', border: OutlineInputBorder()),
            ),
          ],
          if (_type == 'credit') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _billingCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '账单日', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _repayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '还款日', border: OutlineInputBorder()),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
    );
  }
}
