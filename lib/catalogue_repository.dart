import 'database_helper.dart';
import 'models.dart';

class CatalogueRepository {
  CatalogueRepository(this.helper);
  final DatabaseHelper helper;
  Future<List<Folder>> folders() async => (await helper.database.query(
    'folders',
    orderBy: 'name COLLATE NOCASE, id',
  )).map(Folder.fromMap).toList();
  Future<List<CatalogueCard>> cards(int folderId) async =>
      (await helper.database.query(
        'cards',
        where: 'folder_id = ?',
        whereArgs: [folderId],
        orderBy: 'id',
      )).map(CatalogueCard.fromMap).toList();
  Future<int> saveFolder(Folder folder) {
    if (folder.name.trim().isEmpty) throw ArgumentError('Enter a folder name.');
    return folder.id == null
        ? helper.database.insert('folders', folder.toMap())
        : helper.database.update(
            'folders',
            folder.toMap(),
            where: 'id = ?',
            whereArgs: [folder.id],
          );
  }

  Future<int> saveCard(CatalogueCard card) {
    if (card.title.trim().isEmpty || card.suit.trim().isEmpty) {
      throw ArgumentError('Title and suit are required.');
    }
    final ref = card.imageRef;
    if (ref != null && ref.isNotEmpty && !validImageReference(ref)) {
      throw ArgumentError('Use asset:, file:, or an https:// image reference.');
    }
    return card.id == null
        ? helper.database.insert('cards', card.toMap())
        : helper.database.update(
            'cards',
            card.toMap(),
            where: 'id = ?',
            whereArgs: [card.id],
          );
  }

  Future<int> deleteFolder(int id) =>
      helper.database.delete('folders', where: 'id = ?', whereArgs: [id]);
  Future<int> deleteCard(int id) =>
      helper.database.delete('cards', where: 'id = ?', whereArgs: [id]);
  static bool validImageReference(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return (uri.scheme == 'https' && uri.host.isNotEmpty) ||
        ((uri.scheme == 'asset' || uri.scheme == 'file') &&
            uri.path.isNotEmpty);
  }
}
