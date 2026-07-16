import re

path = r"D:\codexproject\pj_003_账本app\my_account_book\lib\database\database_helper.dart"
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. In recordInvestment: capture txnId, enhance note, set related_investment_id
old_insert = """      await txn.insert('transactions', {
        'id': _uuid.v4(), 'book_id': bookId,
        'account_id': fromAccountId, 'to_account_id': accountId,
        'type': 'invest', 'amount': amount,
        'datetime': txnDatetime, 'note': note ?? code,
        'is_investment': 1, 'created_at': now,
      });"""

new_insert = """      final txnId = _uuid.v4();
      final detailNote = '\u4e70\u5165 ' + (note ?? code) + ' \u51c0\u503c$nav \u4efd\u989d${shares.toStringAsFixed(2)} \u624b\u7eed\u8d39${fee.toStringAsFixed(2)}';
      await txn.insert('transactions', {
        'id': txnId, 'book_id': bookId,
        'account_id': fromAccountId, 'to_account_id': accountId,
        'type': 'invest', 'amount': amount,
        'datetime': txnDatetime, 'note': detailNote,
        'is_investment': 1, 'created_at': now,
      });"""

content = content.replace(old_insert, new_insert)

# 2. Add related_investment_id update after the upsert block
old_upsert_end = """      }
      // \u6309\u5e02\u503c\u91cd\u7b97\u6295\u8d44\u8d26\u6237\u4f59\u989d"""

new_upsert_end = """        } else {
          holdingId = _uuid.v4();
        }
      }
      // \u5173\u8054\u4ea4\u6613\u4e0e\u6301\u4ed3
      if (holdingId != null) {
        await txn.rawUpdate(
          'UPDATE transactions SET related_investment_id = ? WHERE id = ?',
          [holdingId, txnId]);
      }
      // \u6309\u5e02\u503c\u91cd\u7b97\u6295\u8d44\u8d26\u6237\u4f59\u989d"""

# But first I need to capture the holding ID from the if-else block
# The existing code uses old['id'] and _uuid.v4() for new holdings
# Let me restructure: capture the holding ID in a variable
old_upsert = """      if (existing.isNotEmpty) {
        final old = existing.first;
        final oldShares = (old['total_shares'] as num).toDouble();
        final oldCost = (old['total_cost'] as num).toDouble();
        await txn.update('investment_holdings', {
          'total_shares': oldShares + shares,
          'total_cost': oldCost + amount,
          'latest_nav': nav, 'nav_date': now, 'updated_at': now,
        }, where: 'id=?', whereArgs: [old['id']]);
      } else {
        await txn.insert('investment_holdings', {
          'id': _uuid.v4(), 'book_id': bookId,
          'account_id': accountId, 'code': code, 'name': name,
          'inv_type': invType, 'total_cost': amount,
          'total_shares': shares, 'latest_nav': nav,
          'nav_date': now, 'fee_type': feeType,
          'is_liquidated': 0, 'created_at': now, 'updated_at': now,
        });
     }"""

new_upsert = """      String? holdingId;
      if (existing.isNotEmpty) {
        final old = existing.first;
        holdingId = old['id'] as String;
        final oldShares = (old['total_shares'] as num).toDouble();
        final oldCost = (old['total_cost'] as num).toDouble();
        await txn.update('investment_holdings', {
          'total_shares': oldShares + shares,
          'total_cost': oldCost + amount,
          'latest_nav': nav, 'nav_date': now, 'updated_at': now,
        }, where: 'id=?', whereArgs: [holdingId]);
      } else {
        holdingId = _uuid.v4();
        await txn.insert('investment_holdings', {
          'id': holdingId, 'book_id': bookId,
          'account_id': accountId, 'code': code, 'name': name,
          'inv_type': invType, 'total_cost': amount,
          'total_shares': shares, 'latest_nav': nav,
          'nav_date': now, 'fee_type': feeType,
          'is_liquidated': 0, 'created_at': now, 'updated_at': now,
        });
      }
      // \u5173\u8054\u4ea4\u6613\u4e0e\u6301\u4ed3
      await txn.rawUpdate(
        'UPDATE transactions SET related_investment_id = ? WHERE id = ?',
        [holdingId, txnId]);"""

content = content.replace(old_upsert, new_upsert)

# 3. Fix deleteTransaction to handle invest rollback
old_delete_invest = """      if (t.type == 'expense') {
        reverseFrom();
      } else if (t.type == 'income') {"""

new_delete_invest = """      if (t.type == 'expense') {
        reverseFrom();
      } else if (t.type == 'invest' && t.relatedInvestmentId != null) {
        final hRows = await txn.query('investment_holdings',
          where: 'id=?', whereArgs: [t.relatedInvestmentId]);
        if (hRows.isNotEmpty) {
          final h = hRows.first;
          final oldShares = (h['total_shares'] as num).toDouble();
          final oldCost = (h['total_cost'] as num).toDouble();
          double costRatio = oldCost > 0 ? (t.amount / oldCost).clamp(0, 1) : 0;
          double sharesToRemove = oldShares * costRatio;
          double newShares = (oldShares - sharesToRemove).clamp(0, double.infinity);
          double newCost = (oldCost - t.amount).clamp(0, double.infinity);
          if (newShares <= 0.001) {
            await txn.update('investment_holdings',
              {'total_shares': 0, 'total_cost': 0, 'is_liquidated': 1, 'updated_at': t.createdAt},
              where: 'id=?', whereArgs: [t.relatedInvestmentId]);
          } else {
            await txn.update('investment_holdings',
              {'total_shares': newShares, 'total_cost': newCost, 'updated_at': t.createdAt},
              where: 'id=?', whereArgs: [t.relatedInvestmentId]);
          }
        }
      } else if (t.type == 'income') {"""

content = content.replace(old_delete_invest, new_delete_invest)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')
