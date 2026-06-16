import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const String _sessionChannelId = 'study_sessions';
  static const String _sessionChannelName = 'Study Session Reminders';

  static const String _eventChannelId = 'planner_events';
  static const String _eventChannelName = 'Planner Event Reminders';

  static const String _deadlineChannelId = 'task_deadlines';
  static const String _deadlineChannelName = 'Task Deadline Reminders';

  static const int _sessionIdOffset = 100000;
  static const int _eventIdOffset = 200000;
  static const int _taskIdOffset = 300000;

  static const bool _enableDebugLogs = true;

  static const Duration _studySessionLeadTime = Duration(minutes: 15);
  static const Duration _plannerEventLeadTime = Duration(minutes: 30);
  static const Duration _taskDeadlineLeadTime = Duration(hours: 24);

  static const Duration _fastTestDelay = Duration(seconds: 8);
  static const Duration _slightlyPastGracePeriod = Duration(minutes: 1);
  static const Duration _pastFallbackDelay = Duration(seconds: 5);

  bool _isInitialised = false;
  bool _canUseExactAlarms = false;
  bool _fastTestModeEnabled = false;

  bool get fastTestModeEnabled => _fastTestModeEnabled;

  void setFastTestMode(bool enabled) {
    _fastTestModeEnabled = enabled;
    _log('FAST TEST MODE ${enabled ? 'ENABLED' : 'DISABLED'}');
  }

  Future<void> init() async {
    if (_isInitialised) return;

    try {
      tz_data.initializeTimeZones();

      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));

      const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(settings);
      await _createNotificationChannels();
      await requestPermissions();

      _isInitialised = true;
      _log('NotificationService initialised successfully.');
    } catch (e, st) {
      _log('NotificationService init error: $e');
      _log(st.toString());
    }
  }

  Future<void> requestPermissions() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();

      if (Platform.isAndroid && androidPlugin != null) {
        try {
          _canUseExactAlarms =
              await androidPlugin.canScheduleExactNotifications() ?? false;

          _log('Can schedule exact alarms: $_canUseExactAlarms');

          if (!_canUseExactAlarms) {
            final granted = await androidPlugin.requestExactAlarmsPermission();
            _log('Requested exact alarm permission. Result: $granted');

            _canUseExactAlarms =
                await androidPlugin.canScheduleExactNotifications() ?? false;

            _log(
              'Can schedule exact alarms after request: $_canUseExactAlarms',
            );
          }
        } catch (e) {
          _canUseExactAlarms = false;
          _log('Exact alarm capability check/request failed: $e');
        }
      }

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e, st) {
      _log('requestPermissions error: $e');
      _log(st.toString());
    }
  }

  AndroidScheduleMode get _scheduleMode => _canUseExactAlarms
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  Future<void> debugShowNow() async {
    await _plugin.show(
      999999,
      'Instant test notification',
      'If you can see this, notifications are displaying correctly.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _sessionChannelId,
          _sessionChannelName,
          channelDescription: 'Reminders before study sessions',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

    _log('Displayed instant debug notification.');
  }

  Future<void> debugScheduleSingleIn10Seconds() async {
    final scheduledTime =
    tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));

    await _plugin.zonedSchedule(
      999998,
      'Scheduled test notification',
      'This should appear in about 10 seconds.',
      scheduledTime,
      _sessionDetails(),
      androidScheduleMode: _scheduleMode,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );

    _log(
      'Scheduled single debug notification for $scheduledTime using $_scheduleMode',
    );
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _sessionChannelId,
        _sessionChannelName,
        description: 'Reminders before study sessions',
        importance: Importance.high,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _eventChannelId,
        _eventChannelName,
        description: 'Reminders before planner events',
        importance: Importance.high,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _deadlineChannelId,
        _deadlineChannelName,
        description: 'Reminders before task deadlines',
        importance: Importance.high,
      ),
    );
  }

  NotificationDetails _sessionDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _sessionChannelId,
        _sessionChannelName,
        channelDescription: 'Reminders before study sessions',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  NotificationDetails _eventDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _eventChannelId,
        _eventChannelName,
        channelDescription: 'Reminders before planner events',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  NotificationDetails _deadlineDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _deadlineChannelId,
        _deadlineChannelName,
        channelDescription: 'Reminders before task deadlines',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  int _sessionNotificationIdFromMap(Map<String, dynamic> session) {
    final baseId =
        _readInt(session['sourceSessionId']) ?? _readInt(session['id']) ?? 0;
    final dateText = _firstNonEmptyString([session['date']]);
    final startTimeText = _firstNonEmptyString([session['startTime']]);

    final occurrenceHash = Object.hash(dateText, startTimeText).abs() % 900000;
    return _sessionIdOffset + (baseId * 1000) + occurrenceHash;
  }

  int _taskNotificationId(int taskId) => _taskIdOffset + taskId;

  int _eventNotificationId(Map<String, dynamic> event) {
    final baseId =
        _readInt(event['sourceEventId']) ?? _readInt(event['id']) ?? 0;
    final dateText = _firstNonEmptyString([event['date']]);
    final startTimeText = _firstNonEmptyString([event['startTime']]);

    final occurrenceHash = Object.hash(dateText, startTimeText).abs() % 900000;
    return _eventIdOffset + (baseId * 1000) + occurrenceHash;
  }

  Future<void> cancelSessionReminderByMap(Map<String, dynamic> session) async {
    await _plugin.cancel(_sessionNotificationIdFromMap(session));
  }

  Future<void> cancelTaskReminder(int taskId) async {
    await _plugin.cancel(_taskNotificationId(taskId));
  }

  Future<void> cancelPlannerEventReminderByMap(
      Map<String, dynamic> event,
      ) async {
    await _plugin.cancel(_eventNotificationId(event));
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _log('Cancelled all notifications.');
  }

  Future<void> resyncAllFromMaps({
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> sessions,
    required List<Map<String, dynamic>> plannerEvents,
  }) async {
    await cancelAll();

    _log(
      'Resyncing notifications. '
          'Tasks: ${tasks.length}, Sessions: ${sessions.length}, Events: ${plannerEvents.length}',
    );

    for (final session in sessions) {
      await scheduleStudySessionReminderFromMap(session);
    }

    for (final event in plannerEvents) {
      await schedulePlannerEventReminderFromMap(event);
    }

    for (final task in tasks) {
      await scheduleTaskDeadlineReminderFromMap(task);
    }
  }

  Future<void> scheduleStudySessionReminderFromMap(
      Map<String, dynamic> session,
      ) async {
    final occurrenceNotificationId = _sessionNotificationIdFromMap(session);

    final isPreview = _readInt(session['isPreview']) == 1;
    if (isPreview) {
      await cancelSessionReminderByMap(session);
      _log('Session notification skipped: preview session.');
      return;
    }

    final startDateTime = _extractSessionStartDateTime(session);
    if (startDateTime == null) {
      await cancelSessionReminderByMap(session);
      _log('Session notification skipped: invalid start time.');
      _log('Raw session date: ${session['date']}');
      _log('Raw session startTime: ${session['startTime']}');
      return;
    }

    final titleText = _firstNonEmptyString([
      session['title'],
      session['moduleName'],
      'Study session',
    ]);

    final scheduledTime = _resolveScheduledTime(
      itemType: 'session',
      itemTitle: titleText,
      targetDateTime: startDateTime,
      productionLeadTime: _studySessionLeadTime,
    );

    if (scheduledTime == null) {
      await cancelSessionReminderByMap(session);
      return;
    }

    final sessionType = _firstNonEmptyString([
      session['sessionType'],
      'study',
    ]);

    final notificationBody =
        '$titleText starts at ${_formatTime(startDateTime)}'
        '${sessionType.isNotEmpty ? ' ($sessionType)' : ''}.';

    await cancelSessionReminderByMap(session);

    _log('--- SESSION DEBUG ---');
    _log('Session id: ${session['id']}');
    _log('Source session id: ${session['sourceSessionId']}');
    _log('Session notification id: $occurrenceNotificationId');
    _log('Session: $titleText');
    _log('Raw date: ${session['date']}');
    _log('Raw startTime: ${session['startTime']}');
    _log('Start: $startDateTime');
    _log('Scheduled: $scheduledTime');
    _log('FAST TEST MODE: $_fastTestModeEnabled');

    await _plugin.zonedSchedule(
      occurrenceNotificationId,
      'Upcoming study session',
      notificationBody,
      tz.TZDateTime.from(scheduledTime, tz.local),
      _sessionDetails(),
      androidScheduleMode: _scheduleMode,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> schedulePlannerEventReminderFromMap(
      Map<String, dynamic> event,
      ) async {
    final startDateTime = _extractPlannerEventStartDateTime(event);
    if (startDateTime == null) {
      await cancelPlannerEventReminderByMap(event);
      _log('Event notification skipped: invalid start time.');
      _log('Raw event date: ${event['date']}');
      _log('Raw event startTime: ${event['startTime']}');
      return;
    }

    final titleText = _firstNonEmptyString([
      event['title'],
      event['type'],
      'Planner event',
    ]);

    final scheduledTime = _resolveScheduledTime(
      itemType: 'event',
      itemTitle: titleText,
      targetDateTime: startDateTime,
      productionLeadTime: _plannerEventLeadTime,
    );

    if (scheduledTime == null) {
      await cancelPlannerEventReminderByMap(event);
      return;
    }

    final notificationBody =
        '$titleText starts at ${_formatTime(startDateTime)}.';

    await cancelPlannerEventReminderByMap(event);

    _log('--- EVENT DEBUG ---');
    _log('Event id: ${event['id']}');
    _log('Source event id: ${event['sourceEventId']}');
    _log('Event notification id: ${_eventNotificationId(event)}');
    _log('Event: $titleText');
    _log('Raw date: ${event['date']}');
    _log('Raw startTime: ${event['startTime']}');
    _log('Start: $startDateTime');
    _log('Scheduled: $scheduledTime');
    _log('FAST TEST MODE: $_fastTestModeEnabled');

    await _plugin.zonedSchedule(
      _eventNotificationId(event),
      'Upcoming event',
      notificationBody,
      tz.TZDateTime.from(scheduledTime, tz.local),
      _eventDetails(),
      androidScheduleMode: _scheduleMode,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleTaskDeadlineReminderFromMap(
      Map<String, dynamic> task,
      ) async {
    final taskId = _readInt(task['id']);
    if (taskId == null) return;

    final deadline = _extractTaskDeadlineDateTime(task);
    if (deadline == null) {
      await cancelTaskReminder(taskId);
      _log('Task notification skipped: invalid deadline.');
      _log('Raw deadline: ${task['deadline']}');
      return;
    }

    final taskTitle = _firstNonEmptyString([
      task['title'],
      'Task',
    ]);

    final scheduledTime = _resolveScheduledTime(
      itemType: 'task',
      itemTitle: taskTitle,
      targetDateTime: deadline,
      productionLeadTime: _taskDeadlineLeadTime,
    );

    if (scheduledTime == null) {
      await cancelTaskReminder(taskId);
      return;
    }

    final notificationBody =
        '$taskTitle is due on ${_formatDate(deadline)} at ${_formatTime(deadline)}.';

    await cancelTaskReminder(taskId);

    _log('--- TASK DEBUG ---');
    _log('Task id: $taskId');
    _log('Task: $taskTitle');
    _log('Raw deadline: ${task['deadline']}');
    _log('Deadline: $deadline');
    _log('Scheduled: $scheduledTime');
    _log('FAST TEST MODE: $_fastTestModeEnabled');

    await _plugin.zonedSchedule(
      _taskNotificationId(taskId),
      'Task deadline reminder',
      notificationBody,
      tz.TZDateTime.from(scheduledTime, tz.local),
      _deadlineDetails(),
      androidScheduleMode: _scheduleMode,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  DateTime? _resolveScheduledTime({
    required String itemType,
    required String itemTitle,
    required DateTime targetDateTime,
    required Duration productionLeadTime,
  }) {
    final now = DateTime.now();

    if (_fastTestModeEnabled) {
      final fastTime = now.add(_fastTestDelay);
      _log(
        'FAST TEST MODE: scheduling $itemType "$itemTitle" '
            'for $fastTime instead of ${targetDateTime.subtract(productionLeadTime)}',
      );
      return fastTime;
    }

    final intendedTime = targetDateTime.subtract(productionLeadTime);
    return _validateFutureScheduledTime(
      intendedTime,
      label: itemType,
      itemTitle: itemTitle,
    );
  }

  DateTime? _validateFutureScheduledTime(
      DateTime scheduledTime, {
        required String label,
        required String itemTitle,
      }) {
    final now = DateTime.now();

    if (scheduledTime.isAfter(now.subtract(_slightlyPastGracePeriod))) {
      if (scheduledTime.isBefore(now)) {
        final fallback = now.add(_pastFallbackDelay);
        _log(
          'Adjusted $label notification for "$itemTitle" '
              'to future fallback: $fallback',
        );
        return fallback;
      }

      return scheduledTime;
    }

    _log(
      'Skipping $label notification for "$itemTitle" '
          '(too far in past): $scheduledTime',
    );
    return null;
  }

  DateTime? _extractSessionStartDateTime(Map<String, dynamic> session) {
    return _combineDateAndTime(
      _firstNonEmptyString([session['date']]),
      _firstNonEmptyString([session['startTime']]),
    );
  }

  DateTime? _extractPlannerEventStartDateTime(Map<String, dynamic> event) {
    return _combineDateAndTime(
      _firstNonEmptyString([event['date']]),
      _firstNonEmptyString([event['startTime']]),
    );
  }

  DateTime? _extractTaskDeadlineDateTime(Map<String, dynamic> task) {
    final deadlineText = _firstNonEmptyString([task['deadline']]);
    if (deadlineText.isEmpty) return null;

    return DateTime.tryParse(deadlineText);
  }

  DateTime? _combineDateAndTime(String datePart, String timePart) {
    final safeDate = datePart.trim();
    final safeTime = timePart.trim();

    if (safeDate.isEmpty || safeTime.isEmpty) return null;

    final normalisedTime = safeTime.length == 5 ? '$safeTime:00' : safeTime;
    return DateTime.tryParse('${safeDate}T$normalisedTime');
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
  }

  void _log(String message) {
    if (_enableDebugLogs || kDebugMode) {
      debugPrint(message);
    }
  }
}