import re

path = r"D:\codexproject\pj_003_账本app\my_account_book\lib\database\database_helper.dart"
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update recordInvestment params
content = content.replace(
    "    double feeRate = 'A',\n    String? note,\n    String? datetime,",
    "    double feeRate = 'A',\n    double? extraFee,\n    double? extraShares,\n    String? note,\n    String? datetime,"
)

# 2. Update recordInvestment calculation: use manual values if provided
old_calc = "    final fee = feeType == 'A' ? amount * 0.0015 : 0.0;\n    final netAmount = amount - fee;\n    final shares = nav > 0 ? netAmount / nav : 0;"
new_calc = "    final fee = extraFee ?? (feeType == 'A' ? amount * 0.0015 : 0.0);\n    final netAmount = amount - fee;\n    final shares = extraShares ?? (nav > 0 ? netAmount / nav : 0);"
content = content.replace(old_calc, new_calc)

# 3. Add switchFund method before the closing of class
switch_method = """

  /// 基金转换：卖出A + 买入B + 手续费 + 退回
  Future<void> switchFund({
    required String bookId,
    required String fromAccountId,
    required String fromHoldingId,
    required double fromShares,
    required double fromNav,
    required String toCode,
    String? toName,
    required double toShares,
    required double toNav,
    required double fee,
    required double refund,
    required String? refundAccountId,
    String? datetime,
  }) async {
    final d = await db;
    final now = _fmt.format(DateTime.now());
    final txnD = datetime ?? now;
    final rows = await d.query('investment_holdings',
      where: 'id=?', whereArgs: [fromHoldingId]);
    if (rows.isEmpty) return;
    final h = rows.first;
    final totalShares = (h['total_shares'] as num).toDouble();
    final totalCost = (h['total_cost'] as num).toDouble();
    if (fromShares > totalShares) return;
    final costSold = totalCost * (fromShares / totalShares);
    final remainingShares = totalShares - fromShares;
    final remainingCost = totalCost - costSold;
    final fromAmount = fromShares * fromNav;

    await d.transaction((txn) async {
      // 卖出A
      await txn.insert('transactions', {
        'id': _uuid.v4(), 'book_id': bookId,
        'account_id': fromAccountId,
        'type': 'invest', 'amount': fromAmount,
        'datetime': txnD, 'note': '\u8f6c\u6362\u8f6c\u51fa ' + (h['code'] as String),
        'is_investment': 1, 'created_at': now,
      });
      if (remainingShares <= 0.001) {
        await txn.update('investment_holdings',
          {'total_shares': 0, 'total_cost': 0, 'is_liquidated': 1, 'updated_at': now},
          where: 'id=?', whereArgs: [fromHoldingId]);
      } else {
        await txn.update('investment_holdings',
          {'total_shares': remainingShares, 'total_cost': remainingCost, 'updated_at': now},
          where: 'id=?', whereArgs: [fromHoldingId]);
      }
      // 买入B
      final existing = await txn.query('investment_holdings',
        where: "book_id=? AND account_id=? AND code=? AND is_liquidated=0",
        whereArgs: [bookId, fromAccountId, toCode]);
      if (existing.isNotEmpty) {
        final o = existing.first;
        final oldShares = (o['total_shares'] as num).toDouble();
        final oldCost = (o['total_cost'] as num).toDouble();
        await txn.update('investment_holdings',
          {'total_shares': oldShares + toShares, 'total_cost': oldCost + fromAmount,
           'latest_nav': toNav, 'nav_date': txnD, 'updated_at': now},
          where: 'id=?', whereArgs: [o['id']]);
      } else {
        await txn.insert('investment_holdings', {
          'id': _uuid.v4(), 'book_id': bookId, 'account_id': fromAccountId,
          'code': toCode, 'name': toName, 'inv_type': 'fund',
          'total_cost': fromAmount, 'total_shares': toShares,
          'latest_nav': toNav, 'nav_date': txnD, 'fee_type': 'custom',
          'is_liquidated': 0, 'created_at': now, 'updated_at': now,
        });
      }
      // 手续费
      if (fee > 0) {
        await txn.insert('transactions', {
          'id': _uuid.v4(), 'book_id': bookId,
          'account_id': fromAccountId,
          'type': 'expense', 'amount': fee,
          'datetime': txnD, 'note': '\u8f6c\u6362\u624b\u7eed\u8d39',
          'is_investment': 1, 'created_at': now,
        });
      }
      // 退回
      if (refund > 0 && refundAccountId != null) {
        await txn.insert('transactions', {
          'id': _uuid.v4(), 'book_id': bookId,
          'account_id': refundAccountId,
          'type': 'income', 'amount': refund,
          'datetime': txnD, 'note': '\u8f6c\u6362\u9000\u56de',
          'is_investment': 1, 'created_at': now,
        });
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [refund, now, refundAccountId]);
      }
      // 更新投资账户余额
      final allH = await txn.query('investment_holdings',
        where: "account_id=? AND is_liquidated=0",
        whereArgs: [fromAccountId]);
      double tv = 0;
      for (final h2 in allH) {
        final s = (h2['total_shares'] as num).toDouble();
        final n = (h2['latest_nav'] as num?)?.toDouble();
        if (n != null) tv += s * n;
      }
      await txn.rawUpdate(
        'UPDATE accounts SET balance = ?, updated_at = ? WHERE id = ?',
        [tv, now, fromAccountId]);
    });
  }
"""

# Insert before last }
last_brace = content.rstrip().rfind("\n}")
content = content[:last_brace] + switch_method + "\n}"

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("database_helper.dart done")
