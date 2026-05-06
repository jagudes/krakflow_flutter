class Task {
  final String title;
  final String deadline;
  final String priority;
  final bool done;

  Task({required this.title, required this.deadline, required this.priority ,this.done= false});
}

class TaskRepository {
  static List<Task> tasks = [
    Task(title: "nauczyć się na kolokwium",priority: "wysoki", deadline: "29.03.2026"),
    Task(title: "zrobić zakupy",priority: "niski", deadline: "30.03.2026"),
    Task(title: "zrobić zadanie z angielskiego",priority: "niski", deadline: "29.03.2026"),
    Task(title: "zrobić zadanie z sieci",priority: "średni", deadline: "03.04.2026"),
  ];
}
