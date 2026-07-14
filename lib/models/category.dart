 class Category {
   final String id;
   final String bookId;
   final String name;
   final String type; // income / expense
   final String? parentId; // null = 一级分类
   final String? icon;
   final int sortOrder;
   final String createdAt;
 
   Category({
     required this.id,
     required this.bookId,
     required this.name,
     required this.type,
     this.parentId,
     this.icon,
     this.sortOrder = 0,
     required this.createdAt,
   });
 
   Map<String, dynamic> toMap() => {
     'id': id,
     'book_id': bookId,
     'name': name,
     'type': type,
     'parent_id': parentId,
     'icon': icon,
     'sort_order': sortOrder,
     'created_at': createdAt,
   };
 
   factory Category.fromMap(Map<String, dynamic> m) => Category(
     id: m['id'],
     bookId: m['book_id'],
     name: m['name'],
     type: m['type'],
     parentId: m['parent_id'],
     icon: m['icon'],
     sortOrder: m['sort_order'] ?? 0,
     createdAt: m['created_at'],
   );
 }
