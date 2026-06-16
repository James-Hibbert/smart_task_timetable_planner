import '../database/database_helper.dart';

class ModuleRepository {
  final DatabaseHelper dbHelper;

  ModuleRepository({required this.dbHelper});

  Future<int> insertModule({
    required int userId,
    required Map<String, dynamic> module,
  }) async {
    final safeModule = Map<String, dynamic>.from(module);
    safeModule['userId'] = userId;

    return await dbHelper.insertModule(safeModule);
  }

  Future<List<Map<String, dynamic>>> getModules({
    required int userId,
  }) async {
    final results = await dbHelper.getModules(userId: userId);

    return results
        .map((module) => Map<String, dynamic>.from(module))
        .toList(growable: false);
  }

  Future<int> updateModule({
    required int userId,
    required Map<String, dynamic> module,
  }) async {
    final safeModule = Map<String, dynamic>.from(module);
    safeModule['userId'] = userId;

    return await dbHelper.updateModule(safeModule);
  }

  Future<int> deleteModule({
    required int userId,
    required int id,
  }) async {
    return await dbHelper.deleteModule(id: id, userId: userId);
  }
}