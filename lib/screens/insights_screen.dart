import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planner_insight.dart';
import '../services/dashboard_service.dart';
import '../services/user_behaviour_service.dart';
import '../state/app_state.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

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

  Future<void> _handleInsightAction(
      BuildContext context,
      String actionKey,
      ) async {
    final appState = context.read<AppState>();

    UserBehaviourService.recordAction(actionKey);

    String message = 'Planner updated successfully.';

    switch (actionKey) {
      case 'auto_schedule':
        await appState.autoSchedule();
        message = 'Study plan preview generated.';
        break;

      case 'regenerate_plan':
      case 'rebalance_schedule':
        await appState.regeneratePlan();
        message = 'Study plan preview regenerated.';
        break;

      case 'save_generated_sessions':
        await appState.saveGeneratedSessions();
        message = 'Generated sessions saved to timetable.';
        break;

      default:
        return;
    }

    if (!context.mounted) return;

    final latestError = context.read<AppState>().errorMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(latestError ?? message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appState.errorMessage != null &&
        !appState.isGeneratingPlan &&
        !appState.isSavingGeneratedSessions) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            appState.errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final summary = DashboardService.buildSummary(
      taskMaps: appState.tasksWithModules,
      sessionMaps: appState.sessionsWithModules,
      plannerEventMaps: appState.plannerEvents,
    );

    final insights = summary.insights;
    final hasPreview = appState.generatedSessionPreview.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Smart Analysis',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Understand your workload, risks, and recommendations.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          if (appState.isGeneratingPlan) ...[
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Generating study plan preview...'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (hasPreview) ...[
            Card(
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.amber.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview ready',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${appState.generatedSessionPreview.length} generated session(s) are ready to review in the dashboard or timetable before saving.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: appState.isSavingGeneratedSessions
                                ? null
                                : () async {
                              await context
                                  .read<AppState>()
                                  .saveGeneratedSessions();

                              if (!context.mounted) return;

                              final latestError =
                                  context.read<AppState>().errorMessage;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    latestError ??
                                        'Generated sessions saved to timetable.',
                                  ),
                                ),
                              );
                            },
                            icon: appState.isSavingGeneratedSessions
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.save),
                            label: Text(
                              appState.isSavingGeneratedSessions
                                  ? 'Saving...'
                                  : 'Save Preview',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: appState.isSavingGeneratedSessions
                                ? null
                                : () {
                              context.read<AppState>().clearPlannerPreview();
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear Preview'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          ...insights.map(
                (insight) => _InsightDetailCard(
              insight: insight,
              iconForType: _iconForInsightType,
              colorForType: _colorForInsightType,
              formatConfidence: _formatConfidence,
              onAction: (actionKey) => _handleInsightAction(
                context,
                actionKey,
              ),
              isBusy:
              appState.isGeneratingPlan || appState.isSavingGeneratedSessions,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightDetailCard extends StatelessWidget {
  final PlannerInsight insight;
  final IconData Function(InsightType) iconForType;
  final Color Function(InsightType) colorForType;
  final String Function(double) formatConfidence;
  final Future<void> Function(String actionKey) onAction;
  final bool isBusy;

  const _InsightDetailCard({
    required this.insight,
    required this.iconForType,
    required this.colorForType,
    required this.formatConfidence,
    required this.onAction,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  iconForType(insight.type),
                  color: colorForType(insight.type),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(insight.message),
            const SizedBox(height: 6),
            Text(
              'Confidence: ${formatConfidence(insight.confidence)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (insight.reason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Why: ${insight.reason}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
            if (insight.explanation != null) ...[
              const SizedBox(height: 8),
              Text(
                'Explanation: ${insight.explanation}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (insight.action != null) ...[
              const SizedBox(height: 10),
              Text(
                'Action: ${insight.action}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (insight.actionLabel != null &&
                insight.actionKey != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isBusy ? null : () => onAction(insight.actionKey!),
                child: Text(insight.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}