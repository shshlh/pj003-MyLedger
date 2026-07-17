 class PeriodicBill {
   final String id;
   final String bookId;
   final String name;
   final String type; // expense / income
   final double amount;
   final String accountId;
   final String? categoryId;
   final String frequency; // daily / weekly / monthly / yearly / custom
   final int? intervalDays;
   final String startDate;
   final String? endDate;
   final String nextRunDate;
 final int enabled; // 0=暂停, 1=启用
 final String createdAt;
  final String? updatedAt;

 PeriodicBill({
     required this.id,
     required this.bookId,
     required this.name,
     required this.type,
     required this.amount,
     required this.accountId,
     this.categoryId,
     required this.frequency,
     this.intervalDays,
     required this.startDate,
     this.endDate,
     required this.nextRunDate,
   this.enabled = 1,
   required this.createdAt,
    this.updatedAt,
 });

 Map<String, dynamic> toMap() => {
     'id': id,
     'book_id': bookId,
     'name': name,
     'type': type,
     'amount': amount,
     'account_id': accountId,
     'category_id': categoryId,
     'frequency': frequency,
     'interval_days': intervalDays,
     'start_date': startDate,
     'end_date': endDate,
     'next_run_date': nextRunDate,
   'enabled': enabled,
   'created_at': createdAt,
    'updated_at': updatedAt,
 };

 factory PeriodicBill.fromMap(Map<String, dynamic> m) => PeriodicBill(
     id: m['id'],
     bookId: m['book_id'],
     name: m['name'],
     type: m['type'],
     amount: (m['amount'] ?? 0).toDouble(),
     accountId: m['account_id'],
     categoryId: m['category_id'],
     frequency: m['frequency'],
     intervalDays: m['interval_days'],
     startDate: m['start_date'],
     endDate: m['end_date'],
     nextRunDate: m['next_run_date'],
   enabled: m['enabled'] ?? 1,
   createdAt: m['created_at'],
    updatedAt: m['updated_at'],
 );
 }
