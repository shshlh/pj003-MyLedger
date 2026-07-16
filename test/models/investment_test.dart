import "package:flutter_test/flutter_test.dart";
import "package:my_account_book/models/investment.dart";
void main() {
  group("InvestmentHolding", () {
    test("toMap/fromMap", () {
      final h = InvestmentHolding(id: "inv1", bookId: "b1", accountId: "a1", code: "000001", name: "fund", invType: "fund", totalCost: 10000, totalShares: 8888.88, latestNav: 1.2345, navDate: "2026-07-01", feeType: "A", isLiquidated: 0, createdAt: "2026-01-01", updatedAt: "2026-07-01");
      final r = InvestmentHolding.fromMap(h.toMap());
      expect(r.code, "000001"); expect(r.totalCost, 10000); expect(r.latestNav, 1.2345);
    });
    test("null nav", () {
      final h = InvestmentHolding(id: "inv2", bookId: "b1", accountId: "a1", code: "000002", invType: "fund", createdAt: "2026-01-01", updatedAt: "2026-07-01");
      expect(h.latestNav, isNull); expect(h.isLiquidated, 0);
    });
    test("liquidated", () {
      final h = InvestmentHolding(id: "inv3", bookId: "b1", accountId: "a1", code: "000003", invType: "fund", isLiquidated: 1, createdAt: "2026-01-01", updatedAt: "2026-07-01");
      expect(h.isLiquidated, 1);
    });
  });
}
