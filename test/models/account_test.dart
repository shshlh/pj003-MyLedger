import "package:flutter_test/flutter_test.dart";
import "package:my_account_book/models/account.dart";
void main() {
  group("Account", () {
    test("toMap and fromMap", () {
      final a = Account(id: "a1", bookId: "b1", name: "cash", type: "debit", balance: 5000.0, billingDay: 5, createdAt: "2026-01-01", updatedAt: "2026-07-16");
      final r = Account.fromMap(a.toMap());
      expect(r.name, "cash"); expect(r.balance, 5000.0);
    });
    test("defaults", () {
      final a = Account(id: "a2", bookId: "b1", name: "cc", type: "credit", createdAt: "2026-01-01", updatedAt: "2026-01-01");
      expect(a.status, "active"); expect(a.billingDay, isNull);
    });
  });
}
