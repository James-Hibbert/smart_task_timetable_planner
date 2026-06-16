import 'planner_insight.dart';

class DashboardSummary {
  final int totalTasks;
  final int tasksDueThisWeek;
  final int studySessionsCount;
  final double scheduledStudyHours;

  final String nextDeadlineText;
  final String workloadText;
  final String studySummaryText;
  final String requiredStudyPaceText;

  final List<String> riskWarnings;
  final Map<String, double> dailyLoad;
  final List<PlannerInsight> insights;

  const DashboardSummary({
    required this.totalTasks,
    required this.tasksDueThisWeek,
    required this.studySessionsCount,
    required this.scheduledStudyHours,
    required this.nextDeadlineText,
    required this.workloadText,
    required this.studySummaryText,
    required this.requiredStudyPaceText,
    this.riskWarnings = const [],
    this.dailyLoad = const {},
    this.insights = const [],
  });

  bool get hasTasks => totalTasks > 0;
  bool get hasStudySessions => studySessionsCount > 0;
  bool get hasRiskWarnings => riskWarnings.isNotEmpty;
  bool get hasInsights => insights.isNotEmpty;
}