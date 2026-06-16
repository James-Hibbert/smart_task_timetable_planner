class WorkloadService {
  static const double _overdueDailyCapHours = 3.0;
  static const double _defaultMaxDailyStudyHours = 5.0;

  static const int _sessionLengthMinutes = 60;
  static const int _minimumSessionMinutes = 30;
  static const int _sessionBreakMinutes = 60;
  static const int _blockingEventBufferMinutes = 60;

  static const int _defaultStartHour = 9;
  static const int _defaultStartMinute = 0;

  static const int _defaultDayStartMinutes = 9 * 60;
  static const int _defaultDayEndMinutes = 18 * 60;

  static const int _weeklyViewLength = 7;
  static const int _defaultPlanningHorizonDays = 90;

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _toIsoDate(DateTime date) {
    final safeDate = _dateOnly(date);
    final year = safeDate.year.toString().padLeft(4, '0');
    final month = safeDate.month.toString().padLeft(2, '0');
    final day = safeDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime _parseIsoDate(String value) {
    return _dateOnly(DateTime.parse(value));
  }

  static DateTime? _tryParseIsoDate(String value) {
    try {
      return _dateOnly(DateTime.parse(value));
    } catch (_) {
      return null;
    }
  }

  static String _getDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  static String _formatDisplayDate(DateTime date) {
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

    final dayName = _getDayName(date).substring(0, 3);
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return '$dayName $day $month';
  }

  static String _formatHours(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}h';
    }
    return '${value.toStringAsFixed(1)}h';
  }

  static String _formatTime(int hour, int minute) {
    final hourText = hour.toString().padLeft(2, '0');
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hourText:$minuteText';
  }

  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]) * 60) + int.parse(parts[1]);
  }

  static int? _tryTimeToMinutes(String time) {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return null;

      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);

      if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
        return null;
      }

      return (hours * 60) + minutes;
    } catch (_) {
      return null;
    }
  }

  static String _minutesToTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static int _getPriorityWeight(String priority) {
    switch (priority.toLowerCase()) {
      case 'medium':
        return 2;
      case 'high':
        return 3;
      case 'low':
      default:
        return 1;
    }
  }

  static double _getUrgencyMultiplier(int daysUntilDeadline) {
    if (daysUntilDeadline <= 3) return 3;
    if (daysUntilDeadline <= 7) return 2;
    if (daysUntilDeadline <= 14) return 1.5;
    return 1;
  }

  static List<String> _orderedDatesFromToday({int length = _weeklyViewLength}) {
    final today = _dateOnly(DateTime.now());
    return List.generate(
      length,
          (index) => _toIsoDate(today.add(Duration(days: index))),
    );
  }

  static List<String> _sortDateKeys(Iterable<String> dates) {
    final sorted = dates.toList()
      ..sort((a, b) => _parseIsoDate(a).compareTo(_parseIsoDate(b)));
    return sorted;
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

  static double _readDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static bool _isCompletedTask(Map<String, dynamic> task) {
    return task['isCompleted'] == 1;
  }

  static DateTime _getPlanningWindowEndDate(DateTime deadlineDate) {
    final today = _dateOnly(DateTime.now());

    if (deadlineDate.isBefore(today)) {
      return today.add(const Duration(days: _weeklyViewLength - 1));
    }

    final horizonEnd = today.add(
      const Duration(days: _defaultPlanningHorizonDays - 1),
    );

    return deadlineDate.isBefore(horizonEnd) ? deadlineDate : horizonEnd;
  }

  static List<String> _getAvailableDatesForTask(DateTime deadlineDate) {
    final today = _dateOnly(DateTime.now());
    final distributionEnd = _getPlanningWindowEndDate(_dateOnly(deadlineDate));

    final numberOfDays = distributionEnd.difference(today).inDays + 1;
    if (numberOfDays <= 0) return [];

    return List.generate(
      numberOfDays,
          (index) => _toIsoDate(today.add(Duration(days: index))),
    );
  }

  static int calculateSingleTaskWorkloadScoreFromMap(
      Map<String, dynamic> task,
      ) {
    // Completed tasks are excluded so workload calculations only reflect
    // remaining academic work.
    if (_isCompletedTask(task)) return 0;

    final today = _dateOnly(DateTime.now());

    // Read task inputs used to calculate workload pressure.
    final deadline = _tryParseIsoDate(_readString(task, 'deadline')) ?? today;
    final estimatedHours = _readInt(task, 'estimatedHours');
    final priority = _readString(task, 'priority');

    // Higher priority tasks receive greater weighting.
    final priorityWeight = _getPriorityWeight(priority);

    // Tasks closer to their deadline receive a higher urgency multiplier.
    final daysUntilDeadline = deadline.difference(today).inDays;
    final urgencyMultiplier = _getUrgencyMultiplier(daysUntilDeadline);


    // Workload score combines effort, priority, and urgency.
    // This makes the system workload-aware rather than just deadline-based.
    return (estimatedHours * priorityWeight * urgencyMultiplier).round();
  }

  static int calculateTotalWorkloadScoreFromMaps(
      List<Map<String, dynamic>> taskMaps,
      ) {
    int workloadScore = 0;

    for (final task in taskMaps) {
      workloadScore += calculateSingleTaskWorkloadScoreFromMap(task);
    }

    return workloadScore;
  }

  static void _distributeTaskEffortAcrossPlanningWindow({
    required Map<String, double> dailyLoad,
    required DateTime now,
    required DateTime deadline,
    required double estimatedHours,
  }) {
    final today = _dateOnly(now);
    final deadlineDate = _dateOnly(deadline);
    final isOverdue = deadlineDate.isBefore(today);

    if (estimatedHours <= 0) return;

    final availableDates = _getAvailableDatesForTask(deadlineDate);
    if (availableDates.isEmpty) return;

    double totalHoursToDistribute = estimatedHours;

    if (isOverdue) {
      final maxOverdueHours =
          _overdueDailyCapHours * availableDates.length.toDouble();
      if (totalHoursToDistribute > maxOverdueHours) {
        totalHoursToDistribute = maxOverdueHours;
      }
    }

    final hoursPerDay = totalHoursToDistribute / availableDates.length;

    for (final dateKey in availableDates) {
      if (dailyLoad.containsKey(dateKey)) {
        dailyLoad[dateKey] = (dailyLoad[dateKey] ?? 0) + hoursPerDay;
      }
    }
  }

  static Map<String, double> calculateDailyWorkloadFromMaps({
    required List<Map<String, dynamic>> taskMaps,
    required List<Map<String, dynamic>> sessionMaps,
    List<Map<String, dynamic>> plannerEventMaps = const [],
  }) {
    final now = DateTime.now();
    final orderedDates = _orderedDatesFromToday(length: _weeklyViewLength);

    final Map<String, double> dailyLoad = {
      for (final date in orderedDates) date: 0,
    };

    final hasSavedSessions = sessionMaps.isNotEmpty;

    if (!hasSavedSessions) {
      for (final task in taskMaps) {
        if (_isCompletedTask(task)) continue;

        final deadline = _tryParseIsoDate(_readString(task, 'deadline'));
        if (deadline == null) continue;

        final estimatedHours = _readDouble(task, 'estimatedHours');

        _distributeTaskEffortAcrossPlanningWindow(
          dailyLoad: dailyLoad,
          now: now,
          deadline: deadline,
          estimatedHours: estimatedHours,
        );
      }
    }

    for (final session in sessionMaps) {
      final startTime = _readString(session, 'startTime');
      final endTime = _readString(session, 'endTime');
      final sessionDate = _readString(session, 'date');

      final sessionHours = _calculateSessionDuration(startTime, endTime);

      if (dailyLoad.containsKey(sessionDate)) {
        dailyLoad[sessionDate] = (dailyLoad[sessionDate] ?? 0) + sessionHours;
      }
    }

    for (final event in plannerEventMaps) {
      final startTime = _readString(event, 'startTime');
      final endTime = _readString(event, 'endTime');
      final eventDate = _readString(event, 'date');

      final eventHours = _calculateSessionDuration(startTime, endTime);

      if (dailyLoad.containsKey(eventDate)) {
        dailyLoad[eventDate] = (dailyLoad[eventDate] ?? 0) + eventHours;
      }
    }

    return dailyLoad;
  }

  static double _calculateSessionDuration(String startTime, String endTime) {
    final startTotalMinutes = _tryTimeToMinutes(startTime);
    final endTotalMinutes = _tryTimeToMinutes(endTime);

    if (startTotalMinutes == null || endTotalMinutes == null) {
      return 0;
    }

    final durationMinutes = endTotalMinutes - startTotalMinutes;
    if (durationMinutes <= 0) {
      return 0;
    }

    return durationMinutes / 60.0;
  }

  static String classifyWorkload(double hours) {
    if (hours < 2) return 'Low';
    if (hours < 4) return 'Moderate';
    if (hours < 6) return 'High';
    return 'Critical';
  }

  static String getWeeklyForecastSummaryFromDayMap(
      Map<String, double> dailyLoad,
      ) {
    final totalHours = dailyLoad.values.fold(0.0, (sum, value) => sum + value);
    final maxHours = dailyLoad.values.fold(
      0.0,
          (currentMax, value) => value > currentMax ? value : currentMax,
    );

    if (maxHours == 0 && totalHours == 0) {
      return 'No active workload yet.';
    }

    String busiestDay = 'Unknown';

    dailyLoad.forEach((dateKey, hours) {
      if (hours == maxHours) {
        final parsedDate = _tryParseIsoDate(dateKey);
        if (parsedDate != null) {
          busiestDay = _formatDisplayDate(parsedDate);
        }
      }
    });

    final double average =
    dailyLoad.isEmpty ? 0.0 : totalHours / dailyLoad.length;
    final weeklyLevel = classifyWorkload(average);
    final highPressureDays =
        dailyLoad.values.where((hours) => hours >= 4).length;

    return '$weeklyLevel workload\n'
        'Busiest day: $busiestDay (${_formatHours(maxHours)})\n'
        '$highPressureDays high-pressure day(s)';
  }

  static String buildAsciiChartFromDayMap(Map<String, double> dailyLoad) {
    final orderedDates = _sortDateKeys(dailyLoad.keys);

    final maxValue = dailyLoad.values.fold<double>(
      0,
          (currentMax, value) => value > currentMax ? value : currentMax,
    );

    if (maxValue == 0) {
      return 'No weekly workload data yet.';
    }

    final lines = orderedDates.map((dateKey) {
      final date = _parseIsoDate(dateKey);
      final shortDay = _getDayName(date).substring(0, 3);
      final value = dailyLoad[dateKey] ?? 0;
      final barLength = ((value / maxValue) * 10).round();
      final bar = '█' * barLength;
      return '$shortDay  $bar ${_formatHours(value)}';
    }).toList();

    return lines.join('\n');
  }

  static String buildRequiredStudyPaceTextFromMaps(
      List<Map<String, dynamic>> taskMaps,
      ) {
    final today = _dateOnly(DateTime.now());

    double totalEffectiveHours = 0;
    DateTime? latestDeadline;

    for (final task in taskMaps) {
      if (_isCompletedTask(task)) continue;

      final deadline = _tryParseIsoDate(_readString(task, 'deadline'));
      if (deadline == null) continue;

      final deadlineDate = _dateOnly(deadline);
      final estimatedHours = _readDouble(task, 'estimatedHours');

      if (latestDeadline == null || deadline.isAfter(latestDeadline)) {
        latestDeadline = deadline;
      }

      if (deadlineDate.isBefore(today)) {
        totalEffectiveHours += _overdueDailyCapHours * _weeklyViewLength;
      } else {
        totalEffectiveHours += estimatedHours;
      }
    }

    if (totalEffectiveHours == 0 || latestDeadline == null) {
      return 'No remaining task effort to schedule.';
    }

    final latestDeadlineDate = _dateOnly(latestDeadline);

    final daysUntilLastDeadline = latestDeadlineDate.isBefore(today)
        ? _weeklyViewLength
        : latestDeadlineDate.difference(today).inDays + 1;

    final requiredHoursPerDay = totalEffectiveHours / daysUntilLastDeadline;

    return 'Remaining task effort: ${_formatHours(totalEffectiveHours)}\n'
        'Days until last deadline: $daysUntilLastDeadline\n'
        'Required daily study: ${_formatHours(requiredHoursPerDay)} / day';
  }

  static List<String> getRiskWarningsFromMaps(
      List<Map<String, dynamic>> taskMaps,
      ) {
    final today = _dateOnly(DateTime.now());
    final warnings = <String>[];

    final incompleteTasks =
    taskMaps.where((task) => !_isCompletedTask(task)).toList();

    for (final task in incompleteTasks) {
      final deadlineDate = _tryParseIsoDate(_readString(task, 'deadline'));
      if (deadlineDate == null) continue;

      final title = _readString(task, 'title');
      final estimatedHours = _readInt(task, 'estimatedHours');

      final daysRemaining = deadlineDate.difference(today).inDays;

      if (daysRemaining < 0) {
        warnings.add('$title is overdue.');
      } else if (daysRemaining <= 2 && estimatedHours > 3) {
        warnings.add(
          '$title is due in ${daysRemaining + 1} day(s) with ${_formatHours(estimatedHours.toDouble())} remaining.',
        );
      }
    }

    if (incompleteTasks.length >= 2) {
      final sortedTasks = List<Map<String, dynamic>>.from(incompleteTasks)
        ..sort((a, b) {
          final aDate =
              _tryParseIsoDate(_readString(a, 'deadline')) ?? DateTime.now();
          final bDate =
              _tryParseIsoDate(_readString(b, 'deadline')) ?? DateTime.now();
          return aDate.compareTo(bDate);
        });

      for (int i = 0; i < sortedTasks.length - 1; i++) {
        final current = sortedTasks[i];
        final next = sortedTasks[i + 1];

        final currentDate = _tryParseIsoDate(_readString(current, 'deadline'));
        final nextDate = _tryParseIsoDate(_readString(next, 'deadline'));

        if (currentDate == null || nextDate == null) continue;

        final gap = nextDate.difference(currentDate).inDays.abs();

        if (gap <= 2) {
          warnings.add(
            'Deadline cluster detected: ${_readString(current, 'title')} and ${_readString(next, 'title')} are close together.',
          );
          break;
        }
      }
    }

    final paceText = buildRequiredStudyPaceTextFromMaps(taskMaps);
    final paceMatch = RegExp(r'Required daily study: ([0-9]+(\.[0-9]+)?)h')
        .firstMatch(paceText);

    if (paceMatch != null) {
      final pace = double.tryParse(paceMatch.group(1) ?? '0') ?? 0;
      if (pace > _defaultMaxDailyStudyHours) {
        warnings.add(
          'Required daily study pace is very high (${pace.toStringAsFixed(1)}h/day).',
        );
      }
    }

    return warnings;
  }

  static Map<String, List<String>> generateStudyPlanFromMaps(
      List<Map<String, dynamic>> taskMaps,
      ) {
    final itemPlan = generateStructuredStudyPlanFromMaps(taskMaps);

    return {
      for (final entry in itemPlan.entries)
        entry.key: entry.value.map((item) => item.displayText).toList(),
    };
  }

  static Map<String, List<_StudyPlanItem>> generateStructuredStudyPlanFromMaps(
      List<Map<String, dynamic>> taskMaps,
      ) {
    final today = _dateOnly(DateTime.now());

    final Map<String, List<_StudyPlanItem>> studyPlan = {};
    final Map<String, double> dailyAllocatedHours = {};

    final incompleteTasks =
    taskMaps.where((task) => !_isCompletedTask(task)).toList();

    incompleteTasks.sort((a, b) {
      final aScore = calculateSingleTaskWorkloadScoreFromMap(a);
      final bScore = calculateSingleTaskWorkloadScoreFromMap(b);
      return bScore.compareTo(aScore);
    });

    for (final task in incompleteTasks) {
      final title = _readString(task, 'title').trim();
      final safeTitle = title.isNotEmpty ? title : 'Study Task';

      final moduleId = _readInt(task, 'moduleId');
      if (moduleId <= 0) continue;

      final deadlineDate =
          _tryParseIsoDate(_readString(task, 'deadline')) ?? today;
      final isOverdue = deadlineDate.isBefore(today);

      double remainingHours = _readDouble(task, 'estimatedHours');
      if (remainingHours <= 0) continue;

      final availableDates = _getAvailableDatesForTask(deadlineDate);
      if (availableDates.isEmpty) continue;

      for (final date in availableDates) {
        studyPlan.putIfAbsent(date, () => []);
        dailyAllocatedHours.putIfAbsent(date, () => 0);
      }

      if (isOverdue) {
        final maxOverdueHoursThisWeek =
            _overdueDailyCapHours * availableDates.length;
        if (remainingHours > maxOverdueHoursThisWeek) {
          remainingHours = maxOverdueHoursThisWeek.toDouble();
        }
      }

      final sortedDates = List<String>.from(availableDates)
        ..sort((a, b) => _parseIsoDate(a).compareTo(_parseIsoDate(b)));

      _allocateTaskAcrossDates(
        studyPlan: studyPlan,
        dailyAllocatedHours: dailyAllocatedHours,
        sortedDates: sortedDates,
        taskTitle: safeTitle,
        moduleId: moduleId,
        remainingHours: remainingHours,
        isOverdue: isOverdue,
      );
    }

    return {
      for (final entry in studyPlan.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  static void _allocateTaskAcrossDates({
    required Map<String, List<_StudyPlanItem>> studyPlan,
    required Map<String, double> dailyAllocatedHours,
    required List<String> sortedDates,
    required String taskTitle,
    required int moduleId,
    required double remainingHours,
    required bool isOverdue,
  }) {
    if (sortedDates.isEmpty || remainingHours <= 0) return;

    double hoursLeft = remainingHours;
    final daysCount = sortedDates.length;

    for (int i = 0; i < sortedDates.length; i++) {
      if (hoursLeft <= 0.01) break;

      final date = sortedDates[i];
      final currentDayLoad = dailyAllocatedHours[date] ?? 0;
      final remainingCapacity = _defaultMaxDailyStudyHours - currentDayLoad;

      if (remainingCapacity <= 0) continue;

      final remainingDaysIncludingToday = daysCount - i;
      double suggestedAllocation = hoursLeft / remainingDaysIncludingToday;

      if (suggestedAllocation > remainingCapacity) {
        suggestedAllocation = remainingCapacity;
      }

      if (isOverdue && suggestedAllocation > _overdueDailyCapHours) {
        suggestedAllocation = _overdueDailyCapHours;
      }

      if (suggestedAllocation < 0.25) {
        suggestedAllocation =
        hoursLeft < remainingCapacity ? hoursLeft : remainingCapacity;

        if (isOverdue && suggestedAllocation > _overdueDailyCapHours) {
          suggestedAllocation = _overdueDailyCapHours;
        }
      }

      if (suggestedAllocation <= 0) continue;

      final roundedAllocation =
          (suggestedAllocation * 4).roundToDouble() / 4.0;

      final finalAllocation =
      roundedAllocation > 0 ? roundedAllocation : suggestedAllocation;

      if (finalAllocation <= 0) continue;

      studyPlan[date]!.add(
        _StudyPlanItem(
          moduleId: moduleId,
          title: taskTitle,
          hours: finalAllocation,
        ),
      );

      dailyAllocatedHours[date] = currentDayLoad + finalAllocation;
      hoursLeft -= finalAllocation;
    }

    if (hoursLeft > 0.01) {
      for (int i = sortedDates.length - 1; i >= 0; i--) {
        if (hoursLeft <= 0.01) break;

        final date = sortedDates[i];
        final currentDayLoad = dailyAllocatedHours[date] ?? 0;
        final remainingCapacity = _defaultMaxDailyStudyHours - currentDayLoad;

        if (remainingCapacity <= 0) continue;

        double extraAllocation =
        hoursLeft < remainingCapacity ? hoursLeft : remainingCapacity;

        if (isOverdue && extraAllocation > _overdueDailyCapHours) {
          extraAllocation = _overdueDailyCapHours;
        }

        if (extraAllocation <= 0) continue;

        final roundedAllocation =
            (extraAllocation * 4).roundToDouble() / 4.0;

        final finalAllocation =
        roundedAllocation > 0 ? roundedAllocation : extraAllocation;

        if (finalAllocation <= 0) continue;

        studyPlan[date]!.add(
          _StudyPlanItem(
            moduleId: moduleId,
            title: taskTitle,
            hours: finalAllocation,
          ),
        );

        dailyAllocatedHours[date] = currentDayLoad + finalAllocation;
        hoursLeft -= finalAllocation;
      }
    }
  }

  static String buildStudyPlanText(Map<String, List<String>> studyPlan) {
    final buffer = StringBuffer();
    final orderedDates = _sortDateKeys(studyPlan.keys);

    for (final dateKey in orderedDates) {
      final items = studyPlan[dateKey] ?? [];

      if (items.isNotEmpty) {
        buffer.writeln(_formatDisplayDate(_parseIsoDate(dateKey)));
        for (final item in items) {
          buffer.writeln('• $item');
        }
        buffer.writeln();
      }
    }

    if (buffer.isEmpty) {
      return 'No study plan suggestions available.';
    }

    return buffer.toString().trim();
  }

  static List<Map<String, dynamic>> generateSessionBlocksFromTaskMaps(
      List<Map<String, dynamic>> taskMaps, {
        List<Map<String, dynamic>> existingSessionMaps = const [],
        List<Map<String, dynamic>> plannerEventMaps = const [],
      }) {
    final structuredPlan = generateStructuredStudyPlanFromMaps(taskMaps);

    return generateSessionBlocksFromStructuredStudyPlan(
      structuredPlan,
      existingSessionMaps: existingSessionMaps,
      plannerEventMaps: plannerEventMaps,
    );
  }

  static List<Map<String, dynamic>> generateSessionBlocksFromStructuredStudyPlan(
      Map<String, List<_StudyPlanItem>> studyPlan, {
        List<Map<String, dynamic>> existingSessionMaps = const [],
        List<Map<String, dynamic>> plannerEventMaps = const [],
      }) {
    final sessions = <Map<String, dynamic>>[];
    final hasConstraints =
        existingSessionMaps.isNotEmpty || plannerEventMaps.isNotEmpty;

    final orderedDates = _sortDateKeys(studyPlan.keys);

    for (final date in orderedDates) {
      final items = studyPlan[date] ?? [];

      if (items.isEmpty) continue;

      if (!hasConstraints) {
        sessions.addAll(
          _generateSessionsForDateWithoutConstraints(
            date: date,
            items: items,
          ),
        );
        continue;
      }

      sessions.addAll(
        _generateSessionsForDateWithConstraints(
          date: date,
          items: items,
          existingSessionMaps: existingSessionMaps,
          plannerEventMaps: plannerEventMaps,
        ),
      );
    }

    sessions.sort((a, b) {
      final dateCompare = (a['date'] ?? '').toString().compareTo(
        (b['date'] ?? '').toString(),
      );
      if (dateCompare != 0) return dateCompare;

      final startCompare = (a['startTime'] ?? '').toString().compareTo(
        (b['startTime'] ?? '').toString(),
      );
      if (startCompare != 0) return startCompare;

      return (a['title'] ?? '').toString().compareTo(
        (b['title'] ?? '').toString(),
      );
    });

    return sessions;
  }

  static List<Map<String, String>> generateSessionBlocksFromStudyPlan(
      Map<String, List<String>> studyPlan, {
        List<Map<String, dynamic>> existingSessionMaps = const [],
        List<Map<String, dynamic>> plannerEventMaps = const [],
      }) {
    final sessions = <Map<String, String>>[];
    final hasConstraints =
        existingSessionMaps.isNotEmpty || plannerEventMaps.isNotEmpty;

    final orderedDates = _sortDateKeys(studyPlan.keys);

    for (final date in orderedDates) {
      final items = studyPlan[date] ?? [];

      if (items.isEmpty) continue;

      if (!hasConstraints) {
        sessions.addAll(
          _generateLegacySessionsForDateWithoutConstraints(
            date: date,
            items: items,
          ),
        );
        continue;
      }

      sessions.addAll(
        _generateLegacySessionsForDateWithConstraints(
          date: date,
          items: items,
          existingSessionMaps: existingSessionMaps,
          plannerEventMaps: plannerEventMaps,
        ),
      );
    }

    sessions.sort((a, b) {
      final dateCompare = (a['date'] ?? '').compareTo(b['date'] ?? '');
      if (dateCompare != 0) return dateCompare;

      final startCompare =
      (a['startTime'] ?? '').compareTo(b['startTime'] ?? '');
      if (startCompare != 0) return startCompare;

      return (a['title'] ?? '').compareTo(b['title'] ?? '');
    });

    return sessions;
  }

  static List<Map<String, dynamic>> _generateSessionsForDateWithoutConstraints({
    required String date,
    required List<_StudyPlanItem> items,
  }) {
    final sessions = <Map<String, dynamic>>[];
    int currentHour = _defaultStartHour;
    int currentMinute = _defaultStartMinute;

    for (final item in items) {
      final title = item.title;
      final moduleId = item.moduleId;
      int totalMinutes = (item.hours * 60).round();

      while (totalMinutes > 0) {
        int sessionMinutes;

        if (totalMinutes >= _sessionLengthMinutes) {
          sessionMinutes = _sessionLengthMinutes;
        } else if (totalMinutes >= _minimumSessionMinutes) {
          sessionMinutes = totalMinutes;
        } else {
          break;
        }

        final startHour = currentHour;
        final startMinute = currentMinute;

        int endHour = currentHour;
        int endMinute = currentMinute + sessionMinutes;

        while (endMinute >= 60) {
          endMinute -= 60;
          endHour += 1;
        }

        sessions.add({
          'moduleId': moduleId,
          'date': date,
          'title': title,
          'startTime': _formatTime(startHour, startMinute),
          'endTime': _formatTime(endHour, endMinute),
        });

        currentHour = endHour;
        currentMinute = endMinute + _sessionBreakMinutes;

        while (currentMinute >= 60) {
          currentMinute -= 60;
          currentHour += 1;
        }

        totalMinutes -= sessionMinutes;
      }
    }

    return sessions;
  }

  static List<Map<String, dynamic>> _generateSessionsForDateWithConstraints({
    required String date,
    required List<_StudyPlanItem> items,
    required List<Map<String, dynamic>> existingSessionMaps,
    required List<Map<String, dynamic>> plannerEventMaps,
  }) {
    final sessions = <Map<String, dynamic>>[];

    // Identify blocked times for this date from manual sessions and planner events.
    // These represent real-world commitments that generated sessions must avoid.
    final blocked = _getBlockedTimeForDate(
      date: date,
      existingSessionMaps: existingSessionMaps,
      plannerEventMaps: plannerEventMaps,
    );

    // Convert blocked times into available free time blocks.
    final freeBlocks = _getFreeTimeBlocks(blocked);

    for (final item in items) {
      final title = item.title;
      final moduleId = item.moduleId;
      int totalMinutesRemaining = (item.hours * 60).round();

      // Allocate study time only inside available free blocks.
      for (int i = 0; i < freeBlocks.length && totalMinutesRemaining > 0; i++) {
        var block = freeBlocks[i];
        int currentStart = block.startMinutes;

        while (currentStart < block.endMinutes &&
            totalMinutesRemaining > 0) {
          final availableMinutes = block.endMinutes - currentStart;

          // Ignore free periods that are too short to form a useful session.
          if (availableMinutes < _minimumSessionMinutes) {
            break;
          }

          int sessionMinutes;

          // Prefer standard one-hour sessions where possible.
          if (totalMinutesRemaining >= _sessionLengthMinutes &&
              availableMinutes >= _sessionLengthMinutes) {
            sessionMinutes = _sessionLengthMinutes;
          } else {
            sessionMinutes = totalMinutesRemaining < availableMinutes
                ? totalMinutesRemaining
                : availableMinutes;

            if (sessionMinutes < _minimumSessionMinutes) {
              break;
            }
          }

          final startMinutes = currentStart;
          final endMinutes = startMinutes + sessionMinutes;

          // Create the generated session block for the timetable.
          sessions.add({
            'moduleId': moduleId,
            'date': date,
            'title': title,
            'startTime': _minutesToTime(startMinutes),
            'endTime': _minutesToTime(endMinutes),
          });

          totalMinutesRemaining -= sessionMinutes;

          final nextStart = endMinutes + _sessionBreakMinutes;

          // Add a break after each generated session to avoid unrealistic
          // back to back scheduling.
          if (nextStart >= block.endMinutes) {
            freeBlocks[i] = _TimeBlock(block.endMinutes, block.endMinutes);
            break;
          }

          freeBlocks[i] = _TimeBlock(nextStart, block.endMinutes);
          block = freeBlocks[i];
          currentStart = nextStart;
        }
      }
    }

    return sessions;
  }

  static List<Map<String, String>> _generateLegacySessionsForDateWithoutConstraints({
    required String date,
    required List<String> items,
  }) {
    final sessions = <Map<String, String>>[];
    int currentHour = _defaultStartHour;
    int currentMinute = _defaultStartMinute;

    for (final item in items) {
      final parsedItem = _parseStudyPlanItem(item);
      if (parsedItem == null) continue;

      final title = parsedItem.title;
      int totalMinutes = parsedItem.minutes;

      while (totalMinutes > 0) {
        int sessionMinutes;

        if (totalMinutes >= _sessionLengthMinutes) {
          sessionMinutes = _sessionLengthMinutes;
        } else if (totalMinutes >= _minimumSessionMinutes) {
          sessionMinutes = totalMinutes;
        } else {
          break;
        }

        final startHour = currentHour;
        final startMinute = currentMinute;

        int endHour = currentHour;
        int endMinute = currentMinute + sessionMinutes;

        while (endMinute >= 60) {
          endMinute -= 60;
          endHour += 1;
        }

        sessions.add({
          'date': date,
          'title': title,
          'startTime': _formatTime(startHour, startMinute),
          'endTime': _formatTime(endHour, endMinute),
        });

        currentHour = endHour;
        currentMinute = endMinute + _sessionBreakMinutes;

        while (currentMinute >= 60) {
          currentMinute -= 60;
          currentHour += 1;
        }

        totalMinutes -= sessionMinutes;
      }
    }

    return sessions;
  }

  static List<Map<String, String>> _generateLegacySessionsForDateWithConstraints({
    required String date,
    required List<String> items,
    required List<Map<String, dynamic>> existingSessionMaps,
    required List<Map<String, dynamic>> plannerEventMaps,
  }) {
    final sessions = <Map<String, String>>[];

    final blocked = _getBlockedTimeForDate(
      date: date,
      existingSessionMaps: existingSessionMaps,
      plannerEventMaps: plannerEventMaps,
    );

    final freeBlocks = _getFreeTimeBlocks(blocked);

    for (final item in items) {
      final parsedItem = _parseStudyPlanItem(item);
      if (parsedItem == null) continue;

      final title = parsedItem.title;
      int totalMinutesRemaining = parsedItem.minutes;

      for (int i = 0; i < freeBlocks.length && totalMinutesRemaining > 0; i++) {
        var block = freeBlocks[i];
        int currentStart = block.startMinutes;

        while (currentStart < block.endMinutes &&
            totalMinutesRemaining > 0) {
          final availableMinutes = block.endMinutes - currentStart;
          if (availableMinutes < _minimumSessionMinutes) {
            break;
          }

          int sessionMinutes;

          if (totalMinutesRemaining >= _sessionLengthMinutes &&
              availableMinutes >= _sessionLengthMinutes) {
            sessionMinutes = _sessionLengthMinutes;
          } else {
            sessionMinutes = totalMinutesRemaining < availableMinutes
                ? totalMinutesRemaining
                : availableMinutes;

            if (sessionMinutes < _minimumSessionMinutes) {
              break;
            }
          }

          final startMinutes = currentStart;
          final endMinutes = startMinutes + sessionMinutes;

          sessions.add({
            'date': date,
            'title': title,
            'startTime': _minutesToTime(startMinutes),
            'endTime': _minutesToTime(endMinutes),
          });

          totalMinutesRemaining -= sessionMinutes;

          final nextStart = endMinutes + _sessionBreakMinutes;

          if (nextStart >= block.endMinutes) {
            freeBlocks[i] = _TimeBlock(block.endMinutes, block.endMinutes);
            break;
          }

          freeBlocks[i] = _TimeBlock(nextStart, block.endMinutes);
          block = freeBlocks[i];
          currentStart = nextStart;
        }
      }
    }

    return sessions;
  }

  static _ParsedStudyPlanItem? _parseStudyPlanItem(String item) {
    final match =
    RegExp(r'^(.*)\s\(([0-9]+(\.[0-9]+)?)h\)$').firstMatch(item);

    if (match == null) return null;

    final title = match.group(1)?.trim() ?? 'Study Task';
    final hours = double.tryParse(match.group(2) ?? '0') ?? 0;
    final minutes = (hours * 60).round();

    if (minutes <= 0) return null;

    return _ParsedStudyPlanItem(
      title: title,
      minutes: minutes,
    );
  }

  static List<_TimeBlock> _getBlockedTimeForDate({
    required String date,
    required List<Map<String, dynamic>> existingSessionMaps,
    required List<Map<String, dynamic>> plannerEventMaps,
  }) {
    final blocks = <_TimeBlock>[];

    for (final session in existingSessionMaps) {
      if (_readString(session, 'date') == date) {
        final start = _tryTimeToMinutes(_readString(session, 'startTime'));
        final end = _tryTimeToMinutes(_readString(session, 'endTime'));

        if (start == null || end == null) continue;

        final safeStart = start < _defaultDayStartMinutes
            ? _defaultDayStartMinutes
            : start;

        final bufferedEnd = end + _blockingEventBufferMinutes;
        final safeEnd = bufferedEnd > _defaultDayEndMinutes
            ? _defaultDayEndMinutes
            : bufferedEnd;

        if (safeEnd <= safeStart) continue;

        blocks.add(_TimeBlock(safeStart, safeEnd));
      }
    }

    for (final event in plannerEventMaps) {
      if (_readString(event, 'date') == date) {
        final start = _tryTimeToMinutes(_readString(event, 'startTime'));
        final end = _tryTimeToMinutes(_readString(event, 'endTime'));

        if (start == null || end == null) continue;

        final safeStart = start < _defaultDayStartMinutes
            ? _defaultDayStartMinutes
            : start;

        final bufferedEnd = end + _blockingEventBufferMinutes;
        final safeEnd = bufferedEnd > _defaultDayEndMinutes
            ? _defaultDayEndMinutes
            : bufferedEnd;

        if (safeEnd <= safeStart) continue;

        blocks.add(_TimeBlock(safeStart, safeEnd));
      }
    }

    return blocks
        .where((block) => block.endMinutes > block.startMinutes)
        .toList();
  }

  static List<_TimeBlock> _getFreeTimeBlocks(List<_TimeBlock> blocked) {
    if (blocked.isEmpty) {
      return [_TimeBlock(_defaultDayStartMinutes, _defaultDayEndMinutes)];
    }

    blocked.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final merged = <_TimeBlock>[];
    for (final block in blocked) {
      if (merged.isEmpty) {
        merged.add(block);
      } else {
        final last = merged.last;
        if (block.startMinutes <= last.endMinutes) {
          merged[merged.length - 1] = _TimeBlock(
            last.startMinutes,
            block.endMinutes > last.endMinutes
                ? block.endMinutes
                : last.endMinutes,
          );
        } else {
          merged.add(block);
        }
      }
    }

    final free = <_TimeBlock>[];
    int current = _defaultDayStartMinutes;

    for (final block in merged) {
      if (block.startMinutes > current) {
        free.add(_TimeBlock(current, block.startMinutes));
      }
      current = block.endMinutes > current ? block.endMinutes : current;
    }

    if (current < _defaultDayEndMinutes) {
      free.add(_TimeBlock(current, _defaultDayEndMinutes));
    }

    return free.where((b) => b.endMinutes > b.startMinutes).toList();
  }

  static String buildGeneratedSessionsText(
      List<Map<String, dynamic>> sessions,
      ) {
    final buffer = StringBuffer();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final session in sessions) {
      final date = (session['date'] ?? '').toString();
      if (date.isEmpty) continue;
      grouped.putIfAbsent(date, () => []).add(session);
    }

    final orderedDates = _sortDateKeys(grouped.keys);

    for (final dateKey in orderedDates) {
      final daySessions = grouped[dateKey] ?? []
        ..sort((a, b) {
          final aTime = (a['startTime'] ?? '').toString();
          final bTime = (b['startTime'] ?? '').toString();
          return aTime.compareTo(bTime);
        });

      if (daySessions.isNotEmpty) {
        buffer.writeln(_formatDisplayDate(_parseIsoDate(dateKey)));
        for (final session in daySessions) {
          buffer.writeln(
            '• ${session['startTime']} - ${session['endTime']}  ${session['title']}',
          );
        }
        buffer.writeln();
      }
    }

    if (buffer.isEmpty) {
      return 'No generated sessions available.';
    }

    return buffer.toString().trim();
  }
}

class _StudyPlanItem {
  final int moduleId;
  final String title;
  final double hours;

  const _StudyPlanItem({
    required this.moduleId,
    required this.title,
    required this.hours,
  });

  String get displayText {
    if (hours == hours.roundToDouble()) {
      return '$title (${hours.toInt()}h)';
    }
    return '$title (${hours.toStringAsFixed(1)}h)';
  }
}

class _ParsedStudyPlanItem {
  final String title;
  final int minutes;

  const _ParsedStudyPlanItem({
    required this.title,
    required this.minutes,
  });
}

class _TimeBlock {
  final int startMinutes;
  final int endMinutes;

  const _TimeBlock(this.startMinutes, this.endMinutes);
}