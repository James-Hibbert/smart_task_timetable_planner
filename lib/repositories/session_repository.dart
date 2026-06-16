import '../database/database_helper.dart';

class SessionRepository {
  final DatabaseHelper dbHelper;

  SessionRepository({required this.dbHelper});

  Future<int> insertSession({
    required int userId,
    required Map<String, dynamic> session,
  }) async {
    final safeSession = Map<String, dynamic>.from(session);
    safeSession.putIfAbsent('sessionType', () => 'manual');
    safeSession['userId'] = userId;

    return await dbHelper.insertSession(safeSession);
  }

  Future<List<Map<String, dynamic>>> getSessionsWithModules({
    required int userId,
  }) async {
    final rawResults = await dbHelper.getSessionsWithModules(userId: userId);

    final today = _dateOnly(DateTime.now());
    final endDate = today.add(const Duration(days: 89));

    final expanded = _expandSessionsForDateRange(
      rawSessions: rawResults,
      startDate: _toIsoDate(today),
      endDate: _toIsoDate(endDate),
    );

    return expanded
        .map((session) => Map<String, dynamic>.from(session))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getBlockingSessionsWithModules({
    required int userId,
  }) async {
    final rawResults =
    await dbHelper.getBlockingSessionsWithModules(userId: userId);

    final today = _dateOnly(DateTime.now());
    final endDate = today.add(const Duration(days: 89));

    final expanded = _expandSessionsForDateRange(
      rawSessions: rawResults,
      startDate: _toIsoDate(today),
      endDate: _toIsoDate(endDate),
    );

    return expanded
        .map((session) => Map<String, dynamic>.from(session))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getSessionsWithModulesForDateRange({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    // IMPORTANT:
    // Fetch all raw sessions first, then expand recurring sessions into the
    // requested range. Otherwise recurring sessions disappear in future weeks.
    final rawResults = await dbHelper.getSessionsWithModules(userId: userId);

    final expanded = _expandSessionsForDateRange(
      rawSessions: rawResults,
      startDate: startDate,
      endDate: endDate,
    );

    return expanded
        .map((session) => Map<String, dynamic>.from(session))
        .toList(growable: false);
  }

  Future<int> updateSession({
    required int userId,
    required Map<String, dynamic> session,
  }) async {
    final safeSession = Map<String, dynamic>.from(session);
    safeSession.putIfAbsent('sessionType', () => 'manual');
    safeSession['userId'] = userId;

    return await dbHelper.updateSession(safeSession);
  }

  Future<int> deleteSession({
    required int userId,
    required int id,
  }) async {
    return await dbHelper.deleteSession(id: id, userId: userId);
  }

  Future<void> replaceGeneratedSessions({
    required int userId,
    required List<Map<String, dynamic>> generatedSessions,
  }) async {
    final safeGeneratedSessions = generatedSessions
        .map((session) => Map<String, dynamic>.from(session))
        .toList(growable: false);

    await dbHelper.replaceGeneratedSessions(
      userId: userId,
      generatedSessions: safeGeneratedSessions,
    );
  }

  List<Map<String, dynamic>> _expandSessionsForDateRange({
    required List<Map<String, dynamic>> rawSessions,
    required String startDate,
    required String endDate,
  }) {
    final rangeStart = _parseIsoDate(startDate);
    final rangeEnd = _parseIsoDate(endDate);

    final expanded = <Map<String, dynamic>>[];

    for (final rawSession in rawSessions) {
      final safeSession = Map<String, dynamic>.from(rawSession);

      final sessionDateText = (safeSession['date'] ?? '').toString().trim();
      final sessionDate = _tryParseIsoDate(sessionDateText);
      if (sessionDate == null) continue;

      final isRecurring =
          safeSession['isRecurring'] == 1 || safeSession['isRecurring'] == true;

      final recurrencePattern =
      (safeSession['recurrencePattern'] ?? 'none').toString().trim();

      if (!isRecurring || recurrencePattern == 'none') {
        if (!_isDateInRange(sessionDate, rangeStart, rangeEnd)) {
          continue;
        }

        expanded.add(safeSession);
        continue;
      }

      if (recurrencePattern == 'weekly') {
        final recurrenceDays = _readRecurrenceDays(
          safeSession['recurrenceDays'],
          fallbackWeekday: sessionDate.weekday,
        );

        final recurrenceEndDate = _tryParseIsoDate(
          (safeSession['recurrenceEndDate'] ?? '').toString().trim(),
        );

        final effectiveEnd = recurrenceEndDate != null &&
            recurrenceEndDate.isBefore(rangeEnd)
            ? recurrenceEndDate
            : rangeEnd;

        if (effectiveEnd.isBefore(rangeStart)) {
          continue;
        }

        var current = rangeStart;
        while (!current.isAfter(effectiveEnd)) {
          if (!current.isBefore(sessionDate) &&
              recurrenceDays.contains(current.weekday)) {
            expanded.add({
              ...safeSession,
              'date': _toIsoDate(current),
              'sourceSessionId': safeSession['id'],
            });
          }

          current = current.add(const Duration(days: 1));
        }
      }
    }

    expanded.sort((a, b) {
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

    return expanded;
  }

  List<int> _readRecurrenceDays(
      dynamic rawValue, {
        required int fallbackWeekday,
      }) {
    final text = (rawValue ?? '').toString().trim();

    if (text.isEmpty) {
      return [fallbackWeekday];
    }

    final values = text
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toList();

    if (values.isEmpty) {
      return [fallbackWeekday];
    }

    return values;
  }

  bool _isDateInRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _parseIsoDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime? _tryParseIsoDate(String value) {
    try {
      return _parseIsoDate(value);
    } catch (_) {
      return null;
    }
  }

  String _toIsoDate(DateTime date) {
    final safeDate = _dateOnly(date);
    final year = safeDate.year.toString().padLeft(4, '0');
    final month = safeDate.month.toString().padLeft(2, '0');
    final day = safeDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}