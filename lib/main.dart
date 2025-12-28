import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatefulWidget {
  const TodoApp({Key? key}) : super(key: key);

  @override
  State<TodoApp> createState() => TodoAppState();

  static TodoAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<TodoAppState>();
  }
}

class TodoAppState extends State<TodoApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString('themeMode') ?? 'system';
    setState(() {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeModeString,
        orElse: () => ThemeMode.system,
      );
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    setState(() {
      _themeMode = mode;
    });
  }

  ThemeMode get themeMode => _themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({Key? key}) : super(key: key);

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final List<TodoItem> _todos = [];
  final List<TodoItem> _history = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = prefs.getString('todos');
    final historyJson = prefs.getString('history');

    setState(() {
      if (todosJson != null) {
        final List<dynamic> decoded = jsonDecode(todosJson);
        _todos.addAll(decoded.map((e) => TodoItem.fromJson(e)));
      }
      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _history.addAll(decoded.map((e) => TodoItem.fromJson(e)));
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('todos', jsonEncode(_todos.map((e) => e.toJson()).toList()));
    await prefs.setString('history', jsonEncode(_history.map((e) => e.toJson()).toList()));
  }

  void _addTodo() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _todos.add(TodoItem(
        id: DateTime.now().toString(),
        title: _controller.text.trim(),
        isCompleted: false,
        createdAt: DateTime.now(),
      ));
      _controller.clear();
    });
    _saveData();
  }

  void _toggleTodo(int index) {
    setState(() {
      _todos[index].isCompleted = !_todos[index].isCompleted;
      if (_todos[index].isCompleted) {
        _todos[index].completedAt = DateTime.now();
      } else {
        _todos[index].completedAt = null;
      }
    });
    _saveData();
  }

  void _deleteTodo(int index) {
    setState(() {
      final removed = _todos.removeAt(index);
      removed.deletedAt = DateTime.now();
      _history.add(removed);
    });
    _saveData();
  }

  void _editTodo(int index) {
    final editController = TextEditingController(text: _todos[index].title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Task title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                setState(() {
                  _todos[index].title = editController.text.trim();
                });
                _saveData();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
    });
    _saveData();
  }

  void _restoreFromHistory(int index) {
    setState(() {
      final item = _history.removeAt(index);
      item.isCompleted = false;
      item.completedAt = null;
      item.deletedAt = null;
      _todos.add(item);
    });
    _saveData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My To-Do List'),
        elevation: 2,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.check_circle, size: 48, color: Theme.of(context).colorScheme.onPrimary),
                  const SizedBox(height: 8),
                  Text('To-Do App', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Active Tasks'),
              trailing: Text('${_todos.where((t) => !t.isCompleted).length}'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('Completed'),
              trailing: Text('${_todos.where((t) => t.isCompleted).length}'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              trailing: Text('${_history.length}'),
              onTap: () {
                Navigator.pop(context);
                _showHistoryScreen();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _showSettingsScreen();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'To-Do App',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.check_circle, size: 48, color: Colors.blue),
                  children: [const Text('A simple to-do list app with persistence and history tracking.')],
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Add a new task...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTodo,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: _todos.isEmpty
                ? const Center(
                    child: Text(
                      'No tasks yet!\nAdd one above to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: todo.isCompleted,
                            onChanged: (_) => _toggleTodo(index),
                          ),
                          title: Text(
                            todo.title,
                            style: TextStyle(
                              decoration: todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: todo.isCompleted ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Text(
                            'Created: ${_formatDate(todo.createdAt)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editTodo(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTodo(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setStateHistory) => Scaffold(
            appBar: AppBar(
              title: const Text('History'),
              actions: [
                if (_history.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: 'Clear all history',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear History'),
                          content: const Text('Are you sure you want to clear all history?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _clearHistory();
                                Navigator.pop(ctx);
                                Navigator.pop(context);
                              },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
            body: _history.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No history yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.history, color: Colors.grey),
                          title: Text(item.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Created: ${_formatDate(item.createdAt)}'),
                              if (item.deletedAt != null)
                                Text('Deleted: ${_formatDate(item.deletedAt!)}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.restore, color: Colors.green),
                            tooltip: 'Restore task',
                            onPressed: () {
                              _restoreFromHistory(index);
                              setStateHistory(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Task restored!')),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  void _showSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setStateSettings) => Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: ListView(
              children: [
                ListTile(
                  title: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ),
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Theme'),
                  subtitle: Text(_getThemeModeText(TodoApp.of(context)?.themeMode ?? ThemeMode.system)),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        tooltip: 'Light',
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        tooltip: 'System',
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        tooltip: 'Dark',
                      ),
                    ],
                    selected: {TodoApp.of(context)?.themeMode ?? ThemeMode.system},
                    onSelectionChanged: (Set<ThemeMode> selection) {
                      TodoApp.of(context)?.setThemeMode(selection.first);
                      setStateSettings(() {});
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  title: Text('Data Management', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Clear Completed Tasks'),
                subtitle: const Text('Move all completed tasks to history'),
                onTap: () {
                  final completed = _todos.where((t) => t.isCompleted).toList();
                  if (completed.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No completed tasks to clear')),
                    );
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear Completed'),
                      content: Text('Move ${completed.length} completed task(s) to history?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              for (var item in completed) {
                                item.deletedAt = DateTime.now();
                                _history.add(item);
                              }
                              _todos.removeWhere((t) => t.isCompleted);
                            });
                            _saveData();
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${completed.length} task(s) moved to history')),
                            );
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Clear All Tasks'),
                subtitle: const Text('Move all tasks to history'),
                onTap: () {
                  if (_todos.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No tasks to clear')),
                    );
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear All Tasks'),
                      content: Text('Move all ${_todos.length} task(s) to history?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            setState(() {
                              for (var item in _todos) {
                                item.deletedAt = DateTime.now();
                              }
                              _history.addAll(_todos);
                              _todos.clear();
                            });
                            _saveData();
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.orange),
                title: const Text('Clear History'),
                subtitle: const Text('Permanently delete all history'),
                onTap: () {
                  if (_history.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History is already empty')),
                    );
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear History'),
                      content: const Text('This action cannot be undone. Are you sure?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            _clearHistory();
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('History cleared')),
                            );
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.dark:
        return 'Dark mode';
      case ThemeMode.system:
        return 'System default';
    }
  }
}

class TodoItem {
  String id;
  String title;
  bool isCompleted;
  DateTime createdAt;
  DateTime? completedAt;
  DateTime? deletedAt;

  TodoItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
    this.completedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'],
        title: json['title'],
        isCompleted: json['isCompleted'],
        createdAt: DateTime.parse(json['createdAt']),
        completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
        deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt']) : null,
      );
}