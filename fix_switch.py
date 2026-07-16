import re

path = r"D:\codexproject\pj_003_账本app\my_account_book\lib\pages\investment_page.dart"
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _openSwitch method after _openNavUpdate
old_nav = """  void _openNavUpdate(Map<String, dynamic> holding) {"""
new_nav = """  void _openSwitch() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => _SwitchForm(bookId: widget.book.id, onSaved: refresh),
    );
  }

  void _openNavUpdate(Map<String, dynamic> holding) {"""
content = content.replace(old_nav, new_nav)

# 2. Update empty state to add fund switch button
old_empty = """                  FilledButton.tonal(onPressed: _openBuy, child: const Text("\u4e70\u5165\u7b2c\u4e00\u7b14")),"""
new_empty = """                  FilledButton.tonal(onPressed: _openBuy, child: const Text("\u4e70\u5165\u7b2c\u4e00\u7b14")),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _openSwitch, child: const Text("\u57fa\u91d1\u8f6c\u6362")),"""
content = content.replace(old_empty, new_empty)

# 3. Append _SwitchForm widget
switch_widget = """

/// \u57fa\u91d1\u8f6c\u6362\u8868\u5355
class _SwitchForm extends StatefulWidget {
  final String bookId;
  final VoidCallback onSaved;
  const _SwitchForm({required this.bookId, required this.onSaved});
  @override
  State<_SwitchForm> createState() => _SwitchFormState();
}

class _SwitchFormState extends State<_SwitchForm> {
  final _fromCodeCtrl = TextEditingController();
  final _fromSharesCtrl = TextEditingController();
  final _fromNavCtrl = TextEditingController();
  final _toCodeCtrl = TextEditingController();
  final _toNameCtrl = TextEditingController();
  final _toSharesCtrl = TextEditingController();
  final _toNavCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _refundCtrl = TextEditingController();
  final _fmt = DateFormat('yyyy-MM-dd HH:mm');
  DateTime _dateTime = DateTime.now();
  List<Account> _accounts = [];
  String? _refundAccountId;
  String? _investAccountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fromCodeCtrl.dispose(); _fromSharesCtrl.dispose(); _fromNavCtrl.dispose();
    _toCodeCtrl.dispose(); _toNameCtrl.dispose(); _toSharesCtrl.dispose(); _toNavCtrl.dispose();
    _feeCtrl.dispose(); _refundCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accs = await DatabaseHelper().getAccounts(widget.bookId);
    setState(() {
      _accounts = accs.where((a) => a.status == "active").toList();
      final funds = _accounts.where((a) => a.type == "fund").toList();
      _investAccountId = funds.isNotEmpty ? funds.first.id : null;
      final dailies = _accounts.where((a) => a.type != "fund" && a.type != "credit").toList();
      _refundAccountId = dailies.isNotEmpty ? dailies.first.id : null;
    });
  }

  Future<void> _save() async {
    final fromShares = double.tryParse(_fromSharesCtrl.text);
    final fromNav = double.tryParse(_fromNavCtrl.text);
    final toShares = double.tryParse(_toSharesCtrl.text);
    final toNav = double.tryParse(_toNavCtrl.text);
    final fee = double.tryParse(_feeCtrl.text) ?? 0;
    final refund = double.tryParse(_refundCtrl.text) ?? 0;
    if (_fromCodeCtrl.text.isEmpty || fromShares == null || fromNav == null || fromNav <= 0) return;
    if (_toCodeCtrl.text.isEmpty || toShares == null || toShares <= 0 || toNav == null || toNav <= 0) return;
    if (_investAccountId == null) return;
    setState(() => _saving = true);

    // \u67e5\u627e\u662f\u5426\u5df2\u6709\u6301\u4ed3A
    final holdings = await DatabaseHelper().getInvestments(widget.bookId);
    final fromHolding = holdings.where((h) =>
        h['code'] == _fromCodeCtrl.text.trim() &&
        h['account_id'] == _investAccountId &&
        h['is_liquidated'] == 0
    ).toList();
    if (fromHolding.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('\u672a\u627e\u5230\u8f6c\u51fa\u57fa\u91d1\u6301\u4ed3')));
      setState(() => _saving = false);
      return;
    }

    await DatabaseHelper().switchFund(
      bookId: widget.bookId,
      fromAccountId: _investAccountId!,
      fromHoldingId: fromHolding.first['id'],
      fromShares: fromShares,
      fromNav: fromNav,
      toCode: _toCodeCtrl.text.trim(),
      toName: _toNameCtrl.text.isNotEmpty ? _toNameCtrl.text.trim() : null,
      toShares: toShares,
      toNav: toNav,
      fee: fee,
      refund: refund,
      refundAccountId: _refundAccountId,
      datetime: _fmt.format(_dateTime),
    );

    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dailies = _accounts.where((a) => a.type != "fund" && a.type != "credit").toList();
    final funds = _accounts.where((a) => a.type == "fund").toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("\u57fa\u91d1\u8f6c\u6362", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Divider(),
          const Text("\u8f6c\u51fa\u57fa\u91d1 A", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _fromCodeCtrl, decoration: const InputDecoration(labelText: "\u57fa\u91d1\u4ee3\u7801", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _fromSharesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "\u786e\u8ba4\u8f6c\u51fa\u4efd\u989d", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _fromNavCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "\u786e\u8ba4\u8f6c\u51fa\u51c0\u503c", border: OutlineInputBorder(), isDense: true))),
          ]),
          const Divider(),
          const Text("\u8f6c\u5165\u57fa\u91d1 B", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _toCodeCtrl, decoration: const InputDecoration(labelText: "\u57fa\u91d1\u4ee3\u7801", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _toNameCtrl, decoration: const InputDecoration(labelText: "\u57fa\u91d1\u540d\u79f0", border: OutlineInputBorder(), isDense: true))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _toSharesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "\u786e\u8ba4\u8f6c\u5165\u4efd\u989d", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _toNavCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "\u786e\u8ba4\u8f6c\u5165\u51c0\u503c", border: OutlineInputBorder(), isDense: true))),
          ]),
          const Divider(),
          const Text("\u8d39\u7528\u4e0e\u9000\u56de", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _feeCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "\u624b\u7eed\u8d39", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _refundCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "\u9000\u56de\u91d1\u989d", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _refundAccountId,
                decoration: const InputDecoration(labelText: "\u9000\u56de\u8d26\u6237", border: OutlineInputBorder(), isDense: true),
                items: dailies.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) { if (v != null) setState(() => _refundAccountId = v); },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _dateTime, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
              if (d == null) return;
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_dateTime));
              if (t == null) return;
              setState(() => _dateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '\u65e5\u671f\u65f6\u95f4', border: OutlineInputBorder(), suffixIcon: Icon(Icons.access_time)),
              child: Text(_fmt.format(_dateTime), style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? "\u5904\u7406\u4e2d..." : "\u786e\u8ba4\u8f6c\u6362", style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
"""

content += switch_widget

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')
