class Task {
  final String title;
  final String deadline;
  final bool done;

  Task({required this.title, required this.deadline, this.done= false});
}

class TaskRepository {
  static List<Task> tasks = [
    Task(title: "nauczyć się na kolokwium", deadline: "29.03.2026"),
    Task(title: "zrobić zakupy", deadline: "30.03.2026"),
    Task(title: "zrobić zadanie z angielskiego", deadline: "29.03.2026"),
    Task(title: "zrobić zadanie z sieci", deadline: "03.04.2026"),
  ];
}
