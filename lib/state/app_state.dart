import 'package:flutter/foundation.dart';

import '../repositories/module_repository.dart';
import '../repositories/planner_event_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/task_repository.dart';
import '../services/notification_service.dart';
import '../services/planner_service.dart';

class AppState extends ChangeNotifier {
  final ModuleRepository moduleRepository;
  final TaskRepository taskRepository;
  final SessionRepository sessionRepository;
  final PlannerEventRepository plannerEventRepository;
  final PlannerService plannerService;

  AppState({
    required this.moduleRepository,
    required this.taskRepository,
    required this.sessionRepository,
    required this.plannerEventRepository,
    required this.plannerService,
  });

  bool isLoading = false;
  bool isGeneratingPlan = false;
  bool isSavingGeneratedSessions = false;

  String? errorMessage;
  int? currentUserId;

  List<Map<String, dynamic>> modules = [];
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> tasksWithModules = [];
  List<Map<String, dynamic>> sessionsWithModules = [];
  List<Map<String, dynamic>> plannerEvents = [];

  String? activeStartDate;
  String? activeEndDate;

  Map<String, List<String>> studyPlanPreview = {};
  List<Map<String, dynamic>> generatedSessionPreview = [];

  bool get hasGeneratedSessionPreview => generatedSessionPreview.isNotEmpty;
  bool get isPlannerBusy => isGeneratingPlan || isSavingGeneratedSessions;
  bool get hasActiveDateRange =>
      activeStartDate != null && activeEndDate != null;
  bool get isFastTestModeEnabled =>
      NotificationService.instance.fastTestModeEnabled;
  bool get hasUserContext => currentUserId != null;

  Future<void> setCurrentUserContext(int? userId) async {
    currentUserId = userId;
    _clearGeneratedPreview(notify: false, clearError: true);

    if (userId == null) {
      modules = [];
      tasks = [];
      tasksWithModules = [];
      sessionsWithModules = [];
      plannerEvents = [];
      activeStartDate = null;
      activeEndDate = null;
      errorMessage = null;
      notifyListeners();
      return;
    }

    await loadAll();
  }

  Future<void> loadAll() async {
    if (!hasUserContext) {
      modules = [];
      tasks = [];
      tasksWithModules = [];
      sessionsWithModules = [];
      plannerEvents = [];
      activeStartDate = null;
      activeEndDate = null;
      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final userId = currentUserId!;

      modules = await moduleRepository.getModules(userId: userId);
      tasks = await taskRepository.getTasks(userId: userId);
      tasksWithModules = await taskRepository.getTasksWithModules(userId: userId);
      sessionsWithModules =
      await sessionRepository.getSessionsWithModules(userId: userId);
      plannerEvents =
      await plannerEventRepository.getAllEvents(userId: userId);

      activeStartDate = null;
      activeEndDate = null;
    } catch (e) {
      errorMessage = 'Failed to load planner data.';
      debugPrint('loadAll error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadForDateRange({
    required String startDate,
    required String endDate,
  }) async {
    if (!hasUserContext) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final userId = currentUserId!;

      modules = await moduleRepository.getModules(userId: userId);
      tasks = await taskRepository.getTasks(userId: userId);
      tasksWithModules = await taskRepository.getTasksWithModules(userId: userId);

      sessionsWithModules =
      await sessionRepository.getSessionsWithModulesForDateRange(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      plannerEvents = await plannerEventRepository.getEventsForDateRange(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      activeStartDate = startDate;
      activeEndDate = endDate;
    } catch (e) {
      errorMessage = 'Failed to load planner data for the selected period.';
      debugPrint('loadForDateRange error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentView() async {
    if (!hasUserContext) return;

    if (hasActiveDateRange) {
      await loadForDateRange(
        startDate: activeStartDate!,
        endDate: activeEndDate!,
      );
      return;
    }

    await loadAll();
  }

  Future<void> addModule(Map<String, dynamic> module) async {
    await _runDataMutation(
      action: () async {
        await moduleRepository.insertModule(
          userId: currentUserId!,
          module: module,
        );
      },
      errorText: 'Failed to add module.',
      invalidatePreview: true,
      resyncNotifications: false,
      regenerateGeneratedSessions: false,
    );
  }

  Future<void> updateModule(Map<String, dynamic> module) async {
    await _runDataMutation(
      action: () async {
        await moduleRepository.updateModule(
          userId: currentUserId!,
          module: module,
        );
      },
      errorText: 'Failed to update module.',
      invalidatePreview: true,
      resyncNotifications: false,
      regenerateGeneratedSessions: false,
    );
  }

  Future<void> deleteModule(int id) async {
    await _runDataMutation(
      action: () async {
        await moduleRepository.deleteModule(
          userId: currentUserId!,
          id: id,
        );
      },
      errorText: 'Failed to delete module.',
      invalidatePreview: true,
      resyncNotifications: false,
      regenerateGeneratedSessions: true,
    );
  }

  Future<void> addTask(Map<String, dynamic> task) async {
    await _runDataMutation(
      action: () async {
        await taskRepository.insertTask(
          userId: currentUserId!,
          task: task,
        );
      },
      errorText: 'Failed to add task.',
      invalidatePreview: true,
      resyncNotifications: true,
      regenerateGeneratedSessions: true,
    );
  }

  Future<void> updateTask(Map<String, dynamic> task) async {
    await _runDataMutation(
      action: () async {
        await taskRepository.updateTask(
          userId: currentUserId!,
          task: task,
        );
      },
      errorText: 'Failed to update task.',
      invalidatePreview: true,
      resyncNotifications: true,
      regenerateGeneratedSessions: true,
    );
  }

  Future<void> deleteTask(int id) async {
    await _runDataMutation(
      action: () async {
        await taskRepository.deleteTask(
          userId: currentUserId!,
          id: id,
        );
      },
      errorText: 'Failed to delete task.',
      invalidatePreview: true,
      resyncNotifications: true,
      regenerateGeneratedSessions: true,
    );
  }

  Future<void> addSession(Map<String, dynamic> session) async {
    await _runDataMutation(
      action: () async {
        final safeSession = Map<String, dynamic>.from(session);
        safeSession.putIfAbsent('sessionType', () => 'manual');

        await sessionRepository.insertSession(
          userId: currentUserId!,
          session: safeSession,
        );
      },
      errorText: 'Failed to add study session.',
      invalidatePreview: true,
      resyncNotifications: true,
      regenerateGeneratedSessions: false,
    );
  }

  Future<void> updateSession(Map<String, dynamic> session) async {
    await _runDataMutation(
      action: () async {
        final safeSession = Map<String, dynamic>.from(session);
        safeSession.putIfAbsent('sessionType', () => 'manual');

        await sessionRepository.updateSession(
          userId: currentUserId!,
          session: safeSession,
        );
      },
      errorText: 'Failed to update study session.',
      invalidatePreview: true,
      resyncNotifications: true,
      regenerateGeneratedSessions: false,
    );
  }

  Future<void> deleteSession(int id) async {
    await _runDataMutation(
      action: () async {
        await sessionRepository.deleteSession(
          userId: currentUserId!,
          id: id,
        );
      },
      errorText: 'Failed to delete study session.',
      invalidatePreview: true,
      resyncNotifications: true,
      regenerateGeneratedSessions: false,
    );
  }

  Future<void> addPlannerEvent(Map<String, dynamic> event) async {
    await _runDataMutation(
      action: () async {
        await plannerEventRepository.insertEvent(
          userId: currentUserId!,
          event: event,
        );
      },
      errorText: 'Failed to add planner event.',
      invalidatePreview: true,
      resyncNotifications: true,
      regenerateGeneratedSessions: true,
    );
  }

  Future<void> updatePlannerEvent(Map<String, dynamic> event) async {
    await _runDataMutation(
      action: () async {
        await plannerEventRepository.updateEvent(
          userId: currentUserId!,
          event: event,
        );
      },
      errorText: 'Failed to update planner event.',
      invalidatePreview: true,
      resyncNotifications: true,
      regenerateGeneratedSessions: true,
    );
  }

  Future<void> deletePlannerEvent(int id) async {
    await _runDataMutation(
      action: () async {
        await plannerEventRepository.deleteEvent(
          userId: currentUserId!,
          id: id,
        );
      },
      errorText: 'Failed to delete planner event.',
      invalidatePreview: true,
      resyncNotifications: true,
      regenerateGeneratedSessions: true,
    );
  }

  Future<void> autoSchedule() async {
    if (isPlannerBusy || !hasUserContext) return;

    isGeneratingPlan = true;
    errorMessage = null;
    notifyListeners();

    try {
      final preview = await plannerService.buildPlannerPreview(
        userId: currentUserId!,
      );
      _setGeneratedPreview(
        studyPlan: preview.studyPlan,
        generatedSessions: preview.generatedSessions,
      );
    } catch (e) {
      errorMessage = 'Failed to generate an auto-scheduled plan.';
      debugPrint('autoSchedule error: $e');
    } finally {
      isGeneratingPlan = false;
      notifyListeners();
    }
  }

  Future<void> regeneratePlan() async {
    if (isPlannerBusy || !hasUserContext) return;

    _clearGeneratedPreview(notify: false, clearError: true);
    await autoSchedule();
  }

  Future<void> saveGeneratedSessions() async {
    if (isPlannerBusy || !hasUserContext) return;

    if (generatedSessionPreview.isEmpty) {
      errorMessage = 'No generated sessions are available to save.';
      notifyListeners();
      return;
    }

    isSavingGeneratedSessions = true;
    errorMessage = null;
    notifyListeners();

    try {
      await sessionRepository.replaceGeneratedSessions(
        userId: currentUserId!,
        generatedSessions: generatedSessionPreview,
      );

      _clearGeneratedPreview(notify: false, clearError: true);
      await refreshCurrentView();

      try {
        await _resyncNotificationsFromDatabase();
      } catch (e) {
        debugPrint(
          'Notification resync failed after saving generated sessions: $e',
        );
      }
    } catch (e) {
      errorMessage = 'Failed to save generated sessions.';
      debugPrint('saveGeneratedSessions error: $e');
    } finally {
      isSavingGeneratedSessions = false;
      notifyListeners();
    }
  }

  Future<void> resyncNotifications() async {
    if (!hasUserContext) return;

    try {
      NotificationService.instance.setFastTestMode(false);
      await _resyncNotificationsFromDatabase();
      notifyListeners();
    } catch (e) {
      debugPrint('resyncNotifications error: $e');
    }
  }

  Future<void> resyncNotificationsWithFastTestMode(bool enabled) async {
    if (!hasUserContext) return;

    NotificationService.instance.setFastTestMode(enabled);

    try {
      await _resyncNotificationsFromDatabase();
      notifyListeners();
    } catch (e) {
      debugPrint('resyncNotificationsWithFastTestMode error: $e');
    }
  }

  Future<void> disableFastTestModeAndResync() async {
    if (!hasUserContext) return;

    NotificationService.instance.setFastTestMode(false);

    try {
      await _resyncNotificationsFromDatabase();
      notifyListeners();
    } catch (e) {
      debugPrint('disableFastTestModeAndResync error: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      NotificationService.instance.setFastTestMode(false);
      await NotificationService.instance.cancelAll();
      notifyListeners();
    } catch (e) {
      debugPrint('cancelAllNotifications error: $e');
    }
  }

  void clearPlannerPreview() {
    _clearGeneratedPreview(clearError: true);
  }

  void clearErrorMessage() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _runDataMutation({
    required Future<void> Function() action,
    required String errorText,
    bool invalidatePreview = true,
    bool resyncNotifications = false,
    bool regenerateGeneratedSessions = false,
  }) async {
    if (!hasUserContext) return;

    errorMessage = null;
    notifyListeners();

    try {
      await action();

      if (regenerateGeneratedSessions) {
        await plannerService.regenerateGeneratedSessionsFromTasks(
          userId: currentUserId!,
        );
      }

      await refreshCurrentView();

      if (invalidatePreview) {
        _invalidateGeneratedPreview();
      }

      if (resyncNotifications) {
        try {
          await _resyncNotificationsFromDatabase();
        } catch (e) {
          debugPrint('Notification resync error: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      errorMessage = errorText;
      debugPrint('_runDataMutation error: $e');
      notifyListeners();
    }
  }

  Future<void> _resyncNotificationsFromDatabase() async {
    final userId = currentUserId!;
    final allTasks = await taskRepository.getTasks(userId: userId);
    final allSessions =
    await sessionRepository.getSessionsWithModules(userId: userId);
    final allPlannerEvents =
    await plannerEventRepository.getAllEvents(userId: userId);

    await NotificationService.instance.resyncAllFromMaps(
      tasks: allTasks,
      sessions: allSessions,
      plannerEvents: allPlannerEvents,
    );
  }

  void _setGeneratedPreview({
    required Map<String, List<String>> studyPlan,
    required List<Map<String, dynamic>> generatedSessions,
  }) {
    studyPlanPreview = Map<String, List<String>>.from(studyPlan);
    generatedSessionPreview = List<Map<String, dynamic>>.from(
      generatedSessions.map((session) => Map<String, dynamic>.from(session)),
    );
  }

  void _invalidateGeneratedPreview() {
    if (studyPlanPreview.isEmpty && generatedSessionPreview.isEmpty) {
      return;
    }

    _clearGeneratedPreview(clearError: false);
  }

  void _clearGeneratedPreview({
    bool notify = true,
    bool clearError = false,
  }) {
    studyPlanPreview = {};
    generatedSessionPreview = [];

    if (clearError) {
      errorMessage = null;
    }

    if (notify) {
      notifyListeners();
    }
  }
}