import 'package:flutter/material.dart';
import 'database_helper.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text(
          'Could not open local storage. Restart the app and check the logs.',
        )),
      ),
    ));
    return;
  }
  runApp(DirectoryApp(helper: helper));
}
class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});
  final DatabaseHelper helper;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fall Festival Guest Roster',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange)),
    home: MyHomePage(title: 'Fall Festival', helper: helper),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.helper});
  final String title;
  final DatabaseHelper helper;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // A temporary display of database results, not permanent storage.
  List<Map<String, dynamic>> _guests = [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _busy = true; _error = null; });
    try {
      final rows = await widget.helper.queryAllRows();
      if (mounted) setState(() => _guests = rows);
    } catch (error, stackTrace) {
      debugPrint('Loading failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = 'Could not load guests. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(Future<void> Function() operation, String message) async {
    setState(() => _busy = true);
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _refresh();
    } catch (error, stackTrace) {
      debugPrint('Save failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the change. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showGuestForm({Map<String, dynamic>? guest}) async {
    final formKey = GlobalKey<FormState>();
    final editing = guest != null;
    var name = guest?[DatabaseHelper.columnName] as String? ?? '';
    var age = guest?[DatabaseHelper.columnAge] as int? ?? 0;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(editing ? 'Correct age' : 'Register guest'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                initialValue: name,
                readOnly: editing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Guest name', hintText: 'Maple Reed'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter a name.' : null,
                onSaved: (value) => name = value!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: editing ? age.toString() : '',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');
                  return number == null || number < 0 || number > 130
                    ? 'Enter a whole number from 0 to 120.' : null;
                },
                onSaved: (value) => age = int.parse(value!.trim()),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(editing ? 'Save age' : 'Register'),
          ),
        ],
      ),
    );
    if (!mounted || submitted != true) return;
    await _save(() async {
      if (guest != null) {
        final affected = await widget.helper.update({
          DatabaseHelper.columnId: guest[DatabaseHelper.columnId],
          DatabaseHelper.columnAge: age,
        });
        if (affected != 1) throw StateError('Guest no longer exists.');
      } else {
        // SQLite generates the ID; never supply one for registration.
        await widget.helper.insert({DatabaseHelper.columnName: name, DatabaseHelper.columnAge: age});
      }
    }, editing ? 'Age updated.' : 'Guest registered.');
  }

  Future<void> _confirmDelete(Map<String, dynamic> guest) async {
    final id = guest[DatabaseHelper.columnId] as int;
    final name = guest[DatabaseHelper.columnName] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove guest?'),
        content: Text('Remove $name (ID $id) from the roster?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _save(() async {
      final affected = await widget.helper.delete(id);
      if (affected != 1) throw StateError('Guest no longer exists.');
    }, 'Guest removed.');
  }

  Widget _buildRoster() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 12),
        Text(_error!),
        FilledButton(onPressed: _refresh, child: const Text('Retry')),
      ]));
    }
    if (_guests.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people_outline, size: 64),
        SizedBox(height: 12),
        Text('No guests registered yet.'),
        Text('Tap Register guest to begin.'),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _guests.length,
      itemBuilder: (context, index) {
        final guest = _guests[index];
        final id = guest[DatabaseHelper.columnId];
        final age = guest[DatabaseHelper.columnAge];
        return Card(
          key: ValueKey(id),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(guest[DatabaseHelper.columnName] as String),
            subtitle: Text('Age $age • ID $id'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Correct age', onPressed: () => _showGuestForm(guest: guest), icon: const Icon(Icons.edit_outlined)),
              IconButton(tooltip: 'Remove guest', onPressed: () => _confirmDelete(guest), icon: const Icon(Icons.delete_outline)),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [IconButton(tooltip: 'Refresh roster', onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh))],
    ),
    body: SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: Alignment.centerLeft, child: Text('Guest roster', style: Theme.of(context).textTheme.headlineSmall)),
      ),
      Expanded(child: _buildRoster()),
    ])),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _showGuestForm(),
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Register guest'),
    ),
  );
}
