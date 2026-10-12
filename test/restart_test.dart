import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:inclass09/database_helper.dart';
import 'package:inclass09/catalogue_repository.dart';
import 'package:inclass09/models.dart';

// Run in two separate flutter test processes; never touches the app database.
void main() {
  const phase = String.fromEnvironment('RESTART_PHASE');
  test('cold process restart: $phase', () async {
    sqfliteFfiInit();
    final path = '${Directory.current.path}/build/restart-proof/MyDatabase.db';
    final directory = Directory(
      '${Directory.current.path}/build/restart-proof',
    );
    if (phase == 'write') {
      await directory.create(recursive: true);
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE my_table (_id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL)',
            );
            await db.insert('my_table', {
              '_id': 42,
              'name': 'Restart guest',
              'age': 31,
            });
          },
        ),
      );
      await legacy.close();
    }
    final helper = DatabaseHelper();
    await helper.init(databasePath: path, factory: databaseFactoryFfi);
    final repo = CatalogueRepository(helper);
    if (phase == 'write') {
      final id = await repo.saveFolder(
        const Folder(name: 'Restart folder', createdAt: '2026-10-12T12:00:00Z'),
      );
      await repo.saveCard(
        CatalogueCard(title: 'Persistent ace', suit: 'Hearts', folderId: id),
      );
    } else {
      final folder = (await repo.folders()).single;
      final card = (await repo.cards(folder.id!)).single;
      expect(folder.name, 'Restart folder');
      expect(card.title, 'Persistent ace');
      expect(card.folderId, folder.id);
      expect(await helper.queryAllRows(), [
        {'_id': 42, 'name': 'Restart guest', 'age': 31},
      ]);
      expect(
        await helper.database.rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    }
    await helper.close();
    if (phase == 'read') await directory.delete(recursive: true);
  }, skip: phase.isEmpty);
}
