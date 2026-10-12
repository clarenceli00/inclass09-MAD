import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:inclass09/database_helper.dart';
import 'package:inclass09/catalogue_repository.dart';
import 'package:inclass09/models.dart';

void main() {
  sqfliteFfiInit();
  test('v1 migration, CRUD, constraints, cascade and disk reopen', () async {
    final directory = await Directory.systemTemp.createTemp('catalogue_test_');
    final path = '${directory.path}/MyDatabase.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE my_table (_id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL)',
          );
          await db.insert('my_table', {
            '_id': 7,
            'name': 'Maple Reed',
            'age': 24,
          });
        },
      ),
    );
    await legacy.close();
    var helper = DatabaseHelper();
    await helper.init(databasePath: path, factory: databaseFactoryFfi);
    var repo = CatalogueRepository(helper);
    expect(await helper.queryAllRows(), [
      {'_id': 7, 'name': 'Maple Reed', 'age': 24},
    ]);
    expect(await helper.database.getVersion(), 2);
    expect(
      (await helper.database.rawQuery('PRAGMA foreign_keys'))
          .single
          .values
          .single,
      1,
    );
    final folder = await repo.saveFolder(
      const Folder(name: 'Favorites', createdAt: '2026-10-12T12:00:00Z'),
    );
    final other = await repo.saveFolder(
      const Folder(name: 'Other', createdAt: '2026-10-12T12:00:00Z'),
    );
    await expectLater(
      repo.saveFolder(const Folder(name: 'Favorites', createdAt: 'now')),
      throwsA(isA<DatabaseException>()),
    );
    final id = await repo.saveCard(
      CatalogueCard(
        title: 'Ace',
        suit: 'Hearts',
        folderId: folder,
        imageRef: 'https://example.com/ace.png',
      ),
    );
    expect((await repo.cards(folder)).single.id, id);
    expect(
      await repo.saveCard(
        CatalogueCard(
          id: id,
          title: 'Ace edited',
          suit: 'Hearts',
          notes: 'Moved',
          folderId: other,
          imageRef: 'asset:images/ace.png',
        ),
      ),
      1,
    );
    expect(await repo.cards(folder), isEmpty);
    expect((await repo.cards(other)).single.notes, 'Moved');
    expect(
      await repo.saveFolder(
        Folder(id: other, name: 'Archive', createdAt: '2026-10-12T12:00:00Z'),
      ),
      1,
    );
    await expectLater(
      repo.saveCard(
        const CatalogueCard(title: 'Orphan', suit: 'Clubs', folderId: 99999),
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      helper.database.insert('cards', {
        'title': 'Null',
        'suit': 'Clubs',
        'folder_id': null,
      }),
      throwsA(isA<DatabaseException>()),
    );
    final disposable = await repo.saveCard(
      CatalogueCard(title: 'Delete me', suit: 'Spades', folderId: folder),
    );
    expect(await repo.deleteCard(disposable), 1);
    expect(await repo.deleteCard(disposable), 0);
    await helper.close();
    helper = DatabaseHelper();
    await helper.init(databasePath: path, factory: databaseFactoryFfi);
    repo = CatalogueRepository(helper);
    expect((await repo.cards(other)).single.folderId, other);
    expect((await repo.cards(other)).single.title, 'Ace edited');
    expect((await helper.queryAllRows()).single['name'], 'Maple Reed');
    expect(await repo.deleteFolder(other), 1);
    expect(await repo.cards(other), isEmpty);
    expect(await helper.database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(await helper.queryRowCount(), 1);
    await helper.close();
    await directory.delete(recursive: true);
  });
}
