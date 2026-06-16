import '../repositories/planner_event_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/task_repository.dart';
import 'workload_service.dart';

class PlannerService {
  final TaskRepository taskRepository;
  final SessionRepository sessionRepository;
  final PlannerEventRepository plannerEventRepository;

  PlannerService({
    required this.taskRepository,
    required this.sessionRepository,
    required this.plannerEventRepository,
  });

  Future<PlannerPreviewResult> buildPlannerPreview({
    required int userId,
  }) async {
    // Build a generated plan without saving it to the database.
    // This supports preview-before-save behaviour so the user can review
    // generated sessions before committing timetable changes.
    final plannerData = await _buildPlannerData(userId: userId);

    return PlannerPreviewResult(
      studyPlan: plannerData.studyPlan,
      generatedSessions: plannerData.generatedSessions,
    );
  }

  Future<void> regenerateGeneratedSessionsFromTasks({
    required int userId,
  }) async {
    // Rebuild the generated plan using the latest tasks and constraints.
    final plannerData = await _buildPlannerData(userId: userId);

    // Persist the generated sessions by replacing only previous generated sessions.
    // Manual sessions are preserved, which protects user-created timetable entries
    await sessionRepository.replaceGeneratedSessions(
      userId: userId,
      generatedSessions: plannerData.generatedSessions,
    );
  }

  Future<_PlannerData> _buildPlannerData({
    required int userId,
  }) async {
    // Load all planner inputs required for generation:
    // active tasks, blocking sessions, and planner events.
    final plannerInputs = await _loadPlannerInputs(userId: userId);

    // Generate a structured workload-aware study plan from task data.
    final structuredStudyPlan =
    WorkloadService.generateStructuredStudyPlanFromMaps(
      plannerInputs.taskMaps,
    );

    // Convert structured plan items into display text for the preview UI.
    final studyPlan = {
      for (final entry in structuredStudyPlan.entries)
        entry.key: entry.value.map((item) => item.displayText).toList(),
    };

    // Convert the study plan into actual timetable session blocks.
    // Existing sessions and planner events are passed in as constraints
    // so generated sessions do not clash with real-world commitments.
    final generatedSessions =
    WorkloadService.generateSessionBlocksFromStructuredStudyPlan(
      structuredStudyPlan,
      existingSessionMaps: plannerInputs.blockingSessionMaps,
      plannerEventMaps: plannerInputs.plannerEventMaps,
    );

    // Return normalised output so preview sessions appear in a predictable order.
    return _PlannerData(
      studyPlan: _normalizeStudyPlan(studyPlan),
      generatedSessions: _normalizeGeneratedSessions(generatedSessions),
    );
  }

  Future<_PlannerInputs> _loadPlannerInputs({
    required int userId,
  }) async {
    final taskMaps = await taskRepository.getTasksWithModules(userId: userId);

    final blockingSessionMaps =
    await sessionRepository.getBlockingSessionsWithModules(userId: userId);

    final plannerEventMaps =
    await plannerEventRepository.getAllEvents(userId: userId);

    return _PlannerInputs(
      taskMaps: taskMaps,
      blockingSessionMaps: blockingSessionMaps,
      plannerEventMaps: plannerEventMaps,
    );
  }

  Map<String, List<String>> _normalizeStudyPlan(
      Map<String, List<String>> studyPlan,
      ) {
    final sortedDates = studyPlan.keys.toList()..sort();

    return {
      for (final date in sortedDates)
        date: List<String>.from(studyPlan[date] ?? const <String>[]),
    };
  }

  List<Map<String, dynamic>> _normalizeGeneratedSessions(
      List<Map<String, dynamic>> sessions,
      ) {
    final normalized = sessions
        .map((session) => Map<String, dynamic>.from(session))
        .toList();

    normalized.sort((a, b) {
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

    return List<Map<String, dynamic>>.unmodifiable(normalized);
  }
}

class PlannerPreviewResult {
  final Map<String, List<String>> studyPlan;
  final List<Map<String, dynamic>> generatedSessions;

  const PlannerPreviewResult({
    required this.studyPlan,
    required this.generatedSessions,
  });

  bool get hasPreview => generatedSessions.isNotEmpty;
}

class _PlannerInputs {
  final List<Map<String, dynamic>> taskMaps;
  final List<Map<String, dynamic>> blockingSessionMaps;
  final List<Map<String, dynamic>> plannerEventMaps;

  const _PlannerInputs({
    required this.taskMaps,
    required this.blockingSessionMaps,
    required this.plannerEventMaps,
  });
}

class _PlannerData {
  final Map<String, List<String>> studyPlan;
  final List<Map<String, dynamic>> generatedSessions;

  const _PlannerData({
    required this.studyPlan,
    required this.generatedSessions,
  });
}