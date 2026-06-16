import '../models/planner_insight.dart';
import 'user_behaviour_service.dart';
import 'workload_service.dart';

class InsightsService {
  static List<PlannerInsight> generateInsights({
    required List<Map<String, dynamic>> taskMaps,
    required List<Map<String, dynamic>> sessionMaps,
    required Map<String, double> dailyLoad,
  }) {
    final insights = <PlannerInsight>[];
    final today = _dateOnly(DateTime.now());

    final incompleteTasks =
    taskMaps.where((task) => !_isCompletedTask(task)).toList();

    if (incompleteTasks.isEmpty) {
      insights.add(
        const PlannerInsight(
          title: 'All caught up',
          message:
          'You have no incomplete tasks right now. This is a good time to stay ahead.',
          type: InsightType.positive,
          reason: 'All tasks are marked as completed.',
          action:
          'Consider reviewing future modules or starting upcoming work early.',
          confidence: 0.98,
          explanation:
          'The planner found no active incomplete tasks, so there is currently no immediate academic pressure.',
        ),
      );
      return insights;
    }

    final workloadScore =
    WorkloadService.calculateTotalWorkloadScoreFromMaps(taskMaps);

    if (workloadScore >= 25) {
      insights.add(
        const PlannerInsight(
          title: 'Heavy workload detected',
          message: 'Your current task mix suggests a high-pressure period.',
          type: InsightType.warning,
          reason:
          'Total workload score is high based on deadlines, priority, and estimated hours.',
          action:
          'Rebuild the study plan using your latest deadlines, sessions, and planner events.',
          actionLabel: 'Regenerate Plan',
          actionKey: 'regenerate_plan',
          confidence: 0.90,
          explanation:
          'This insight was triggered because multiple factors—deadline proximity, estimated effort, and task priority—combine into a high overall workload score.',
        ),
      );
    } else if (workloadScore > 0 && workloadScore < 10) {
      insights.add(
        const PlannerInsight(
          title: 'Workload looks manageable',
          message: 'Your current workload appears relatively light.',
          type: InsightType.positive,
          reason: 'Low combined workload score across tasks.',
          action: 'Use this time to get ahead on upcoming deadlines.',
          confidence: 0.82,
          explanation:
          'The planner detected relatively low immediate pressure compared with the time available.',
        ),
      );
    }

    final requiredStudyPaceText =
    WorkloadService.buildRequiredStudyPaceTextFromMaps(taskMaps);

    final paceMatch = RegExp(r'Required daily study: ([0-9]+(\.[0-9]+)?)h')
        .firstMatch(requiredStudyPaceText);

    if (paceMatch != null) {
      final pace = double.tryParse(paceMatch.group(1) ?? '0') ?? 0;

      if (pace >= 5) {
        insights.add(
          PlannerInsight(
            title: 'Study pace is very high',
            message:
            'You need about ${pace.toStringAsFixed(1)}h/day to stay on track.',
            type: InsightType.warning,
            reason:
            'Large amount of remaining work relative to available days.',
            action:
            'Generate an auto-scheduled preview so you can review a realistic set of study sessions.',
            actionLabel: 'Auto-Schedule Preview',
            actionKey: 'auto_schedule',
            confidence: 0.94,
            explanation:
            'The required daily pace exceeds a realistic steady workload for most students, so the system flags this as a strong warning.',
          ),
        );
      } else if (pace >= 2) {
        insights.add(
          PlannerInsight(
            title: 'Consistent study needed',
            message:
            'You need about ${pace.toStringAsFixed(1)}h/day to stay on track.',
            type: InsightType.info,
            reason: 'Moderate workload spread across remaining time.',
            action:
            'Maintain a steady daily study routine to avoid last-minute pressure.',
            confidence: 0.78,
            explanation:
            'The remaining effort is still manageable, but consistency is important to prevent workload compression near deadlines.',
          ),
        );
      }
    }

    final overdueTaskInsight = _buildOverdueTaskInsight(
      incompleteTasks: incompleteTasks,
      today: today,
    );

    if (overdueTaskInsight != null) {
      insights.add(overdueTaskInsight);
    } else {
      final atRiskTaskInsight = _buildAtRiskTaskInsight(
        incompleteTasks: incompleteTasks,
        today: today,
      );

      if (atRiskTaskInsight != null) {
        insights.add(atRiskTaskInsight);
      }
    }

    final peakDayInsight = _buildPeakDayInsight(dailyLoad);
    if (peakDayInsight != null) {
      insights.add(peakDayInsight);
    }

    final rebalanceInsight = _buildRebalancingInsight(dailyLoad);
    if (rebalanceInsight != null) {
      insights.add(rebalanceInsight);
    }

    if (_hasNoActionableRisk(insights)) {
      insights.add(
        const PlannerInsight(
          title: 'Planner is stable',
          message: 'No major workload risks detected.',
          type: InsightType.positive,
          reason: 'Workload is balanced across tasks and sessions.',
          action: 'Continue following your current plan.',
          confidence: 0.75,
          explanation:
          'Current task and session patterns do not show strong signs of overload or deadline risk.',
        ),
      );
    }

    final deduplicated = _deduplicateInsights(insights);

    deduplicated.sort((a, b) {
      int scoreA = _priorityForType(a.type);
      int scoreB = _priorityForType(b.type);

      if (a.actionKey != null && UserBehaviourService.isPreferred(a.actionKey!)) {
        scoreA -= 1;
      }

      if (b.actionKey != null && UserBehaviourService.isPreferred(b.actionKey!)) {
        scoreB -= 1;
      }

      final typeCompare = scoreA.compareTo(scoreB);
      if (typeCompare != 0) return typeCompare;

      return b.confidence.compareTo(a.confidence);
    });

    return deduplicated.take(5).toList();
  }

  static PlannerInsight? _buildOverdueTaskInsight({
    required List<Map<String, dynamic>> incompleteTasks,
    required DateTime today,
  }) {
    Map<String, dynamic>? mostOverdueTask;
    int? mostOverdueDays;

    for (final task in incompleteTasks) {
      final deadline = _tryParseDate(_readString(task, 'deadline'));
      if (deadline == null) continue;

      final deadlineDate = _dateOnly(deadline);
      final daysRemaining = deadlineDate.difference(today).inDays;

      if (daysRemaining < 0) {
        final overdueDays = daysRemaining.abs();
        if (mostOverdueDays == null || overdueDays > mostOverdueDays) {
          mostOverdueDays = overdueDays;
          mostOverdueTask = task;
        }
      }
    }

    if (mostOverdueTask == null || mostOverdueDays == null) {
      return null;
    }

    final title = _safeTaskTitle(mostOverdueTask);

    return PlannerInsight(
      title: 'Overdue task',
      message: '$title is overdue.',
      type: InsightType.warning,
      reason: 'Deadline has already passed.',
      action:
      'Generate a new study plan preview immediately so this overdue work can be prioritised.',
      actionLabel: 'Auto-Schedule Preview',
      actionKey: 'auto_schedule',
      confidence: 0.99,
      explanation:
      'This is a direct rule-based alert because the task deadline is already in the past.',
    );
  }

  static PlannerInsight? _buildAtRiskTaskInsight({
    required List<Map<String, dynamic>> incompleteTasks,
    required DateTime today,
  }) {
    Map<String, dynamic>? riskiestTask;
    int riskiestScore = -1;
    int riskiestDaysRemaining = 0;
    int riskiestEstimatedHours = 0;

    for (final task in incompleteTasks) {
      final deadline = _tryParseDate(_readString(task, 'deadline'));
      if (deadline == null) continue;

      final deadlineDate = _dateOnly(deadline);
      final daysRemaining = deadlineDate.difference(today).inDays;
      final estimatedHours = _readInt(task, 'estimatedHours');

      if (daysRemaining <= 2 && daysRemaining >= 0 && estimatedHours > 3) {
        final riskScore = ((2 - daysRemaining) * 10) + estimatedHours;

        if (riskScore > riskiestScore) {
          riskiestScore = riskScore;
          riskiestTask = task;
          riskiestDaysRemaining = daysRemaining;
          riskiestEstimatedHours = estimatedHours;
        }
      }
    }

    if (riskiestTask == null) return null;

    final title = _safeTaskTitle(riskiestTask);
    final dueLabel = riskiestDaysRemaining == 0
        ? 'today'
        : riskiestDaysRemaining == 1
        ? 'tomorrow'
        : 'in ${riskiestDaysRemaining + 1} days';

    return PlannerInsight(
      title: 'Task at risk',
      message: '$title is due $dueLabel with significant work remaining.',
      type: InsightType.warning,
      reason:
      'Due soon with about ${riskiestEstimatedHours}h still estimated.',
      action:
      'Generate a study plan preview now so focused sessions can be placed before the deadline.',
      actionLabel: 'Fix Now',
      actionKey: 'auto_schedule',
      confidence: 0.93,
      explanation:
      'The combination of short time remaining and high estimated effort makes this task likely to slip without intervention.',
    );
  }

  static PlannerInsight? _buildPeakDayInsight(
      Map<String, double> dailyLoad,
      ) {
    String busiestDate = '';
    double busiestHours = 0;

    dailyLoad.forEach((date, hours) {
      if (hours > busiestHours) {
        busiestHours = hours;
        busiestDate = date;
      }
    });

    if (busiestHours < 4 || busiestDate.isEmpty) {
      return null;
    }

    final busiestDateLabel = _formatDisplayDate(busiestDate);

    return PlannerInsight(
      title: 'Peak pressure day',
      message: '$busiestDateLabel is your busiest day.',
      type: InsightType.info,
      reason:
      '$busiestDateLabel has ${_formatHours(busiestHours)} scheduled workload.',
      action: 'You may want to rebalance generated sessions away from this date.',
      confidence: 0.80,
      explanation:
      'The planner detected a concentration of workload on one day, which may increase stress and reduce flexibility.',
    );
  }

  static PlannerInsight? _buildRebalancingInsight(
      Map<String, double> dailyLoad,
      ) {
    final lowLoadDays = dailyLoad.entries
        .where((entry) => entry.value > 0 && entry.value < 2)
        .map((entry) => entry.key)
        .toList()
      ..sort();

    final highLoadDays = dailyLoad.entries
        .where((entry) => entry.value >= 4)
        .map((entry) => entry.key)
        .toList()
      ..sort();

    if (lowLoadDays.isEmpty || highLoadDays.isEmpty) {
      return null;
    }

    final lightestDateLabel = _formatDisplayDate(lowLoadDays.first);

    return PlannerInsight(
      title: 'Rebalancing opportunity',
      message: 'You have lighter workload days available.',
      type: InsightType.recommendation,
      reason: 'Some days have less than 2h scheduled while others are busier.',
      action:
      'Rebuild the plan so some workload can shift to $lightestDateLabel.',
      actionLabel: 'Rebalance Plan',
      actionKey: 'rebalance_schedule',
      confidence: 0.76,
      explanation:
      'The planner found unused capacity on lighter days that could be used to smooth the weekly workload distribution.',
    );
  }

  static List<PlannerInsight> _deduplicateInsights(
      List<PlannerInsight> insights,
      ) {
    final seen = <String>{};
    final result = <PlannerInsight>[];

    for (final insight in insights) {
      final key =
          '${insight.title}|${insight.type.name}|${insight.actionKey ?? ''}';
      if (seen.contains(key)) continue;

      seen.add(key);
      result.add(insight);
    }

    return result;
  }

  static bool _hasNoActionableRisk(List<PlannerInsight> insights) {
    return !insights.any(
          (insight) =>
      insight.type == InsightType.warning ||
          insight.type == InsightType.recommendation,
    );
  }

  static bool _isCompletedTask(Map<String, dynamic> task) {
    return task['isCompleted'] == 1;
  }

  static String _safeTaskTitle(Map<String, dynamic> task) {
    final title = _readString(task, 'title').trim();
    return title.isNotEmpty ? title : 'Task';
  }

  static String _readString(Map<String, dynamic> map, String key) {
    return (map[key] ?? '').toString();
  }

  static int _readInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
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

  static int _priorityForType(InsightType type) {
    switch (type) {
      case InsightType.warning:
        return 0;
      case InsightType.recommendation:
        return 1;
      case InsightType.info:
        return 2;
      case InsightType.positive:
        return 3;
    }
  }

  static String _formatHours(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}h';
    }
    return '${value.toStringAsFixed(1)}h';
  }

  static String _formatDisplayDate(String isoDate) {
    final date = _tryParseDate(isoDate);
    if (date == null) return isoDate;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = _weekdayShort(date.weekday);
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];

    return '$weekday $day $month';
  }

  static String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}