import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planner_insight.dart';
import '../services/dashboard_service.dart';
import '../services/user_behaviour_service.dart';
import '../state/app_state.dart';
import '../widgets/generated_plan_preview.dart';
import '../widgets/weekly_workload_chart.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  IconData _iconForInsightType(InsightType type) {
    switch (type) {
      case InsightType.warning:
        return Icons.warning_amber_rounded;
      case InsightType.recommendation:
        return Icons.lightbulb_outline;
      case InsightType.positive:
        return Icons.check_circle_outline;
      case InsightType.info:
        return Icons.info_outline;
    }
  }

  Color _colorForInsightType(InsightType type) {
    switch (type) {
      case InsightType.warning:
        return Colors.orange;
      case InsightType.recommendation:
        return Colors.blue;
      case InsightType.positive:
        return Colors.green;
      case InsightType.info:
        return Colors.grey;
    }
  }

  String _formatConfidence(double confidence) {
    return '${(confidence * 100).round()}%';
  }

  void _showFeedbackMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  Future<void> _runPlannerAction(
      BuildContext context, {
        required String actionKey,
      }) async {
    final appState = context.read<AppState>();

    UserBehaviourService.recordAction(actionKey);

    String successMessage;

    switch (actionKey) {
      case 'auto_schedule':
        await appState.autoSchedule();
        successMessage = 'Study plan preview generated.';
        break;

      case 'regenerate_plan':
      case 'rebalance_schedule':
        await appState.regeneratePlan();
        successMessage = 'Study plan preview regenerated.';
        break;

      case 'save_generated_sessions':
        await appState.saveGeneratedSessions();
        successMessage = 'Generated sessions saved to timetable.';
        break;

      case 'clear_preview':
        appState.clearPlannerPreview();
        successMessage = 'Generated preview cleared.';
        break;

      default:
        return;
    }

    if (!context.mounted) return;

    final latestError = context.read<AppState>().errorMessage;
    _showFeedbackMessage(context, latestError ?? successMessage);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = DashboardService.buildSummary(
      taskMaps: appState.tasksWithModules,
      sessionMaps: appState.sessionsWithModules,
      plannerEventMaps: appState.plannerEvents,
    );

    final topInsights = summary.insights.take(2).toList();
    final primaryInsight = topInsights.isNotEmpty ? topInsights.first : null;

    final List<Map<String, dynamic>> previewSessions =
        appState.generatedSessionPreview;
    final hasPreview = previewSessions.isNotEmpty;
    final isBusy = appState.isPlannerBusy;
    final showPlannerErrorBanner = appState.errorMessage != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _WelcomeHeader(),
        const SizedBox(height: 16),

        if (showPlannerErrorBanner) ...[
          _PlannerErrorBanner(
            message: appState.errorMessage!,
          ),
          const SizedBox(height: 16),
        ],

        _FocusNowCard(
          nextDeadlineText: summary.nextDeadlineText,
          primaryInsight: primaryInsight,
          onInsightAction: (actionKey) => _runPlannerAction(
            context,
            actionKey: actionKey,
          ),
          isGeneratingPlan: appState.isGeneratingPlan,
          isSavingGeneratedSessions: appState.isSavingGeneratedSessions,
          hasGeneratedPreview: hasPreview,
        ),
        const SizedBox(height: 16),

        if (topInsights.isNotEmpty) ...[
          _InsightPreviewCard(
            insights: topInsights,
            iconForType: _iconForInsightType,
            colorForType: _colorForInsightType,
            formatConfidence: _formatConfidence,
            onInsightAction: (actionKey) => _runPlannerAction(
              context,
              actionKey: actionKey,
            ),
            isGeneratingPlan: appState.isGeneratingPlan,
            isSavingGeneratedSessions: appState.isSavingGeneratedSessions,
            hasGeneratedPreview: hasPreview,
          ),
          const SizedBox(height: 16),
        ],

        _WeeklySnapshotRow(
          totalTasks: summary.totalTasks,
          tasksDueThisWeek: summary.tasksDueThisWeek,
          studySessionsCount: summary.studySessionsCount,
          requiredStudyPaceText: summary.requiredStudyPaceText,
        ),
        const SizedBox(height: 16),

        WeeklyWorkloadChart(dailyLoad: summary.dailyLoad),
        const SizedBox(height: 16),

        _PlannerStatusCard(
          hasGeneratedPreview: hasPreview,
          previewSessionCount: previewSessions.length,
          isGeneratingPlan: appState.isGeneratingPlan,
          isSavingGeneratedSessions: appState.isSavingGeneratedSessions,
        ),
        const SizedBox(height: 16),

        _PlannerActionsCard(
          hasGeneratedPreview: hasPreview,
          isGeneratingPlan: appState.isGeneratingPlan,
          isSavingGeneratedSessions: appState.isSavingGeneratedSessions,
          onAutoSchedule: () => _runPlannerAction(
            context,
            actionKey: 'auto_schedule',
          ),
          onRegeneratePlan: () => _runPlannerAction(
            context,
            actionKey: 'regenerate_plan',
          ),
          onSaveGeneratedSessions: () => _runPlannerAction(
            context,
            actionKey: 'save_generated_sessions',
          ),
          onClearPreview: () => _runPlannerAction(
            context,
            actionKey: 'clear_preview',
          ),
        ),
        const SizedBox(height: 16),

        if (appState.isGeneratingPlan) ...[
          const _PlannerLoadingCard(),
          const SizedBox(height: 16),
        ],

        if (hasPreview) ...[
          const _PreviewStatusBanner(),
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generated Plan Preview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'These generated sessions are only a preview. They are not yet part of your saved timetable until you press Save Generated Sessions.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GeneratedPlanPreview(
                    sessions: previewSessions,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        _SavedTimetableContextCard(
          savedSessionsCount: summary.studySessionsCount,
          hasGeneratedPreview: hasPreview,
          isBusy: isBusy,
        ),
      ],
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Planner',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Focus on what matters most this week.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _PlannerErrorBanner extends StatelessWidget {
  final String message;

  const _PlannerErrorBanner({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusNowCard extends StatelessWidget {
  final String nextDeadlineText;
  final PlannerInsight? primaryInsight;
  final Future<void> Function(String actionKey) onInsightAction;
  final bool isGeneratingPlan;
  final bool isSavingGeneratedSessions;
  final bool hasGeneratedPreview;

  const _FocusNowCard({
    required this.nextDeadlineText,
    required this.primaryInsight,
    required this.onInsightAction,
    required this.isGeneratingPlan,
    required this.isSavingGeneratedSessions,
    required this.hasGeneratedPreview,
  });

  bool _isActionDisabled(String? actionKey) {
    if (actionKey == null) return true;

    if (actionKey == 'save_generated_sessions') {
      return isSavingGeneratedSessions || !hasGeneratedPreview;
    }

    if (actionKey == 'clear_preview') {
      return isGeneratingPlan || isSavingGeneratedSessions || !hasGeneratedPreview;
    }

    return isGeneratingPlan || isSavingGeneratedSessions;
  }

  @override
  Widget build(BuildContext context) {
    final titleLines = nextDeadlineText.split('\n');
    final mainTitle =
    titleLines.isNotEmpty ? titleLines.first : 'No upcoming deadlines';
    final subTitle =
    titleLines.length > 1 ? titleLines.sublist(1).join('\n') : '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Now',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              mainTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subTitle,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (primaryInsight != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryInsight!.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(primaryInsight!.message),
                  ],
                ),
              ),
              if (primaryInsight!.actionLabel != null &&
                  primaryInsight!.actionKey != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isActionDisabled(primaryInsight!.actionKey)
                      ? null
                      : () => onInsightAction(primaryInsight!.actionKey!),
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(primaryInsight!.actionLabel!),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightPreviewCard extends StatelessWidget {
  final List<PlannerInsight> insights;
  final IconData Function(InsightType type) iconForType;
  final Color Function(InsightType type) colorForType;
  final String Function(double confidence) formatConfidence;
  final Future<void> Function(String actionKey) onInsightAction;
  final bool isGeneratingPlan;
  final bool isSavingGeneratedSessions;
  final bool hasGeneratedPreview;

  const _InsightPreviewCard({
    required this.insights,
    required this.iconForType,
    required this.colorForType,
    required this.formatConfidence,
    required this.onInsightAction,
    required this.isGeneratingPlan,
    required this.isSavingGeneratedSessions,
    required this.hasGeneratedPreview,
  });

  bool _isDisabled(String? actionKey) {
    if (actionKey == null) return true;

    if (actionKey == 'save_generated_sessions') {
      return isSavingGeneratedSessions || !hasGeneratedPreview;
    }

    if (actionKey == 'clear_preview') {
      return isGeneratingPlan || isSavingGeneratedSessions || !hasGeneratedPreview;
    }

    return isGeneratingPlan || isSavingGeneratedSessions;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Insights',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...insights.map(
                  (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      iconForType(insight.type),
                      size: 20,
                      color: colorForType(insight.type),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(insight.message),
                          const SizedBox(height: 4),
                          Text(
                            'Confidence: ${formatConfidence(insight.confidence)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          if (insight.actionLabel != null &&
                              insight.actionKey != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _isDisabled(insight.actionKey)
                                  ? null
                                  : () => onInsightAction(insight.actionKey!),
                              child: Text(insight.actionLabel!),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklySnapshotRow extends StatelessWidget {
  final int totalTasks;
  final int tasksDueThisWeek;
  final int studySessionsCount;
  final String requiredStudyPaceText;

  const _WeeklySnapshotRow({
    required this.totalTasks,
    required this.tasksDueThisWeek,
    required this.studySessionsCount,
    required this.requiredStudyPaceText,
  });

  String _extractDailyPace(String text) {
    final match = RegExp(r'Required daily study: ([^\n]+)').firstMatch(text);
    return match?.group(1) ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final pace = _extractDailyPace(requiredStudyPaceText);

    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Tasks',
            value: '$totalTasks',
            icon: Icons.checklist,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'Due Soon',
            value: '$tasksDueThisWeek',
            icon: Icons.event,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'Sessions',
            value: '$studySessionsCount',
            icon: Icons.schedule,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'Daily Pace',
            value: pace,
            icon: Icons.timer,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerStatusCard extends StatelessWidget {
  final bool hasGeneratedPreview;
  final int previewSessionCount;
  final bool isGeneratingPlan;
  final bool isSavingGeneratedSessions;

  const _PlannerStatusCard({
    required this.hasGeneratedPreview,
    required this.previewSessionCount,
    required this.isGeneratingPlan,
    required this.isSavingGeneratedSessions,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String message;
    IconData icon;
    Color backgroundColor;
    Color borderColor;
    Color iconColor;

    if (isGeneratingPlan) {
      title = 'Planner Status';
      message = 'A fresh study plan preview is currently being generated.';
      icon = Icons.sync;
      backgroundColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      iconColor = Colors.blue.shade700;
    } else if (isSavingGeneratedSessions) {
      title = 'Planner Status';
      message = 'Generated preview sessions are currently being saved to the timetable.';
      icon = Icons.save;
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      iconColor = Colors.green.shade700;
    } else if (hasGeneratedPreview) {
      title = 'Preview Ready';
      message =
      '$previewSessionCount generated session${previewSessionCount == 1 ? '' : 's'} ready to review. These are not yet saved.';
      icon = Icons.preview_rounded;
      backgroundColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade200;
      iconColor = Colors.amber.shade800;
    } else {
      title = 'No Active Preview';
      message =
      'Your dashboard currently reflects saved timetable data only. Generate a preview to review proposed study sessions.';
      icon = Icons.event_note;
      backgroundColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade300;
      iconColor = Colors.grey.shade700;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerActionsCard extends StatelessWidget {
  final bool hasGeneratedPreview;
  final bool isGeneratingPlan;
  final bool isSavingGeneratedSessions;
  final Future<void> Function() onAutoSchedule;
  final Future<void> Function() onRegeneratePlan;
  final Future<void> Function() onSaveGeneratedSessions;
  final Future<void> Function() onClearPreview;

  const _PlannerActionsCard({
    required this.hasGeneratedPreview,
    required this.isGeneratingPlan,
    required this.isSavingGeneratedSessions,
    required this.onAutoSchedule,
    required this.onRegeneratePlan,
    required this.onSaveGeneratedSessions,
    required this.onClearPreview,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = isGeneratingPlan || isSavingGeneratedSessions;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Planner Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Generate a preview first, then save it when you are happy with the proposed sessions.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : onAutoSchedule,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Auto-Schedule Preview'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onRegeneratePlan,
                icon: const Icon(Icons.refresh),
                label: Text(
                  hasGeneratedPreview ? 'Regenerate Preview' : 'Regenerate Plan',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (!hasGeneratedPreview || isBusy)
                    ? null
                    : onSaveGeneratedSessions,
                icon: isSavingGeneratedSessions
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: Text(
                  isSavingGeneratedSessions
                      ? 'Saving Generated Sessions...'
                      : 'Save Generated Sessions',
                ),
              ),
            ),
            if (hasGeneratedPreview) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: isBusy ? null : onClearPreview,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Preview'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlannerLoadingCard extends StatelessWidget {
  const _PlannerLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Generating your study plan preview...',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStatusBanner extends StatelessWidget {
  const _PreviewStatusBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.preview_rounded,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are viewing generated preview sessions only. These have not been saved into your timetable yet.',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedTimetableContextCard extends StatelessWidget {
  final int savedSessionsCount;
  final bool hasGeneratedPreview;
  final bool isBusy;

  const _SavedTimetableContextCard({
    required this.savedSessionsCount,
    required this.hasGeneratedPreview,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Timetable Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasGeneratedPreview
                  ? 'Your dashboard statistics still reflect saved timetable data until the preview is explicitly saved.'
                  : 'Your dashboard statistics currently reflect the sessions already stored in the timetable.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event_note),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved study sessions in timetable: $savedSessionsCount',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (hasGeneratedPreview && !isBusy) ...[
              const SizedBox(height: 12),
              Text(
                'Tip: review the generated preview above, then use Save Generated Sessions to persist it.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}