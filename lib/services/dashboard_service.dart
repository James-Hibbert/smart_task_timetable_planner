import '../models/dashboard_summary.dart';
import 'insights_service.dart';
import 'workload_service.dart';

class DashboardService {
  static DashboardSummary buildSummary({
    required List<Map<String, dynamic>> taskMaps,
    required List<Map<String, dynamic>> sessionMaps,
    List<Map<String, dynamic>> plannerEventMaps = const [],
  }) {
    final today = _dateOnly(DateTime.now());
    final next7DaysInclusive = today.add(const Duration(days: 6));

    final incompleteTasks =
    taskMaps.where((task) => !_isCompletedTask(task)).toList();

    int dueThisWeek = 0;
    DateTime? nearestDeadline;
    String? nearestTaskTitle;

    for (final task in incompleteTasks) {
      final deadline = _tryParseDate(_readString(task, 'deadline'));
      if (deadline == null) continue;

      final deadlineDate = _dateOnly(deadline);

      final isDueThisWeek =
          (deadlineDate.isAtSameMomentAs(today) || deadlineDate.isAfter(today)) &&
              (deadlineDate.isAtSameMomentAs(next7DaysInclusive) ||
                  deadlineDate.isBefore(next7DaysInclusive));

      if (isDueThisWeek) {
        dueThisWeek++;
      }

      if (nearestDeadline == null || deadlineDate.isBefore(nearestDeadline)) {
        nearestDeadline = deadlineDate;
        nearestTaskTitle = _readString(task, 'title');
      }
    }

    double totalStudyHours = 0;
    for (final session in sessionMaps) {
      totalStudyHours += _calculateSessionDuration(
        _readString(session, 'startTime'),
        _readString(session, 'endTime'),
      );
    }

    final nextDeadlineText = _buildNextDeadlineText(
      nearestDeadline: nearestDeadline,
      nearestTaskTitle: nearestTaskTitle,
      today: today,
    );

    final workloadScore =
    WorkloadService.calculateTotalWorkloadScoreFromMaps(taskMaps);

    final dailyLoad = WorkloadService.calculateDailyWorkloadFromMaps(
      taskMaps: taskMaps,
      sessionMaps: sessionMaps,
      plannerEventMaps: plannerEventMaps,
    );

    final workloadSummaryText =
    WorkloadService.getWeeklyForecastSummaryFromDayMap(dailyLoad);

    final requiredStudyPaceText =
    WorkloadService.buildRequiredStudyPaceTextFromMaps(taskMaps);

    final riskWarnings = WorkloadService.getRiskWarningsFromMaps(taskMaps);

    final studySummaryText = sessionMaps.isEmpty
        ? 'No study sessions added yet.'
        : 'Sessions: ${sessionMaps.length}\n'
        'Scheduled hours: ${_formatHours(totalStudyHours)}';

    final workloadText = '$workloadSummaryText\n'
        'Task score: $workloadScore\n'
        'Study hours: ${_formatHours(totalStudyHours)}';

    final insights = InsightsService.generateInsights(
      taskMaps: taskMaps,
      sessionMaps: sessionMaps,
      dailyLoad: dailyLoad,
    );

    return DashboardSummary(
      totalTasks: incompleteTasks.length,
      tasksDueThisWeek: dueThisWeek,
      studySessionsCount: sessionMaps.length,
      scheduledStudyHours: totalStudyHours,
      nextDeadlineText: nextDeadlineText,
      workloadText: workloadText,
      studySummaryText: studySummaryText,
      requiredStudyPaceText: requiredStudyPaceText,
      riskWarnings: riskWarnings,
      dailyLoad: dailyLoad,
      insights: insights,
    );
  }

  static bool _isCompletedTask(Map<String, dynamic> task) {
    return task['isCompleted'] == 1;
  }

  static String _readString(Map<String, dynamic> map, String key) {
    return (map[key] ?? '').toString();
  }

  static DateTime? _tryParseDate(String value) {
    try {
      final parsed = DateTime.parse(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _buildNextDeadlineText({
    required DateTime? nearestDeadline,
    required String? nearestTaskTitle,
    required DateTime today,
  }) {
    final safeTitle = nearestTaskTitle?.trim() ?? '';

    if (nearestDeadline == null || safeTitle.isEmpty) {
      return 'No upcoming deadlines.';
    }

    final formattedDate = _formatDateOnly(nearestDeadline);
    final daysRemaining = nearestDeadline.difference(today).inDays;

    String dueText;
    if (daysRemaining < 0) {
      dueText = 'Overdue since: $formattedDate';
    } else if (daysRemaining == 0) {
      dueText = 'Due: Today ($formattedDate)';
    } else if (daysRemaining == 1) {
      dueText = 'Due: Tomorrow ($formattedDate)';
    } else {
      dueText = 'Due: $formattedDate';
    }

    return '$safeTitle\n$dueText';
  }

  static double _calculateSessionDuration(String startTime, String endTime) {
    final startTotalMinutes = _timeToMinutes(startTime);
    final endTotalMinutes = _timeToMinutes(endTime);

    if (startTotalMinutes == null || endTotalMinutes == null) {
      return 0;
    }

    final difference = endTotalMinutes - startTotalMinutes;
    if (difference <= 0) {
      return 0;
    }

    return difference / 60.0;
  }

  static int? _timeToMinutes(String time) {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return null;

      return (int.parse(parts[0]) * 60) + int.parse(parts[1]);
    } catch (_) {
      return null;
    }
  }

  static String _formatDateOnly(DateTime date) {
    final safeDate = _dateOnly(date);
    final year = safeDate.year.toString().padLeft(4, '0');
    final month = safeDate.month.toString().padLeft(2, '0');
    final day = safeDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _formatHours(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}h';
    }
    return '${value.toStringAsFixed(1)}h';
  }
}