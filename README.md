# Part II: Card catalogue

Open Catalogue from the existing guest roster. Create folders and cards, edit
cards to move them between folders, and edit/delete records using the displayed
IDs. Folder deletion asks for confirmation and cascades to all its cards.

## Database and layers

DatabaseHelper opens the original documents-directory MyDatabase.db, now at
version 2. Its transactional upgrade creates folders, cards, and the folder_id
index without dropping or reseeding my_table. Fresh installs create all three.
onConfigure enables foreign keys on every connection. NOT NULL and the foreign
key require exactly one existing parent per card. Folder names are unique.
Models map typed objects to rows; CatalogueRepository validates and performs
parameterized CRUD; CataloguePage manages UI without SQL. Part I remains usable.

## Image references

image_ref is nullable TEXT containing a reference, not image bytes:

- asset:images/ace.png references a bundled asset declared in pubspec.
- file:///path/ace.png references a local file. Use a durable app-owned file,
  not a temporary cache or picker path. The app does not copy/import files.
- https://example.com/ace.png references a remote image requiring network access.
- Actual image bytes would use a BLOB or a separately managed file, not this
  reference column. Base64 is not stored here.

Blank means no image; missing images show a fallback icon. Deleting rows does
not delete local files, assets, or remote images.

## Observed verification (October 12, 2026)

The catalogue database test passed: migration of a real v1 disk database,
unchanged Part I guest ID 7, folder/card CRUD, moving a card, duplicate folder
rejection, invalid/null parent rejection, close/reopen persistence, cascade
deletion, and an empty PRAGMA foreign_key_check result.

These two separate test-process executions also both passed:

```powershell
flutter test test/restart_test.dart --dart-define=RESTART_PHASE=write
flutter test test/restart_test.dart --dart-define=RESTART_PHASE=read
```

The first process saved a v1 guest, migrated, and saved a folder/card. The second
opened the same disk file and verified guest ID 42 and the saved card's parent
relationship. It cleaned up the isolated database under build/restart-proof.

This proves repository/SQLite persistence across process restarts. A manual
Android app cold restart has not been observed. Collect that demonstration:

1. Keep the existing Part I installation; do not uninstall or clear storage.
   Record an existing guest's ID, name, and age.
2. Launch the updated app and verify that guest. Create a folder/card and note
   their IDs. Edit the card and verify the change.
3. Force-stop the app and launch it again (no hot reload/hot restart). Capture
   the original guest and the saved card with its folder ID after launch.
4. Delete a disposable folder containing cards. Verify its cards disappear and
   the Part I guest and other folders/cards remain.

Run the application on Android/iOS with sqflite. Windows/web runtime database
support is not added; sqflite_common_ffi is a host-test dependency only.
