 class Transaction {
   final String id;
   final String bookId;
   final String accountId;
   final String? toAccountId; // 转账目标账户
   final String? categoryId;
   final String type; // expense / income / transfer / invest
   final double amount;
   final String datetime;
   final String? note;
   final int isInvestment; // 0=日常, 1=投资
   final String? relatedInvestmentId;
   final String createdAt;
   final String updatedAt;
   final String? batchId;
 
   Transaction({
     required this.id,
     required this.bookId,
     required this.accountId,
     this.toAccountId,
     this.categoryId,
     required this.type,
     required this.amount,
     required this.datetime,
     this.note,
     this.isInvestment = 0,
     this.relatedInvestmentId,
    required this.updatedAt,
    this.batchId,
     required this.createdAt,
   });
 
   Map<String, dynamic> toMap() => {
     'id': id,
     'book_id': bookId,
     'account_id': accountId,
     'to_account_id': toAccountId,
     'category_id': categoryId,
     'type': type,
     'amount': amount,
     'datetime': datetime,
     'note': note,
     'is_investment': isInvestment,
     'related_investment_id': relatedInvestmentId,
     'created_at': createdAt,
    'updated_at': updatedAt,
    'batch_id': batchId,
   };
 
   factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
     id: m['id'],
     bookId: m['book_id'],
     accountId: m['account_id'],
     toAccountId: m['to_account_id'],
     categoryId: m['category_id'],
     type: m['type'],
     amount: (m['amount'] ?? 0).toDouble(),
     datetime: m['datetime'],
     note: m['note'],
     isInvestment: m['is_investment'] ?? 0,
     relatedInvestmentId: m['related_investment_id'],
     createdAt: m['created_at'],
    updatedAt: m['updated_at'] ?? m['created_at'],
    batchId: m['batch_id'],
   );
 }
