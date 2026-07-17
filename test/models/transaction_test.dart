import "package:flutter_test/flutter_test.dart";
import "package:my_account_book/models/transaction.dart";
void main() {
  group("Transaction", () {
    test("expense round trip", () {
      final t = Transaction(id: "t1", bookId: "b1", accountId: "a1", categoryId: "c1", type: "expense", amount: 100.0, datetime: "2026-07-01", isInvestment: 0, createdAt: "2026-07-01", updatedAt: "2026-07-01");
      final r = Transaction.fromMap(t.toMap());
      expect(r.type, "expense"); expect(r.amount, 100.0);
    });
    test("invest with related id", () {
      final t = Transaction(id: "t2", bookId: "b1", accountId: "a1", toAccountId: "a2", type: "invest", amount: 5000.0, datetime: "2026-07-01", isInvestment: 1, relatedInvestmentId: "inv1", createdAt: "2026-07-01", updatedAt: "2026-07-01");
      expect(t.isInvestment, 1); expect(t.relatedInvestmentId, "inv1");
    });
    test("transfer", () {
      final t = Transaction(id: "t3", bookId: "b1", accountId: "a1", toAccountId: "a2", type: "transfer", amount: 200.0, datetime: "2026-07-01", isInvestment: 0, createdAt: "2026-07-01", updatedAt: "2026-07-01");
      expect(t.type, "transfer"); expect(t.toAccountId, "a2");
    });
  });
}
