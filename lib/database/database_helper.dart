import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const String _manualSessionType = 'manual';
  static const String _generatedSessionType = 'generated';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('planner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        firebaseUid TEXT,
        passwordHash TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        moduleId INTEGER NOT NULL,
        deadline TEXT NOT NULL,
        estimatedHours INTEGER NOT NULL,
        priority TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (moduleId) REFERENCES modules (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        moduleId INTEGER NOT NULL,
        title TEXT,
        date TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        room TEXT NOT NULL,
        sessionType TEXT NOT NULL DEFAULT 'manual',
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurrencePattern TEXT NOT NULL DEFAULT 'none',
        recurrenceDays TEXT,
        recurrenceEndDate TEXT,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (moduleId) REFERENCES modules (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE planner_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        type TEXT NOT NULL,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurrencePattern TEXT NOT NULL DEFAULT 'none',
        recurrenceDays TEXT,
        recurrenceEndDate TEXT,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_firebaseUid ON users(firebaseUid)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_modules_userId_name ON modules(userId, name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_userId_deadline ON tasks(userId, deadline)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_moduleId ON tasks(moduleId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_userId_date_start ON sessions(userId, date, startTime)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_moduleId ON sessions(moduleId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_room ON sessions(room)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_sessionType ON sessions(sessionType)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_isRecurring ON sessions(isRecurring)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_recurrencePattern ON sessions(recurrencePattern)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_planner_events_userId_date_start ON planner_events(userId, date, startTime)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_planner_events_isRecurring ON planner_events(isRecurring)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_planner_events_recurrencePattern ON planner_events(recurrencePattern)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS tasks');

      await db.execute('''
        CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          moduleId INTEGER NOT NULL,
          deadline TEXT NOT NULL,
          estimatedHours INTEGER NOT NULL,
          priority TEXT NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (moduleId) REFERENCES modules (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          moduleId INTEGER NOT NULL,
          title TEXT,
          date TEXT NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          room TEXT NOT NULL,
          FOREIGN KEY (moduleId) REFERENCES modules (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      final columns = await db.rawQuery('PRAGMA table_info(sessions)');
      final hasTitle = columns.any((column) => column['name'] == 'title');

      if (!hasTitle) {
        await db.execute('ALTER TABLE sessions ADD COLUMN title TEXT');
      }
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE planner_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          date TEXT NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          type TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      await db.execute('DROP TABLE IF EXISTS sessions');
      await db.execute('DROP TABLE IF EXISTS planner_events');

      await db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          moduleId INTEGER NOT NULL,
          title TEXT,
          date TEXT NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          room TEXT NOT NULL,
          FOREIGN KEY (moduleId) REFERENCES modules (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE planner_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          date TEXT NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          type TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 7) {
      final columns = await db.rawQuery('PRAGMA table_info(sessions)');
      final hasSessionType =
      columns.any((column) => column['name'] == 'sessionType');

      if (!hasSessionType) {
        await db.execute(
          "ALTER TABLE sessions ADD COLUMN sessionType TEXT NOT NULL DEFAULT 'manual'",
        );
      }

      await db.update(
        'sessions',
        {'sessionType': _generatedSessionType},
        where: 'room = ?',
        whereArgs: ['Generated'],
      );

      await db.update(
        'sessions',
        {'sessionType': _manualSessionType},
        where: 'sessionType IS NULL OR TRIM(sessionType) = ?',
        whereArgs: [''],
      );
    }

    if (oldVersion < 8) {
      final columns = await db.rawQuery('PRAGMA table_info(planner_events)');

      final hasIsRecurring =
      columns.any((column) => column['name'] == 'isRecurring');
      final hasRecurrencePattern =
      columns.any((column) => column['name'] == 'recurrencePattern');
      final hasRecurrenceDays =
      columns.any((column) => column['name'] == 'recurrenceDays');
      final hasRecurrenceEndDate =
      columns.any((column) => column['name'] == 'recurrenceEndDate');

      if (!hasIsRecurring) {
        await db.execute(
          "ALTER TABLE planner_events ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 0",
        );
      }

      if (!hasRecurrencePattern) {
        await db.execute(
          "ALTER TABLE planner_events ADD COLUMN recurrencePattern TEXT NOT NULL DEFAULT 'none'",
        );
      }

      if (!hasRecurrenceDays) {
        await db.execute(
          "ALTER TABLE planner_events ADD COLUMN recurrenceDays TEXT",
        );
      }

      if (!hasRecurrenceEndDate) {
        await db.execute(
          "ALTER TABLE planner_events ADD COLUMN recurrenceEndDate TEXT",
        );
      }
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT NOT NULL UNIQUE,
          passwordHash TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 10) {
      await db.execute('PRAGMA foreign_keys = OFF');
      try {
        await _migratePlannerDataToUserSpecific(db);
      } finally {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }

    if (oldVersion < 11) {
      final columns = await db.rawQuery('PRAGMA table_info(sessions)');

      final hasIsRecurring =
      columns.any((column) => column['name'] == 'isRecurring');
      final hasRecurrencePattern =
      columns.any((column) => column['name'] == 'recurrencePattern');
      final hasRecurrenceDays =
      columns.any((column) => column['name'] == 'recurrenceDays');
      final hasRecurrenceEndDate =
      columns.any((column) => column['name'] == 'recurrenceEndDate');

      if (!hasIsRecurring) {
        await db.execute(
          "ALTER TABLE sessions ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 0",
        );
      }

      if (!hasRecurrencePattern) {
        await db.execute(
          "ALTER TABLE sessions ADD COLUMN recurrencePattern TEXT NOT NULL DEFAULT 'none'",
        );
      }

      if (!hasRecurrenceDays) {
        await db.execute(
          "ALTER TABLE sessions ADD COLUMN recurrenceDays TEXT",
        );
      }

      if (!hasRecurrenceEndDate) {
        await db.execute(
          "ALTER TABLE sessions ADD COLUMN recurrenceEndDate TEXT",
        );
      }
    }

    if (oldVersion < 12) {
      final columns = await db.rawQuery('PRAGMA table_info(users)');
      final hasFirebaseUid =
      columns.any((column) => column['name'] == 'firebaseUid');

      if (!hasFirebaseUid) {
        await db.execute('ALTER TABLE users ADD COLUMN firebaseUid TEXT');
      }
    }

    await _createIndexes(db);
  }

  Future<void> _migratePlannerDataToUserSpecific(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT NOT NULL UNIQUE,
          passwordHash TEXT NOT NULL
        )
      ''');

      final defaultUser = await txn.query(
        'users',
        where: 'email = ?',
        whereArgs: ['local@smartplanner.app'],
        limit: 1,
      );

      int defaultUserId;
      if (defaultUser.isEmpty) {
        defaultUserId = await txn.insert(
          'users',
          {
            'email': 'local@smartplanner.app',
            'passwordHash': 'migrated_local_user',
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        if (defaultUserId == 0) {
          final retry = await txn.query(
            'users',
            where: 'email = ?',
            whereArgs: ['local@smartplanner.app'],
            limit: 1,
          );
          defaultUserId = retry.first['id'] as int;
        }
      } else {
        defaultUserId = defaultUser.first['id'] as int;
      }

      await _rebuildPlannerEventsTable(txn, defaultUserId);
      await _rebuildTasksTable(txn, defaultUserId);
      await _rebuildSessionsTable(txn, defaultUserId);
      await _rebuildModulesTable(txn, defaultUserId);
    });
  }

  Future<void> _rebuildModulesTable(Transaction txn, int defaultUserId) async {
    final columns = await txn.rawQuery('PRAGMA table_info(modules)');
    final hasUserId = columns.any((column) => column['name'] == 'userId');
    if (hasUserId) return;

    await txn.execute('ALTER TABLE modules RENAME TO modules_old');

    await txn.execute('''
      CREATE TABLE modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await txn.execute('''
      INSERT INTO modules (id, userId, name, code)
      SELECT id, ?, name, code
      FROM modules_old
    ''', [defaultUserId]);

    await txn.execute('DROP TABLE modules_old');
  }

  Future<void> _rebuildTasksTable(Transaction txn, int defaultUserId) async {
    final columns = await txn.rawQuery('PRAGMA table_info(tasks)');
    final hasUserId = columns.any((column) => column['name'] == 'userId');
    if (hasUserId) return;

    await txn.execute('ALTER TABLE tasks RENAME TO tasks_old');

    await txn.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        moduleId INTEGER NOT NULL,
        deadline TEXT NOT NULL,
        estimatedHours INTEGER NOT NULL,
        priority TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (moduleId) REFERENCES modules (id) ON DELETE CASCADE
      )
    ''');

    await txn.execute('''
      INSERT INTO tasks (id, userId, title, moduleId, deadline, estimatedHours, priority, isCompleted)
      SELECT id, ?, title, moduleId, deadline, estimatedHours, priority, isCompleted
      FROM tasks_old
    ''', [defaultUserId]);

    await txn.execute('DROP TABLE tasks_old');
  }

  Future<void> _rebuildSessionsTable(Transaction txn, int defaultUserId) async {
    final columns = await txn.rawQuery('PRAGMA table_info(sessions)');
    final hasUserId = columns.any((column) => column['name'] == 'userId');
    if (hasUserId) return;

    await txn.execute('ALTER TABLE sessions RENAME TO sessions_old');

    await txn.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        moduleId INTEGER NOT NULL,
        title TEXT,
        date TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        room TEXT NOT NULL,
        sessionType TEXT NOT NULL DEFAULT 'manual',
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurrencePattern TEXT NOT NULL DEFAULT 'none',
        recurrenceDays TEXT,
        recurrenceEndDate TEXT,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (moduleId) REFERENCES modules (id) ON DELETE CASCADE
      )
    ''');

    final oldHasSessionType =
    columns.any((column) => column['name'] == 'sessionType');
    final oldHasIsRecurring =
    columns.any((column) => column['name'] == 'isRecurring');
    final oldHasRecurrencePattern =
    columns.any((column) => column['name'] == 'recurrencePattern');
    final oldHasRecurrenceDays =
    columns.any((column) => column['name'] == 'recurrenceDays');
    final oldHasRecurrenceEndDate =
    columns.any((column) => column['name'] == 'recurrenceEndDate');

    await txn.execute('''
      INSERT INTO sessions (
        id, userId, moduleId, title, date, startTime, endTime, room,
        sessionType, isRecurring, recurrencePattern, recurrenceDays, recurrenceEndDate
      )
      SELECT
        id,
        ?,
        moduleId,
        title,
        date,
        startTime,
        endTime,
        room,
        ${oldHasSessionType ? 'sessionType' : "'manual'"},
        ${oldHasIsRecurring ? 'isRecurring' : '0'},
        ${oldHasRecurrencePattern ? 'recurrencePattern' : "'none'"},
        ${oldHasRecurrenceDays ? 'recurrenceDays' : "NULL"},
        ${oldHasRecurrenceEndDate ? 'recurrenceEndDate' : "NULL"}
      FROM sessions_old
    ''', [defaultUserId]);

    await txn.execute('DROP TABLE sessions_old');
  }

  Future<void> _rebuildPlannerEventsTable(
      Transaction txn,
      int defaultUserId,
      ) async {
    final columns = await txn.rawQuery('PRAGMA table_info(planner_events)');
    final hasUserId = columns.any((column) => column['name'] == 'userId');
    if (hasUserId) return;

    await txn.execute('ALTER TABLE planner_events RENAME TO planner_events_old');

    await txn.execute('''
      CREATE TABLE planner_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        type TEXT NOT NULL,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurrencePattern TEXT NOT NULL DEFAULT 'none',
        recurrenceDays TEXT,
        recurrenceEndDate TEXT,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await txn.execute('''
      INSERT INTO planner_events (
        id, userId, title, date, startTime, endTime, type,
        isRecurring, recurrencePattern, recurrenceDays, recurrenceEndDate
      )
      SELECT
        id, ?, title, date, startTime, endTime, type,
        isRecurring, recurrencePattern, recurrenceDays, recurrenceEndDate
      FROM planner_events_old
    ''', [defaultUserId]);

    await txn.execute('DROP TABLE planner_events_old');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    return await db.insert(
      'users',
      _sanitiseUser(user, includeId: false),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Map<String, dynamic>.from(results.first);
  }

  Future<Map<String, dynamic>?> getUserByFirebaseUid(String firebaseUid) async {
    final db = await instance.database;
    final safeFirebaseUid = firebaseUid.trim();

    if (safeFirebaseUid.isEmpty) return null;

    final results = await db.query(
      'users',
      where: 'firebaseUid = ?',
      whereArgs: [safeFirebaseUid],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Map<String, dynamic>.from(results.first);
  }

  Future<int> updateUserFirebaseUid({
    required int userId,
    required String firebaseUid,
  }) async {
    final db = await instance.database;
    final safeFirebaseUid = firebaseUid.trim();

    if (safeFirebaseUid.isEmpty) {
      throw ArgumentError('firebaseUid cannot be empty.');
    }

    return await db.update(
      'users',
      {
        'firebaseUid': safeFirebaseUid,
      },
      where: 'id = ?',
      whereArgs: [userId],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Map<String, dynamic>.from(results.first);
  }

  Future<int> insertModule(Map<String, dynamic> module) async {
    final db = await instance.database;
    return await db.insert(
      'modules',
      _sanitiseModule(module, includeId: false),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> getModules({
    required int userId,
  }) async {
    final db = await instance.database;
    return await db.query(
      'modules',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
  }

  Future<int> updateModule(Map<String, dynamic> module) async {
    final db = await instance.database;
    final safeModule = _sanitiseModule(module, includeId: true);

    if (safeModule['id'] == null) {
      throw ArgumentError('Cannot update module without an id.');
    }

    return await db.update(
      'modules',
      {
        'name': safeModule['name'],
        'code': safeModule['code'],
      },
      where: 'id = ? AND userId = ?',
      whereArgs: [safeModule['id'], safeModule['userId']],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> deleteModule({
    required int id,
    required int userId,
  }) async {
    final db = await instance.database;
    return await db.delete(
      'modules',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<int> insertTask(Map<String, dynamic> task) async {
    final db = await instance.database;
    return await db.insert(
      'tasks',
      _sanitiseTask(task, includeId: false),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> getTasks({
    required int userId,
  }) async {
    final db = await instance.database;
    return await db.query(
      'tasks',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'deadline ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getTasksWithModules({
    required int userId,
  }) async {
    final db = await instance.database;

    return await db.rawQuery('''
      SELECT 
        tasks.id,
        tasks.userId,
        tasks.title,
        tasks.moduleId,
        tasks.deadline,
        tasks.estimatedHours,
        tasks.priority,
        tasks.isCompleted,
        modules.name AS moduleName,
        modules.code AS moduleCode
      FROM tasks
      INNER JOIN modules ON tasks.moduleId = modules.id
      WHERE tasks.userId = ? AND modules.userId = ?
      ORDER BY tasks.deadline ASC
    ''', [userId, userId]);
  }

  Future<int> updateTask(Map<String, dynamic> task) async {
    final db = await instance.database;
    final safeTask = _sanitiseTask(task, includeId: true);

    return await db.update(
      'tasks',
      safeTask,
      where: 'id = ? AND userId = ?',
      whereArgs: [safeTask['id'], safeTask['userId']],
    );
  }

  Future<int> deleteTask({
    required int id,
    required int userId,
  }) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<int> insertSession(Map<String, dynamic> session) async {
    final db = await instance.database;
    return await db.insert(
      'sessions',
      _sanitiseSession(session, includeId: false),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> getSessionsWithModules({
    required int userId,
  }) async {
    final db = await instance.database;

    return await db.rawQuery('''
      SELECT
        sessions.id,
        sessions.userId,
        sessions.moduleId,
        sessions.title AS title,
        sessions.date,
        sessions.startTime,
        sessions.endTime,
        sessions.room,
        sessions.sessionType,
        sessions.isRecurring,
        sessions.recurrencePattern,
        sessions.recurrenceDays,
        sessions.recurrenceEndDate,
        modules.name AS moduleName,
        modules.code AS moduleCode
      FROM sessions
      INNER JOIN modules ON sessions.moduleId = modules.id
      WHERE sessions.userId = ? AND modules.userId = ?
      ORDER BY sessions.date ASC, sessions.startTime ASC
    ''', [userId, userId]);
  }

  Future<List<Map<String, dynamic>>> getBlockingSessionsWithModules({
    required int userId,
  }) async {
    final db = await instance.database;

    return await db.rawQuery('''
      SELECT
        sessions.id,
        sessions.userId,
        sessions.moduleId,
        sessions.title AS title,
        sessions.date,
        sessions.startTime,
        sessions.endTime,
        sessions.room,
        sessions.sessionType,
        sessions.isRecurring,
        sessions.recurrencePattern,
        sessions.recurrenceDays,
        sessions.recurrenceEndDate,
        modules.name AS moduleName,
        modules.code AS moduleCode
      FROM sessions
      INNER JOIN modules ON sessions.moduleId = modules.id
      WHERE sessions.userId = ? AND modules.userId = ? AND sessions.sessionType = ?
      ORDER BY sessions.date ASC, sessions.startTime ASC
    ''', [userId, userId, _manualSessionType]);
  }

  Future<List<Map<String, dynamic>>> getSessionsWithModulesForDateRange({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    final db = await instance.database;

    return await db.rawQuery('''
      SELECT
        sessions.id,
        sessions.userId,
        sessions.moduleId,
        sessions.title AS title,
        sessions.date,
        sessions.startTime,
        sessions.endTime,
        sessions.room,
        sessions.sessionType,
        sessions.isRecurring,
        sessions.recurrencePattern,
        sessions.recurrenceDays,
        sessions.recurrenceEndDate,
        modules.name AS moduleName,
        modules.code AS moduleCode
      FROM sessions
      INNER JOIN modules ON sessions.moduleId = modules.id
      WHERE sessions.userId = ? AND modules.userId = ?
        AND sessions.date >= ? AND sessions.date <= ?
      ORDER BY sessions.date ASC, sessions.startTime ASC
    ''', [userId, userId, startDate, endDate]);
  }

  Future<int> updateSession(Map<String, dynamic> session) async {
    final db = await instance.database;
    final safeSession = _sanitiseSession(session, includeId: true);

    return await db.update(
      'sessions',
      safeSession,
      where: 'id = ? AND userId = ?',
      whereArgs: [safeSession['id'], safeSession['userId']],
    );
  }

  Future<int> deleteSession({
    required int id,
    required int userId,
  }) async {
    final db = await instance.database;
    return await db.delete(
      'sessions',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<void> replaceGeneratedSessions({
    required int userId,
    required List<Map<String, dynamic>> generatedSessions,
  }) async {
    final db = await instance.database;
    final safeGeneratedSessions = _normaliseGeneratedSessions(generatedSessions);

    await db.transaction((txn) async {
      await txn.delete(
        'sessions',
        where: 'userId = ? AND sessionType = ?',
        whereArgs: [userId, _generatedSessionType],
      );

      for (final generated in safeGeneratedSessions) {
        final moduleId = _toInt(generated['moduleId']);
        final title = (generated['title'] ?? '').toString().trim();
        final date = (generated['date'] ?? '').toString().trim();
        final startTime = (generated['startTime'] ?? '').toString().trim();
        final endTime = (generated['endTime'] ?? '').toString().trim();

        if (moduleId <= 0 ||
            title.isEmpty ||
            date.isEmpty ||
            startTime.isEmpty ||
            endTime.isEmpty) {
          continue;
        }

        if (!_isValidIsoDate(date) ||
            !_isValidTime(startTime) ||
            !_isValidTime(endTime) ||
            !_isEndTimeAfterStartTime(startTime, endTime)) {
          continue;
        }

        await txn.insert(
          'sessions',
          {
            'userId': userId,
            'moduleId': moduleId,
            'title': title,
            'date': date,
            'startTime': startTime,
            'endTime': endTime,
            'room': 'Generated',
            'sessionType': _generatedSessionType,
            'isRecurring': 0,
            'recurrencePattern': 'none',
            'recurrenceDays': '',
            'recurrenceEndDate': null,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  Future<int> insertPlannerEvent(Map<String, dynamic> event) async {
    final db = await instance.database;
    return await db.insert(
      'planner_events',
      _sanitisePlannerEvent(event, includeId: false),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> getPlannerEvents({
    required int userId,
  }) async {
    final db = await instance.database;
    return await db.query(
      'planner_events',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date ASC, startTime ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getPlannerEventsForDateRange({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    final db = await instance.database;
    return await db.query(
      'planner_events',
      where: 'userId = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, startDate, endDate],
      orderBy: 'date ASC, startTime ASC',
    );
  }

  Future<int> updatePlannerEvent(Map<String, dynamic> event) async {
    final db = await instance.database;
    final safeEvent = _sanitisePlannerEvent(event, includeId: true);

    return await db.update(
      'planner_events',
      safeEvent,
      where: 'id = ? AND userId = ?',
      whereArgs: [safeEvent['id'], safeEvent['userId']],
    );
  }

  Future<int> deletePlannerEvent({
    required int id,
    required int userId,
  }) async {
    final db = await instance.database;
    return await db.delete(
      'planner_events',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Map<String, dynamic> _sanitiseUser(
      Map<String, dynamic> user, {
        required bool includeId,
      }) {
    final firebaseUid = (user['firebaseUid'] ?? '').toString().trim();

    return {
      if (includeId && user['id'] != null) 'id': user['id'],
      'email': (user['email'] ?? '').toString().trim().toLowerCase(),
      'firebaseUid': firebaseUid.isEmpty ? null : firebaseUid,
      'passwordHash': (user['passwordHash'] ?? '').toString().trim(),
    };
  }

  Map<String, dynamic> _sanitiseModule(
      Map<String, dynamic> module, {
        required bool includeId,
      }) {
    return {
      if (includeId && module['id'] != null) 'id': module['id'],
      'userId': _toInt(module['userId']),
      'name': (module['name'] ?? '').toString().trim(),
      'code': (module['code'] ?? '').toString().trim(),
    };
  }

  Map<String, dynamic> _sanitiseTask(
      Map<String, dynamic> task, {
        required bool includeId,
      }) {
    return {
      if (includeId && task['id'] != null) 'id': task['id'],
      'userId': _toInt(task['userId']),
      'title': (task['title'] ?? '').toString().trim(),
      'moduleId': _toInt(task['moduleId']),
      'deadline': (task['deadline'] ?? '').toString().trim(),
      'estimatedHours': _toInt(task['estimatedHours']),
      'priority': (task['priority'] ?? '').toString().trim(),
      'isCompleted': _toBoolInt(task['isCompleted']),
    };
  }

  Map<String, dynamic> _sanitiseSession(
      Map<String, dynamic> session, {
        required bool includeId,
      }) {
    final rawSessionType = (session['sessionType'] ?? '').toString().trim();
    final sessionType = rawSessionType.isEmpty
        ? _inferSessionTypeFromRoom(session['room'])
        : rawSessionType;

    final recurrencePattern =
    (session['recurrencePattern'] ?? 'none').toString().trim();
    final recurrenceDays = (session['recurrenceDays'] ?? '').toString().trim();
    final recurrenceEndDate =
    (session['recurrenceEndDate'] ?? '').toString().trim();

    return {
      if (includeId && session['id'] != null) 'id': session['id'],
      'userId': _toInt(session['userId']),
      'moduleId': _toInt(session['moduleId']),
      'title': (session['title'] ?? '').toString().trim(),
      'date': (session['date'] ?? '').toString().trim(),
      'startTime': (session['startTime'] ?? '').toString().trim(),
      'endTime': (session['endTime'] ?? '').toString().trim(),
      'room': (session['room'] ?? '').toString().trim(),
      'sessionType': sessionType,
      'isRecurring': _toBoolInt(session['isRecurring']),
      'recurrencePattern':
      recurrencePattern.isEmpty ? 'none' : recurrencePattern,
      'recurrenceDays': recurrenceDays,
      'recurrenceEndDate':
      recurrenceEndDate.isEmpty ? null : recurrenceEndDate,
    };
  }

  Map<String, dynamic> _sanitisePlannerEvent(
      Map<String, dynamic> event, {
        required bool includeId,
      }) {
    final recurrencePattern =
    (event['recurrencePattern'] ?? 'none').toString().trim();
    final recurrenceDays = (event['recurrenceDays'] ?? '').toString().trim();
    final recurrenceEndDate =
    (event['recurrenceEndDate'] ?? '').toString().trim();

    return {
      if (includeId && event['id'] != null) 'id': event['id'],
      'userId': _toInt(event['userId']),
      'title': (event['title'] ?? '').toString().trim(),
      'date': (event['date'] ?? '').toString().trim(),
      'startTime': (event['startTime'] ?? '').toString().trim(),
      'endTime': (event['endTime'] ?? '').toString().trim(),
      'type': (event['type'] ?? '').toString().trim(),
      'isRecurring': _toBoolInt(event['isRecurring']),
      'recurrencePattern':
      recurrencePattern.isEmpty ? 'none' : recurrencePattern,
      'recurrenceDays': recurrenceDays,
      'recurrenceEndDate':
      recurrenceEndDate.isEmpty ? null : recurrenceEndDate,
    };
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  int _toBoolInt(dynamic value) {
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value == 1 ? 1 : 0;
    if (value is num) return value.toInt() == 1 ? 1 : 0;

    final text = (value ?? '').toString().toLowerCase().trim();
    if (text == 'true' || text == '1') return 1;
    return 0;
  }

  String _inferSessionTypeFromRoom(dynamic room) {
    final roomText = (room ?? '').toString().trim().toLowerCase();
    if (roomText == 'generated') {
      return _generatedSessionType;
    }
    return _manualSessionType;
  }

  List<Map<String, dynamic>> _normaliseGeneratedSessions(
      List<Map<String, dynamic>> generatedSessions,
      ) {
    final sessions = generatedSessions
        .map((session) => <String, dynamic>{
      'moduleId': _toInt(session['moduleId']),
      'title': (session['title'] ?? '').toString().trim(),
      'date': (session['date'] ?? '').toString().trim(),
      'startTime': (session['startTime'] ?? '').toString().trim(),
      'endTime': (session['endTime'] ?? '').toString().trim(),
    })
        .toList();

    sessions.sort((a, b) {
      final dateCompare =
      (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString());
      if (dateCompare != 0) return dateCompare;

      final startCompare = (a['startTime'] ?? '')
          .toString()
          .compareTo((b['startTime'] ?? '').toString());
      if (startCompare != 0) return startCompare;

      return (a['title'] ?? '')
          .toString()
          .compareTo((b['title'] ?? '').toString());
    });

    return sessions;
  }

  bool _isValidIsoDate(String value) {
    try {
      final parsed = DateTime.parse(value);
      final year = parsed.year.toString().padLeft(4, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      return '$year-$month-$day' == value;
    } catch (_) {
      return false;
    }
  }

  bool _isValidTime(String value) {
    final match = RegExp(r'^\d{2}:\d{2}$').firstMatch(value);
    if (match == null) return false;

    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return false;
    if (hour < 0 || hour > 23) return false;
    if (minute < 0 || minute > 59) return false;

    return true;
  }

  bool _isEndTimeAfterStartTime(String startTime, String endTime) {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    final startMinutes =
        (int.parse(startParts[0]) * 60) + int.parse(startParts[1]);
    final endMinutes =
        (int.parse(endParts[0]) * 60) + int.parse(endParts[1]);

    return endMinutes > startMinutes;
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}