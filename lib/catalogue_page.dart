import 'dart:io';

import 'package:flutter/material.dart';

import 'catalogue_repository.dart';
import 'models.dart';

class CataloguePage extends StatefulWidget {
  const CataloguePage({super.key, required this.repository});
  final CatalogueRepository repository;
  @override
  State<CataloguePage> createState() => _CataloguePageState();
}

class _CataloguePageState extends State<CataloguePage> {
  List<Folder> folders = [];
  List<CatalogueCard> cards = [];
  int? selected;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final loaded = await widget.repository.folders();
      final id = loaded.any((f) => f.id == selected)
          ? selected
          : loaded.firstOrNull?.id;
      final children = id == null
          ? <CatalogueCard>[]
          : await widget.repository.cards(id);
      if (mounted) {
        setState(() {
          folders = loaded;
          selected = id;
          cards = children;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load catalogue: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change(
    Future<int> Function() action, {
    bool editing = false,
  }) async {
    setState(() => busy = true);
    try {
      final result = await action();
      if (editing && result != 1) throw StateError('This ID no longer exists.');
      await refresh();
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Change failed: $e')));
      }
    }
  }

  Future<void> folderForm([Folder? folder]) async {
    final value = await fields(
      'Folder${folder == null ? '' : ' ID ${folder.id}'}',
      {'Name': folder?.name ?? ''},
    );
    if (value == null || !mounted) return;
    await change(
      () => widget.repository.saveFolder(
        Folder(
          id: folder?.id,
          name: value['Name']!,
          createdAt:
              folder?.createdAt ?? DateTime.now().toUtc().toIso8601String(),
        ),
      ),
      editing: folder != null,
    );
  }

  Future<void> cardForm([CatalogueCard? card]) async {
    var folderId = card?.folderId ?? selected!;
    final value = await fields(
      'Card${card == null ? '' : ' ID ${card.id}'}',
      {
        'Title': card?.title ?? '',
        'Suit': card?.suit ?? '',
        'Notes': card?.notes ?? '',
        'Image reference': card?.imageRef ?? '',
      },
      extra: DropdownButtonFormField<int>(
        initialValue: folderId,
        decoration: const InputDecoration(labelText: 'Folder'),
        items: folders
            .map(
              (f) => DropdownMenuItem(
                value: f.id,
                child: Text('${f.name} (ID ${f.id})'),
              ),
            )
            .toList(),
        onChanged: (id) => folderId = id!,
      ),
    );
    if (value == null || !mounted) return;
    await change(
      () => widget.repository.saveCard(
        CatalogueCard(
          id: card?.id,
          title: value['Title']!,
          suit: value['Suit']!,
          notes: value['Notes']!,
          imageRef: value['Image reference']!.isEmpty
              ? null
              : value['Image reference'],
          folderId: folderId,
        ),
      ),
      editing: card != null,
    );
  }

  Future<Map<String, String>?> fields(
    String title,
    Map<String, String> values, {
    Widget? extra,
  }) async {
    final key = GlobalKey<FormState>();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...values.entries.map(
                    (entry) => TextFormField(
                      initialValue: entry.value,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        helperText: entry.key == 'Image reference'
                            ? 'asset:images/card.png, file:///path, https://…'
                            : null,
                      ),
                      validator: (v) {
                        if (entry.key != 'Notes' &&
                            entry.key != 'Image reference' &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Required';
                        }
                        if (entry.key == 'Image reference' &&
                            v!.trim().isNotEmpty &&
                            !CatalogueRepository.validImageReference(v.trim())) {
                          return 'Use asset:, file:, or https://';
                        }
                        return null;
                      },
                      onSaved: (v) => values[entry.key] = v!.trim(),
                    ),
                  ),
                  ?extra,
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                key.currentState!.save();
                Navigator.pop(ctx, values);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> remove(String description, Future<int> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm deletion'),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await change(action, editing: true);
  }

  Widget thumbnail(String? ref) {
    const fallback = Icon(Icons.image_not_supported_outlined);
    if (ref == null) return const Icon(Icons.style);
    final uri = Uri.parse(ref);
    Widget failed(BuildContext context, Object error, StackTrace? stack) =>
        fallback;
    if (uri.scheme == 'https') {
      return Image.network(
        ref,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: failed,
      );
    }
    if (uri.scheme == 'asset') {
      return Image.asset(
        ref.substring(6),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: failed,
      );
    }
    return Image.file(
      File.fromUri(uri),
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: failed,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Card catalogue'),
      actions: [
        IconButton(
          onPressed: busy ? null : refresh,
          tooltip: 'Refresh catalogue',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: busy
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: refresh, child: const Text('Retry')),
              ],
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => folderForm(),
                      icon: const Icon(Icons.create_new_folder),
                      label: const Text('New folder'),
                    ),
                    if (folders.isNotEmpty) ...[
                      DropdownButton<int>(
                        value: selected,
                        items: folders
                            .map(
                              (f) => DropdownMenuItem(
                                value: f.id,
                                child: Text('${f.name} (ID ${f.id})'),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          selected = id;
                          refresh();
                        },
                      ),
                      IconButton(
                        tooltip: 'Edit folder',
                        icon: const Icon(Icons.edit),
                        onPressed: () => folderForm(
                          folders.firstWhere((f) => f.id == selected),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete folder and cards',
                        icon: const Icon(Icons.delete),
                        onPressed: () => remove(
                          'Delete folder ID $selected and all ${cards.length} of its cards? This cannot be undone.',
                          () => widget.repository.deleteFolder(selected!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: cards.isEmpty
                    ? Center(
                        child: Text(
                          folders.isEmpty
                              ? 'Create a folder to start your catalogue.'
                              : 'No cards in this folder.',
                        ),
                      )
                    : ListView(
                        children: cards
                            .map(
                              (card) => Card(
                                child: ListTile(
                                  leading: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: thumbnail(card.imageRef),
                                  ),
                                  title: Text(card.title),
                                  subtitle: Text(
                                    '${card.suit} | Card ID ${card.id} | Folder ID ${card.folderId}\n${card.notes}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit card',
                                        onPressed: () => cardForm(card),
                                        icon: const Icon(Icons.edit),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete card',
                                        onPressed: () => remove(
                                          'Delete card ID ${card.id} (${card.title})?',
                                          () => widget.repository.deleteCard(
                                            card.id!,
                                          ),
                                        ),
                                        icon: const Icon(Icons.delete),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
    floatingActionButton: selected == null || busy
        ? null
        : FloatingActionButton.extended(
            onPressed: () => cardForm(),
            icon: const Icon(Icons.add),
            label: const Text('New card'),
          ),
  );
}
