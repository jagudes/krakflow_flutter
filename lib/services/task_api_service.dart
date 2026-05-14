import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/task.dart';

class TaskApiService {
  static const String baseUrl =
      'https://dummyjson.com/todos';

  static Future<List<Task>> fetchTasks() async {
    final response = await http.get(
      Uri.parse(baseUrl),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final List todosJson = data['todos'];

      final random = Random();

      final priorities = [
        "niski",
        "średni",
        "wysoki",
      ];

      return todosJson.map((json) {
        final randomPriority =
        priorities[random.nextInt(
          priorities.length,
        )];

        final randomDay =
            random.nextInt(28) + 1;

        final randomDeadline =
            "$randomDay.05.2026";

        return Task(
          id: json['id'],
          title: json['todo'],
          done: json['completed'],
          priority: randomPriority,
          deadline: randomDeadline,
        );
      }).toList();
    } else {
      throw Exception(
        'Nie udało się pobrać zadań',
      );
    }
  }
}