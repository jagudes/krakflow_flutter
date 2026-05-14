import 'package:flutter/material.dart';
import 'models/task.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'services/task_api_service.dart';
import 'services/task_local_database.dart';
import 'services/task_sync_service.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox("tasks");
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista zadań',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}


class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}



class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController deadlineController = TextEditingController();
  final TextEditingController priorityController = TextEditingController();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nowe zadanie"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [TextField(controller: titleController, decoration: const InputDecoration(labelText: "Tytuł")),
            TextField(controller: deadlineController, decoration: const InputDecoration(labelText: "Termin")),
            TextField(controller: priorityController, decoration: const InputDecoration(labelText: "Priorytet")),

            ElevatedButton(
              onPressed: () {
                Navigator.pop( context,
                  Task(
                    id: Random().nextInt(1000000),
                    title: titleController.text,
                    priority: priorityController.text,
                    deadline: deadlineController.text,
                    done: false,
                  ),
                );
              },
              child: const Text("Zapisz"),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {

  const HomeScreen({
    super.key,});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedFilter = 'wszystkie';

  @override
  void initState() {
    super.initState();
  }


  void _showDeleteAllDialog() {
    if (TaskLocalDatabase.getTasks().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lista jest już pusta")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Potwierdzenie"),
            content: const Text(
                "Czy na pewno chcesz usunąć wszystkie zadania?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Anuluj"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    TaskLocalDatabase.getTasks().clear();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usunięto wszystkie zadania')),
                  );
                },
                child: const Text("Usuń", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Moje zadania"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _showDeleteAllDialog
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Masz dziś ${TaskLocalDatabase.getTasks().length} zadania"),
            ),
            const SizedBox(height: 8),
            FilterBar(
              onFilterChanged: (value) {
                setState(() => selectedFilter = value);
              },
            ),
          Expanded(
            child: TaskListScreen(selectedFilter: selectedFilter,),
          ),
    ],
        ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Task? newTask =  await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTaskScreen(),
            ),
          );
          if (newTask != null) {
            await TaskLocalDatabase.addTask(newTask);
            setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  final String selectedFilter;

  const TaskListScreen({
    super.key,
    required this.selectedFilter,});
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<Task>> tasksFuture;
  @override
  void initState() {
    super.initState();
    tasksFuture = loadTasks();
  }
  Future<List<Task>> loadTasks() async {
    await TaskSyncService.loadInitialDataIfNeeded();

    return TaskLocalDatabase.getTasks();
  }
  @override
  Widget build(BuildContext context) {
    List<Task> filteredTasks = TaskRepository.tasks;
    if (TaskRepository.selectedFilter == "wykonane") {
      filteredTasks = TaskRepository.tasks.where((t) => t.done).toList();
    } else if (TaskRepository.selectedFilter == "do zrobienia") {
      filteredTasks = TaskRepository.tasks.where((t) => !t.done).toList();
    }

    return FutureBuilder<List<Task>>(
      future: tasksFuture,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = filteredTasks[index];
            return Dismissible(
              key: ObjectKey(task),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) {
                  TaskLocalDatabase.deleteTask(task.id);
                  setState(() {
                    tasksFuture = loadTasks();
                  });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Usunięto: ${task.title}")),
                );
              },
              child: TaskCard(
                title: task.title,
                subtitle: "Termin: ${task.deadline} | Priorytet: ${task.priority}",
                done: task.done,
                onChanged: (value) async {
                  final updatedTask = Task(
                    id: task.id,
                    title: task.title,
                    deadline: task.deadline,
                    priority: task.priority,
                    done: value ?? false,
                  );

                  await TaskLocalDatabase.updateTask(updatedTask);

                  setState(() {
                    tasksFuture = loadTasks();
                  });
                },
                onTap: () async {
                  final Task? updatedTask = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditTaskScreen(task: task),
                    ),
                  );
                  if (updatedTask != null) {
                    setState(() {
                      int originalIndex = TaskLocalDatabase.getTasks().indexOf(task);
                      TaskRepository.tasks[originalIndex] = updatedTask;
                    });
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class FilterBar extends StatelessWidget {
  final Function(String) onFilterChanged;

  const FilterBar({
    super.key,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _filterButton('wszystkie', 'Wszystkie'),
        _filterButton('do zrobienia', 'Do zrobienia'),
        _filterButton('wykonane', 'Wykonane'),
      ],
    );
  }

  Widget _filterButton(String value, String label) {
    return TextButton(
      onPressed: () => onFilterChanged(value),
      child: Text(
        label,
        style: TextStyle(
          color: TaskRepository.selectedFilter == value ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.done,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Checkbox(
          value: done,
          onChanged: onChanged,
        ),
        title: Text(
          title,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
            color: done ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}


class EditTaskScreen extends StatefulWidget {
  final Task task;
  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final titleController = TextEditingController();
  final deadlineController = TextEditingController();
  final priorityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    titleController.text = widget.task.title;
    deadlineController.text = widget.task.deadline;
    priorityController.text = widget.task.priority;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edytuj zadanie")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Tytuł zadania")),
            TextField(controller: deadlineController, decoration: const InputDecoration(labelText: "Termin")),
            TextField(controller: priorityController, decoration: const InputDecoration(labelText: "Priorytet")),
            ElevatedButton(
              onPressed: () {
                final updatedTask = Task(
                  title: titleController.text,
                  deadline: deadlineController.text,
                  priority: priorityController.text,
                  done: widget.task.done,
                );
                Navigator.pop(context, updatedTask);
              },
              child: const Text("Zapisz zmiany"),
            ),
          ],
        ),
      ),
    );
  }
}
