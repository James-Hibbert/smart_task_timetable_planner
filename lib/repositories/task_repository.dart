import '../database/database_helper.dart';

class TaskRepository {
  final DatabaseHelper dbHelper;

  TaskRepository({required this.dbHelper});

  Future<int> insertTask({
    required int userId,
    required Map<String, dynamic> task,
  }) async {
    final safeTask = Map<String, dynamic>.from(task);
    safeTask['userId'] = userId;

    return await dbHelper.insertTask(safeTask);
  }

  Future<List<Map<String, dynamic>>> getTasks({
    required int userId,
  }) async {
    final results = await dbHelper.getTasks(userId: userId);

    return results
        .map((task) => Map<String, dynamic>.from(task))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getTasksWithModules({
    required int userId,
  }) async {
    final results = await dbHelper.getTasksWithModules(userId: userId);

    return results
        .map((task) => Map<String, dynamic>.from(task))
        .toList(growable: false);
  }

  Future<int> updateTask({
    required int userId,
    required Map<String, dynamic> task,
  }) async {
    final safeTask = Map<String, dynamic>.from(task);
    safeTask['userId'] = userId;

    return await dbHelper.updateTask(safeTask);
  }

  Future<int> deleteTask({
    required int userId,
    required int id,
  }) async {
    return await dbHelper.deleteTask(id: id, userId: userId);
  }
}