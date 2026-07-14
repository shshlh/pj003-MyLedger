 class Account {
   final String id;
   final String bookId;
   final String name;
   final String type; // cash/debit/credit/invest/receivable/payable
   final double balance;
   final String currency;
   final String status; // active/archived/deleted
   final int? billingDay;
   final int? repaymentDay;
   final int sortOrder;
   final String createdAt;
   final String updatedAt;
 
   Account({
     required this.id,
     required this.bookId,
     required this.name,
     required this.type,
     this.balance = 0,
     this.currency = 'CNY',
     this.status = 'active',
     this.billingDay,
     this.repaymentDay,
     this.sortOrder = 0,
     required this.createdAt,
     required this.updatedAt,
   });
 
   Map<String, dynamic> toMap() => {
     'id': id,
     'book_id': bookId,
     'name': name,
     'type': type,
     'balance': balance,
     'currency': currency,
     'status': status,
     'billing_day': billingDay,
     'repayment_day': repaymentDay,
     'sort_order': sortOrder,
     'created_at': createdAt,
     'updated_at': updatedAt,
   };
 
   factory Account.fromMap(Map<String, dynamic> m) => Account(
     id: m['id'],
     bookId: m['book_id'],
     name: m['name'],
     type: m['type'],
     balance: (m['balance'] ?? 0).toDouble(),
     currency: m['currency'] ?? 'CNY',
     status: m['status'] ?? 'active',
     billingDay: m['billing_day'],
     repaymentDay: m['repayment_day'],
     sortOrder: m['sort_order'] ?? 0,
     createdAt: m['created_at'],
     updatedAt: m['updated_at'],
   );
 }
