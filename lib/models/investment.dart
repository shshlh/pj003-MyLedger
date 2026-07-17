class InvestmentHolding {
  final String id;
  final String bookId;
  final String accountId;
  final String code;
  final String? name;
 final String invType;
  /// 成本基数（累计买入金额 - 累计卖出按比例扣减的成本，非累计投入总额）
 final double totalCost;
 final double totalShares;
  final double? latestNav;
  final String? navDate;
  final String feeType;
  final int isLiquidated;
  final String createdAt;
  final String updatedAt;

  InvestmentHolding({
    required this.id,
    required this.bookId,
    required this.accountId,
    required this.code,
    this.name,
    required this.invType,
    this.totalCost = 0,
    this.totalShares = 0,
    this.latestNav,
    this.navDate,
    this.feeType = 'A',
    this.isLiquidated = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'book_id': bookId,
    'account_id': accountId,
    'code': code,
    'name': name,
    'inv_type': invType,
    'total_cost': totalCost,
    'total_shares': totalShares,
    'latest_nav': latestNav,
    'nav_date': navDate,
    'fee_type': feeType,
    'is_liquidated': isLiquidated,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory InvestmentHolding.fromMap(Map<String, dynamic> m) => InvestmentHolding(
    id: m['id'],
    bookId: m['book_id'],
    accountId: m['account_id'],
    code: m['code'],
    name: m['name'],
    invType: m['inv_type'],
    totalCost: (m['total_cost'] ?? 0).toDouble(),
    totalShares: (m['total_shares'] ?? 0).toDouble(),
    latestNav: (m['latest_nav'] as num?)?.toDouble(),
    navDate: m['nav_date'],
    feeType: m['fee_type'] ?? 'A',
    isLiquidated: m['is_liquidated'] ?? 0,
    createdAt: m['created_at'],
    updatedAt: m['updated_at'],
  );
}
