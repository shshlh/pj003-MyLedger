import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/account.dart';
import '../models/category.dart';

/// 链式转账的单个节点
class _TransferNode {
  String fromAccountId;
  String toAccountId;
  double amount = 0;
  _TransferNode({required this.fromAccountId, required this.toAccountId});
}

class RecordPage extends StatefulWidget {
  final Book book;
  final bool embedded;
  const RecordPage({super.key, required this.book, this.embedded = false});

  @override
  State<RecordPage> createState() => RecordPageState();
}

class RecordPageState extends State<RecordPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _fmt = DateFormat('yyyy-MM-dd HH:mm');
  String _type = 'expense';
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  bool _isChainTransfer = false;
  final List<_TransferNode> _chainNodes = [];
  DateTime _dateTime = DateTime.now();

  List<Account> _accounts = [];
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
   super.initState();
    refresh();
 }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => _loading = true);
    final db = DatabaseHelper();
    final accs = await db.getAccounts(widget.book.id);
    final cats = await db.getCategories(widget.book.id, type: _type);
    setState(() {
      _accounts = accs;
      _categories = cats;
      _accountId = _firstAccountId(null);
      _toAccountId = _firstToAccountId(exclude: _accountId);
      if (cats.isNotEmpty) _categoryId = cats.first.id;
      _loading = false;
    });
  }

  /// 从账户列表：转账排除信用卡
  List<Account> get _fromAccounts {
    return _accounts.where((a) {
      if (a.status != 'active') return false;
      if (_type == 'transfer' && a.type == 'credit') return false;
      return true;
    }).toList();
  }

  /// 到账户列表：所有活跃账户
  List<Account> get _toAccounts {
    return _accounts.where((a) {
      if (a.status != 'active') return false;
      return true;
    }).toList();
  }

  String? _firstAccountId(String? excludeId) {
    final from = _fromAccounts;
    for (final a in from) {
      if (a.id != excludeId) return a.id;
    }
    return from.isNotEmpty ? from.first.id : null;
  }

  String? _firstToAccountId({String? exclude}) {
    final to = _toAccounts;
    if (exclude != null) {
      final filtered = to.where((a) => a.id != exclude).toList();
      if (filtered.isNotEmpty) return filtered.first.id;
    }
    return to.isNotEmpty ? to.first.id : null;
  }

  String _accountName(String id) {
    final a = _accounts.where((a) => a.id == id).firstOrNull;
    return a != null ? '${a.name} (¥${a.balance.toStringAsFixed(2)})' : id;
  }

  Future<void> _loadCategories() async {
    final cats =
        await DatabaseHelper().getCategories(widget.book.id, type: _type);
    setState(() {
      _categories = cats;
      if (cats.isNotEmpty) _categoryId = cats.first.id;
    });
  }

  void _switchType(String type) {
    setState(() {
      _type = type;
      _isChainTransfer = false;
      _accountId = _firstAccountId(null);
      _toAccountId = _firstToAccountId(exclude: _accountId);
    });
    _loadCategories();
  }

  /// 日期/时间选择器
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  /// ---- 链式转账 ----
  void _addChainNode() {
    final froms = _fromAccounts;
    final tos = _toAccounts;
    if (froms.isEmpty || tos.isEmpty) return;
    setState(() {
      final fromId = froms.first.id;
      final toId = tos.first.id != fromId
          ? tos.first.id
          : tos.length > 1
              ? tos[1].id
              : tos.first.id;
      _chainNodes.add(_TransferNode(
        fromAccountId: fromId,
        toAccountId: toId,
      ));
    });
  }

  void _removeChainNode(int index) {
    setState(() => _chainNodes.removeAt(index));
  }

  Future<void> _saveChain() async {
    if (_chainNodes.isEmpty) {
      _showError('请至少添加一个转账节点');
      return;
    }
    for (int i = 0; i < _chainNodes.length; i++) {
      final n = _chainNodes[i];
      if (n.amount <= 0) {
        _showError('第${i + 1}个节点金额必须大于零');
        return;
      }
      if (n.fromAccountId == n.toAccountId) {
        _showError('第${i + 1}个节点不能自己转自己');
        return;
      }
      final fromAcc = _accounts.firstWhere((a) => a.id == n.fromAccountId);
      if (fromAcc.balance < n.amount) {
        _showError(
            '「${fromAcc.name}」余额不足（余额 ¥${fromAcc.balance.toStringAsFixed(2)}，需转 ¥${n.amount.toStringAsFixed(2)}）');
        return;
      }
    }

   await DatabaseHelper().recordChainTransfer(
     bookId: widget.book.id,
     nodes: _chainNodes
         .map((n) => {
               'from_id': n.fromAccountId,
               'to_id': n.toAccountId,
               'amount': n.amount,
             })
         .toList(),
      datetime: _fmt.format(_dateTime),
   );

    final freshAccounts = await DatabaseHelper().getAccounts(widget.book.id);
    setState(() {
      _accounts = freshAccounts;
      _chainNodes.clear();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链式转账已保存'), duration: Duration(seconds: 1)),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  /// ---- 普通记账 ----
  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || _accountId == null) return;
    if ((_type == 'transfer') && _toAccountId == null) return;

    await DatabaseHelper().recordTransaction(
      bookId: widget.book.id,
      accountId: _accountId!,
      toAccountId: (_type == 'transfer') ? _toAccountId : null,
      categoryId: (_type == 'transfer') ? null : _categoryId,
      type: _type,
      amount: amount,
      note: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null,
      datetime: _fmt.format(_dateTime),
    );

    final freshAccounts = await DatabaseHelper().getAccounts(widget.book.id);
    setState(() {
      _accounts = freshAccounts;
      _accountId = _firstAccountId(_toAccountId);
      _toAccountId = _firstToAccountId();
      _dateTime = DateTime.now();
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in ['expense', 'income', 'transfer'])
                  ChoiceChip(
                    label: Text({
                      'expense': '支出',
                      'income': '收入',
                      'transfer': '转账'
                    }[t]!),
                    selected: _type == t,
                    onSelected: (_) => _switchType(t),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 链式转账子模式切换（仅 transfer 类型）
            if (_type == 'transfer') ...[
              Row(children: [
                const Text('转账模式：', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('单笔')),
                    ButtonSegment(value: true, label: Text('链式')),
                  ],
                  selected: {_isChainTransfer},
                  onSelectionChanged: (v) =>
                      setState(() => _isChainTransfer = v.first),
                ),
              ]),
              const SizedBox(height: 12),
            ],

            if (!_isChainTransfer) ...[
              // ---- 普通记账表单 ----
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: '金额', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              if (_type != 'transfer')
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                      labelText: '分类', border: OutlineInputBorder()),
                  items: _categories
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              if (_type != 'transfer') const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: InputDecoration(
                  labelText: _type == 'transfer' ? '从账户' : '账户',
                  border: const OutlineInputBorder(),
                ),
                items: _fromAccounts
                    .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                            '${a.name} (¥${a.balance.toStringAsFixed(2)})')))
                    .toList(),
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              if (_type == 'transfer')
                DropdownButtonFormField<String>(
                  initialValue: _toAccountId,
                  decoration: const InputDecoration(
                    labelText: '到账户',
                    border: OutlineInputBorder(),
                  ),
                  items: _toAccounts
                      .where((a) => a.id != _accountId)
                      .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                              '${a.name} (¥${a.balance.toStringAsFixed(2)})')))
                      .toList(),
                  onChanged: (v) => setState(() => _toAccountId = v),
                ),
              if (_type == 'transfer') const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                    labelText: '备注（可选）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              // 日期/时间选择
              InkWell(
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '日期时间',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(_fmt.format(_dateTime),
                      style: const TextStyle(fontSize: 15)),
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
            ] else ...[
              // ---- 链式转账表单 ----
              for (int i = 0; i < _chainNodes.length; i++)
                _buildChainNodeCard(i),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addChainNode,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加转账节点'),
              ),
             const SizedBox(height: 16),
              // 日期选择
              InkWell(
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '日期时间',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(_fmt.format(_dateTime), style: const TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 16),
             SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _saveChain,
                  child: const Text('保存全部转账', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChainNodeCard(int index) {
    final node = _chainNodes[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('转账 #${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  onPressed: () => _removeChainNode(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: node.fromAccountId,
              decoration: const InputDecoration(
                  labelText: '从账户',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: _fromAccounts
                  .map((a) => DropdownMenuItem(
                      value: a.id, child: Text(_accountName(a.id))))
                  .toList(),
              onChanged: (v) => setState(() {
                if (v != null) node.fromAccountId = v;
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: node.toAccountId,
              decoration: const InputDecoration(
                  labelText: '到账户',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: _toAccounts
                      .toList()
                      .where((a) => a.id != node.fromAccountId)
                      .isEmpty
                  ? _toAccounts
                      .map((a) => DropdownMenuItem(
                          value: a.id, child: Text(_accountName(a.id))))
                      .toList()
                  : _toAccounts
                      .where((a) => a.id != node.fromAccountId)
                      .map((a) => DropdownMenuItem(
                          value: a.id, child: Text(_accountName(a.id))))
                      .toList(),
              onChanged: (v) => setState(() {
                if (v != null) node.toAccountId = v;
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                hintText: '输入金额',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => node.amount = double.tryParse(v) ?? 0,
            ),
          ],
        ),
      ),
    );
  }
}
