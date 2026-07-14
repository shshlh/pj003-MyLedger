 class Book {
   final String id;
   final String name;
   final String? cover;
   final String createdAt;
   final String updatedAt;
 
   Book({
     required this.id,
     required this.name,
     this.cover,
     required this.createdAt,
     required this.updatedAt,
   });
 
   Map<String, dynamic> toMap() => {
     'id': id,
     'name': name,
     'cover': cover,
     'created_at': createdAt,
     'updated_at': updatedAt,
   };
 
   factory Book.fromMap(Map<String, dynamic> m) => Book(
     id: m['id'],
     name: m['name'],
     cover: m['cover'],
     createdAt: m['created_at'],
     updatedAt: m['updated_at'],
   );
 }
