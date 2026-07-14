import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/account.dart';
import '../models/category.dart';

class RecordPage extends StatefulWidget {
  final Book book;
  final bool embedded; // 嵌入底部导航时隐藏 AppBar
  const RecordPage({super.key, required this.book, this.embedded = false});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _type = 'expense';
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;

  List<Account> _accounts = [];
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final db = DatabaseHelper();
    final accs = await db.getAccounts(widget.book.id);
    final cats = await db.getCategories(widget.book.id, type: _type);
    setState(() {
      _accounts = accs;
      _categories = cats;
      _accountId = _firstAccountId(null);
      _toAccountId = _firstToAccountId();
      if (cats.isNotEmpty) _categoryId = cats.first.id;
      _loading = false;
    });
  }

  /// 从账户列表：支出/收入显示所有 active 账户；转账排除信用卡
  List<Account> get _fromAccounts {
    return _accounts.where((a) {
      if (a.status != 'active') return false;
      if (_type == 'transfer' && a.type == 'credit') return false;
      return true;
    }).toList();
  }

  /// 到账户列表：排除与从账户相同的即可
  List<Account> get _toAccounts {
    return _accounts.where((a) {
      if (a.status != 'active') return false;
      if (a.id == _accountId) return false;
      return true;
    }).toList();
  }

  /// 返回第一个可用的从账户 ID，确保值在 _fromAccounts 中存在
  String? _firstAccountId(String? excludeId) {
    final from = _fromAccounts;
    // 优先选择非 excludeId 的
    for (final a in from) {
      if (a.id != excludeId) return a.id;
    }
    return from.isNotEmpty ? from.first.id : null;
  }

  /// 返回第一个可用的到账户 ID
  String? _firstToAccountId() {
    final to = _toAccounts;
    return to.isNotEmpty ? to.first.id : null;
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper().getCategories(widget.book.id, type: _type);
    setState(() {
      _categories = cats;
      if (cats.isNotEmpty) _categoryId = cats.first.id;
    });
  }

  void _switchType(String type) {
    setState(() {
      _type = type;
      // 切换类型时重新计算选中值，确保在过滤后的列表中存在
      _accountId = _firstAccountId(_toAccountId);
      _toAccountId = _firstToAccountId();
    });
    _loadCategories();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || _accountId == null) return;
    if (_type == 'transfer' && _toAccountId == null) return;

    await DatabaseHelper().recordTransaction(
      bookId: widget.book.id,
      accountId: _accountId!,
      toAccountId: _type == 'transfer' ? _toAccountId : null,
      categoryId: _type == 'transfer' ? null : _categoryId,
      type: _type,
      amount: amount,
      note: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null,
    );

    final freshAccounts = await DatabaseHelper().getAccounts(widget.book.id);
    setState(() {
      _accounts = freshAccounts;
      // 刷新后重新校验选中值
      _accountId = _firstAccountId(_toAccountId);
      _toAccountId = _firstToAccountId();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
    );
    _amountCtrl.clear();
    _noteCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(title: Text('${widget.book.name} — 记一笔')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text('${widget.book.name} — 记一笔')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // 类型切换
            Row(children: [
              for (final t in ['expense', 'income', 'transfer'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text({
                      'expense': '支出',
                      'income': '收入',
                      'transfer': '转账'
                    }[t]!),
                    selected: _type == t,
                    onSelected: (_) => _switchType(t),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            // 金额
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // 分类（转账不显示）
            if (_type != 'transfer')
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: '分类',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            if (_type != 'transfer') const SizedBox(height: 12),
            // 账户（支出/收入）/ 从账户（转账）
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: _type == 'transfer' ? '从账户' : '账户',
                border: const OutlineInputBorder(),
              ),
              items: _fromAccounts
                  .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} (¥${a.balance.toStringAsFixed(2)})')))
                  .toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            // 转账目标账户
            if (_type == 'transfer')
              DropdownButtonFormField<String>(
                initialValue: _toAccountId,
                decoration: const InputDecoration(
                  labelText: '到账户',
                  border: OutlineInputBorder(),
                ),
                items: _toAccounts
                    .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.name} (¥${a.balance.toStringAsFixed(2)})')))
                    .toList(),
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
            if (_type == 'transfer') const SizedBox(height: 12),
            // 备注
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _save,
                child: const Text('保存', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
