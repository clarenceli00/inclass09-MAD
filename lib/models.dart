class Folder {
  const Folder({this.id, required this.name, required this.createdAt});
  final int? id;
  final String name;
  final String createdAt;
  factory Folder.fromMap(Map<String, Object?> row) => Folder(
    id: row['id'] as int,
    name: row['name'] as String,
    createdAt: row['created_at'] as String,
  );
  Map<String, Object?> toMap() => {
    'name': name.trim(),
    'created_at': createdAt,
  };
}

class CatalogueCard {
  const CatalogueCard({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });
  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;
  factory CatalogueCard.fromMap(Map<String, Object?> row) => CatalogueCard(
    id: row['id'] as int,
    title: row['title'] as String,
    suit: row['suit'] as String,
    notes: row['notes'] as String,
    imageRef: row['image_ref'] as String?,
    folderId: row['folder_id'] as int,
  );
  Map<String, Object?> toMap() => {
    'title': title.trim(),
    'suit': suit.trim(),
    'notes': notes,
    'image_ref': imageRef,
    'folder_id': folderId,
  };
}
