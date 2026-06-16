import '../database/database_helper.dart';

class PlannerEventRepository {
  final DatabaseHelper dbHelper;

  PlannerEventRepository({required this.dbHelper});

  Future<List<Map<String, dynamic>>> getAllEvents({
    required int userId,
  }) async {
    final rawResults = await dbHelper.getPlannerEvents(userId: userId);

    final today = _dateOnly(DateTime.now());
    final endDate = today.add(const Duration(days: 89));

    return _expandEventsForDateRange(
      rawEvents: rawResults,
      startDate: _toIsoDate(today),
      endDate: _toIsoDate(endDate),
    );
  }

  Future<List<Map<String, dynamic>>> getEventsForDateRange({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    // IMPORTANT FIX:
    // Fetch all raw events for the user first, then expand recurrence into the
    // requested range. If we query only by the base event date first, recurring
    // events disappear in future weeks.
    final rawResults = await dbHelper.getPlannerEvents(userId: userId);

    return _expandEventsForDateRange(
      rawEvents: rawResults,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<int> insertEvent({
    required int userId,
    required Map<String, dynamic> event,
  }) async {
    final safeEvent = Map<String, dynamic>.from(event);
    safeEvent['userId'] = userId;

    return await dbHelper.insertPlannerEvent(safeEvent);
  }

  Future<int> updateEvent({
    required int userId,
    required Map<String, dynamic> event,
  }) async {
    final safeEvent = Map<String, dynamic>.from(event);
    safeEvent['userId'] = userId;

    return await dbHelper.updatePlannerEvent(safeEvent);
  }

  Future<int> deleteEvent({
    required int userId,
    required int id,
  }) async {
    return await dbHelper.deletePlannerEvent(id: id, userId: userId);
  }

  List<Map<String, dynamic>> _expandEventsForDateRange({
    required List<Map<String, dynamic>> rawEvents,
    required String startDate,
    required String endDate,
  }) {
    final rangeStart = _parseIsoDate(startDate);
    final rangeEnd = _parseIsoDate(endDate);

    final expanded = <Map<String, dynamic>>[];

    for (final rawEvent in rawEvents) {
      final safeEvent = Map<String, dynamic>.from(rawEvent);

      final eventDateText = (safeEvent['date'] ?? '').toString().trim();
      final eventDate = _tryParseIsoDate(eventDateText);
      if (eventDate == null) continue;

      final isRecurring =
          safeEvent['isRecurring'] == 1 || safeEvent['isRecurring'] == true;

      final recurrencePattern =
      (safeEvent['recurrencePattern'] ?? 'none').toString().trim();

      if (!isRecurring || recurrencePattern == 'none') {
        if (!_isDateInRange(eventDate, rangeStart, rangeEnd)) {
          continue;
        }

        expanded.add(safeEvent);
        continue;
      }

      if (recurrencePattern == 'weekly') {
        final recurrenceDays = _readRecurrenceDays(
          safeEvent['recurrenceDays'],
          fallbackWeekday: eventDate.weekday,
        );

        final recurrenceEndDate = _tryParseIsoDate(
          (safeEvent['recurrenceEndDate'] ?? '').toString().trim(),
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
          if (!current.isBefore(eventDate) &&
              recurrenceDays.contains(current.weekday)) {
            expanded.add({
              ...safeEvent,
              'date': _toIsoDate(current),
              'sourceEventId': safeEvent['id'],
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