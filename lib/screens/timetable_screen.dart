import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/module.dart';
import '../models/planner_event.dart';
import '../models/study_session.dart';
import '../state/app_state.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final List<String> _eventTypes = const [
    'Work',
    'Lecture',
    'Gym',
    'Appointment',
    'Social',
    'Blocked',
  ];

  final List<_WeekdayOption> _weekdayOptions = const [
    _WeekdayOption(value: DateTime.monday, label: 'Mon'),
    _WeekdayOption(value: DateTime.tuesday, label: 'Tue'),
    _WeekdayOption(value: DateTime.wednesday, label: 'Wed'),
    _WeekdayOption(value: DateTime.thursday, label: 'Thu'),
    _WeekdayOption(value: DateTime.friday, label: 'Fri'),
    _WeekdayOption(value: DateTime.saturday, label: 'Sat'),
    _WeekdayOption(value: DateTime.sunday, label: 'Sun'),
  ];

  late DateTime _selectedWeekStart;
  bool _didLoadInitialWeek = false;

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _startOfWeek(DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didLoadInitialWeek) {
      _didLoadInitialWeek = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSelectedWeek();
      });
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _startOfWeek(DateTime date) {
    final safeDate = _dateOnly(date);
    return safeDate.subtract(Duration(days: safeDate.weekday - 1));
  }

  DateTime _endOfWeek(DateTime weekStart) {
    return _dateOnly(weekStart).add(const Duration(days: 6));
  }

  DateTime _addMonths(DateTime date, int monthsToAdd) {
    final yearOffset = ((date.month - 1 + monthsToAdd) ~/ 12);
    final newYear = date.year + yearOffset;
    final newMonth = ((date.month - 1 + monthsToAdd) % 12 + 12) % 12 + 1;

    final lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day > lastDayOfNewMonth ? lastDayOfNewMonth : date.day;

    return DateTime(newYear, newMonth, newDay);
  }

  String _toIsoDate(DateTime date) {
    final safeDate = _dateOnly(date);
    final year = safeDate.year.toString().padLeft(4, '0');
    final month = safeDate.month.toString().padLeft(2, '0');
    final day = safeDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime _parseIsoDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _weekdayName(DateTime date) {
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

  String _weekdayShort(DateTime date) {
    switch (date.weekday) {
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

  String _monthShort(DateTime date) {
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
    return months[date.month - 1];
  }

  String _formatDateLabel(DateTime date) {
    return '${_weekdayName(date)} ${date.day} ${_monthShort(date)}';
  }

  String _formatCompactDateLabel(DateTime date) {
    return '${_weekdayShort(date)} ${date.day} ${_monthShort(date)}';
  }

  String _formatWeekRange(DateTime weekStart) {
    final weekEnd = _endOfWeek(weekStart);

    if (weekStart.month == weekEnd.month && weekStart.year == weekEnd.year) {
      return '${weekStart.day}–${weekEnd.day} ${_monthShort(weekStart)} ${weekStart.year}';
    }

    if (weekStart.year == weekEnd.year) {
      return '${weekStart.day} ${_monthShort(weekStart)} – ${weekEnd.day} ${_monthShort(weekEnd)} ${weekStart.year}';
    }

    return '${weekStart.day} ${_monthShort(weekStart)} ${weekStart.year} – ${weekEnd.day} ${_monthShort(weekEnd)} ${weekEnd.year}';
  }

  String _formatMonthLabel(DateTime weekStart) {
    final weekEnd = _endOfWeek(weekStart);

    if (weekStart.month == weekEnd.month && weekStart.year == weekEnd.year) {
      return '${_monthShort(weekStart)} ${weekStart.year}';
    }

    if (weekStart.year == weekEnd.year) {
      return '${_monthShort(weekStart)} / ${_monthShort(weekEnd)} ${weekStart.year}';
    }

    return '${_monthShort(weekStart)} ${weekStart.year} / ${_monthShort(weekEnd)} ${weekEnd.year}';
  }

  List<DateTime> _datesForSelectedWeek() {
    return List.generate(
      7,
          (index) => _selectedWeekStart.add(Duration(days: index)),
    );
  }

  Future<void> _loadSelectedWeek() async {
    if (!mounted) return;

    final appState = context.read<AppState>();
    await appState.loadForDateRange(
      startDate: _toIsoDate(_selectedWeekStart),
      endDate: _toIsoDate(_endOfWeek(_selectedWeekStart)),
    );
  }

  Future<void> _goToPreviousWeek() async {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    });
    await _loadSelectedWeek();
  }

  Future<void> _goToNextWeek() async {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
    });
    await _loadSelectedWeek();
  }

  Future<void> _goToPreviousMonth() async {
    final currentReferenceDate = _selectedWeekStart.add(const Duration(days: 3));
    setState(() {
      _selectedWeekStart = _startOfWeek(_addMonths(currentReferenceDate, -1));
    });
    await _loadSelectedWeek();
  }

  Future<void> _goToNextMonth() async {
    final currentReferenceDate = _selectedWeekStart.add(const Duration(days: 3));
    setState(() {
      _selectedWeekStart = _startOfWeek(_addMonths(currentReferenceDate, 1));
    });
    await _loadSelectedWeek();
  }

  Future<void> _goToCurrentWeek() async {
    setState(() {
      _selectedWeekStart = _startOfWeek(DateTime.now());
    });
    await _loadSelectedWeek();
  }

  Future<String?> _pickTime(BuildContext context, TimeOfDay initialTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked == null) return null;

    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<String?> _pickDate(
      BuildContext context, {
        required DateTime initialDate,
      }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null) return null;
    return _toIsoDate(picked);
  }

  bool _isEndTimeAfterStartTime(String startTime, String endTime) {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    final startMinutes =
        (int.parse(startParts[0]) * 60) + int.parse(startParts[1]);
    final endMinutes = (int.parse(endParts[0]) * 60) + int.parse(endParts[1]);

    return endMinutes > startMinutes;
  }

  Future<bool> _confirmDelete(
      BuildContext context, {
        required String title,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete item'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showFeedbackMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _handleSavePreview() async {
    await context.read<AppState>().saveGeneratedSessions();
    if (!mounted) return;

    final message = context.read<AppState>().errorMessage ??
        'Generated sessions saved to timetable.';
    _showFeedbackMessage(message);
  }

  void _handleClearPreview() {
    context.read<AppState>().clearPlannerPreview();
    _showFeedbackMessage('Generated preview cleared.');
  }

  Color _eventCardColor(String type) {
    switch (type.toLowerCase()) {
      case 'work':
        return Colors.orange.shade50;
      case 'lecture':
        return Colors.purple.shade50;
      case 'gym':
        return Colors.green.shade50;
      case 'appointment':
        return Colors.teal.shade50;
      case 'social':
        return Colors.pink.shade50;
      case 'blocked':
      default:
        return Colors.red.shade50;
    }
  }

  Color _eventAccentColor(String type) {
    switch (type.toLowerCase()) {
      case 'work':
        return Colors.orange.shade100;
      case 'lecture':
        return Colors.purple.shade100;
      case 'gym':
        return Colors.green.shade100;
      case 'appointment':
        return Colors.teal.shade100;
      case 'social':
        return Colors.pink.shade100;
      case 'blocked':
      default:
        return Colors.red.shade100;
    }
  }

  IconData _eventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'work':
        return Icons.work_outline;
      case 'lecture':
        return Icons.school_outlined;
      case 'gym':
        return Icons.fitness_center;
      case 'appointment':
        return Icons.event_available_outlined;
      case 'social':
        return Icons.groups_outlined;
      case 'blocked':
      default:
        return Icons.block;
    }
  }

  String _weekdayLabelFromValue(int weekday) {
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

  String _buildRecurringDaysText(String recurrenceDays) {
    final values = recurrenceDays
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toList();

    if (values.isEmpty) return 'Weekly';

    return values.map(_weekdayLabelFromValue).join(', ');
  }

  String? _buildRecurringSummary(PlannerEvent event) {
    if (!event.isRecurring ||
        event.recurrencePattern != PlannerEvent.recurrenceWeekly) {
      return null;
    }

    final daysText = _buildRecurringDaysText(event.recurrenceDays);
    final endText = (event.recurrenceEndDate ?? '').trim();

    if (endText.isEmpty) {
      return 'Repeats weekly • $daysText';
    }

    return 'Repeats weekly • $daysText • until $endText';
  }

  String? _buildSessionRecurringSummary(StudySession session) {
    if (!session.isRecurring ||
        session.recurrencePattern != StudySession.recurrenceWeekly) {
      return null;
    }

    final daysText = _buildRecurringDaysText(session.recurrenceDays);
    final endText = (session.recurrenceEndDate ?? '').trim();

    if (endText.isEmpty) {
      return 'Repeats weekly • $daysText';
    }

    return 'Repeats weekly • $daysText • until $endText';
  }

  Future<void> _addSession({
    required BuildContext context,
    required int moduleId,
    required String title,
    required String date,
    required String startTime,
    required String endTime,
    required String room,
    required bool isRecurring,
    required String recurrencePattern,
    required String recurrenceDays,
    String? recurrenceEndDate,
  }) async {
    final appState = context.read<AppState>();

    final session = StudySession(
      userId: appState.currentUserId,
      moduleId: moduleId,
      title: title,
      date: date,
      startTime: startTime,
      endTime: endTime,
      room: room,
      sessionType: StudySession.manualType,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
      recurrenceDays: recurrenceDays,
      recurrenceEndDate: recurrenceEndDate,
    );

    await appState.addSession(session.toMap());
  }

  Future<void> _updateSession({
    required BuildContext context,
    required int id,
    required int? userId,
    required int moduleId,
    required String title,
    required String date,
    required String startTime,
    required String endTime,
    required String room,
    required String sessionType,
    required bool isRecurring,
    required String recurrencePattern,
    required String recurrenceDays,
    String? recurrenceEndDate,
  }) async {
    final session = StudySession(
      id: id,
      userId: userId,
      moduleId: moduleId,
      title: title,
      date: date,
      startTime: startTime,
      endTime: endTime,
      room: room,
      sessionType: sessionType,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
      recurrenceDays: recurrenceDays,
      recurrenceEndDate: recurrenceEndDate,
    );

    await context.read<AppState>().updateSession(session.toMap());
  }

  Future<void> _deleteSession(BuildContext context, int id) async {
    await context.read<AppState>().deleteSession(id);
  }

  Future<void> _addPlannerEvent({
    required BuildContext context,
    required String title,
    required String date,
    required String startTime,
    required String endTime,
    required String type,
    required bool isRecurring,
    required String recurrencePattern,
    required String recurrenceDays,
    String? recurrenceEndDate,
  }) async {
    final event = PlannerEvent(
      title: title,
      date: date,
      startTime: startTime,
      endTime: endTime,
      type: type,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
      recurrenceDays: recurrenceDays,
      recurrenceEndDate: recurrenceEndDate,
    );

    await context.read<AppState>().addPlannerEvent(event.toMap());
  }

  Future<void> _updatePlannerEvent({
    required BuildContext context,
    required int id,
    required String title,
    required String date,
    required String startTime,
    required String endTime,
    required String type,
    required bool isRecurring,
    required String recurrencePattern,
    required String recurrenceDays,
    String? recurrenceEndDate,
  }) async {
    final event = PlannerEvent(
      id: id,
      title: title,
      date: date,
      startTime: startTime,
      endTime: endTime,
      type: type,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
      recurrenceDays: recurrenceDays,
      recurrenceEndDate: recurrenceEndDate,
    );

    await context.read<AppState>().updatePlannerEvent(event.toMap());
  }

  Future<void> _deletePlannerEvent(BuildContext context, int id) async {
    await context.read<AppState>().deletePlannerEvent(id);
  }

  void _showAddOptionsSheet(BuildContext context, List<Module> modules) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Add Study Session'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showSessionDialog(context, modules: modules);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('Add Event / Blocked Time'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEventDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoModulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No Modules Available'),
        content: const Text(
          'Please add a module first before creating a study session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSessionDialog(
      BuildContext context, {
        required List<Module> modules,
        StudySession? existingSession,
        Map<String, dynamic>? existingDisplay,
      }) {
    if (modules.isEmpty) {
      _showNoModulesDialog(context);
      return;
    }

    final isEditing = existingSession != null;
    final formKey = GlobalKey<FormState>();

    final matchingModule = existingSession == null
        ? <Module>[]
        : modules.where((m) => m.id == existingSession.moduleId).toList();

    Module selectedModule =
    matchingModule.isNotEmpty ? matchingModule.first : modules.first;

    String selectedDate =
        existingSession?.date ?? _toIsoDate(_selectedWeekStart);
    String startTime = existingSession?.startTime ?? '09:00';
    String endTime = existingSession?.endTime ?? '10:00';

    bool isRecurring = existingSession?.isRecurring ?? false;
    String recurrencePattern =
        existingSession?.recurrencePattern ?? StudySession.recurrenceNone;
    final selectedRecurringDays = <int>{
      ...(existingSession?.recurrenceDayList ?? []),
    };
    String? recurrenceEndDate = existingSession?.recurrenceEndDate;

    bool isSubmitting = false;

    final roomController = TextEditingController(
      text: existingSession?.room ?? '',
    );

    final titleController = TextEditingController(
      text: existingDisplay != null
          ? (existingDisplay['title'] ?? '').toString()
          : '',
    );

    if (isRecurring &&
        recurrencePattern == StudySession.recurrenceWeekly &&
        selectedRecurringDays.isEmpty) {
      selectedRecurringDays.add(_parseIsoDate(selectedDate).weekday);
    }

    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final editingGeneratedSession =
                isEditing && (existingSession?.isGenerated ?? false);

            return AlertDialog(
              title: Text(isEditing ? 'Edit Study Session' : 'Add Study Session'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (editingGeneratedSession)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: const Text(
                            'Editing this generated session will convert it into a manual session so it will no longer be replaced automatically.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      TextFormField(
                        controller: titleController,
                        enabled: !isSubmitting,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Session Title (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Module>(
                        value: selectedModule,
                        decoration: const InputDecoration(
                          labelText: 'Module',
                          border: OutlineInputBorder(),
                        ),
                        items: modules.map((module) {
                          return DropdownMenuItem<Module>(
                            value: module,
                            child: Text('${module.name} (${module.code})'),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedModule = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: isSubmitting
                            ? null
                            : () async {
                          final picked = await _pickDate(
                            dialogContext,
                            initialDate: _parseIsoDate(selectedDate),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;

                              if (isRecurring &&
                                  recurrencePattern ==
                                      StudySession.recurrenceWeekly &&
                                  selectedRecurringDays.isEmpty) {
                                selectedRecurringDays.add(
                                  _parseIsoDate(selectedDate).weekday,
                                );
                              }
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDateLabel(_parseIsoDate(selectedDate))),
                              const Icon(Icons.calendar_today_outlined),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start Time'),
                        subtitle: Text(startTime),
                        trailing: const Icon(Icons.access_time),
                        enabled: !isSubmitting,
                        onTap: isSubmitting
                            ? null
                            : () async {
                          final startParts = startTime.split(':');
                          final picked = await _pickTime(
                            dialogContext,
                            TimeOfDay(
                              hour: int.parse(startParts[0]),
                              minute: int.parse(startParts[1]),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startTime = picked;
                            });
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End Time'),
                        subtitle: Text(endTime),
                        trailing: const Icon(Icons.access_time),
                        enabled: !isSubmitting,
                        onTap: isSubmitting
                            ? null
                            : () async {
                          final endParts = endTime.split(':');
                          final picked = await _pickTime(
                            dialogContext,
                            TimeOfDay(
                              hour: int.parse(endParts[0]),
                              minute: int.parse(endParts[1]),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              endTime = picked;
                            });
                          }
                        },
                      ),
                      TextFormField(
                        controller: roomController,
                        enabled: !isSubmitting,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Room / Location',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a room or location.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Repeat weekly'),
                        subtitle: Text(
                          isRecurring
                              ? 'This study session will repeat every week.'
                              : 'Turn on to create a weekly recurring study session.',
                        ),
                        value: isRecurring,
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                          setDialogState(() {
                            isRecurring = value;
                            recurrencePattern = value
                                ? StudySession.recurrenceWeekly
                                : StudySession.recurrenceNone;

                            if (value && selectedRecurringDays.isEmpty) {
                              selectedRecurringDays.add(
                                _parseIsoDate(selectedDate).weekday,
                              );
                            }

                            if (!value) {
                              selectedRecurringDays.clear();
                              recurrenceEndDate = null;
                            }
                          });
                        },
                      ),
                      if (isRecurring) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Repeat on',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _weekdayOptions.map((option) {
                            final isSelected =
                            selectedRecurringDays.contains(option.value);

                            return FilterChip(
                              label: Text(option.label),
                              selected: isSelected,
                              onSelected: isSubmitting
                                  ? null
                                  : (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedRecurringDays.add(option.value);
                                  } else {
                                    selectedRecurringDays.remove(
                                      option.value,
                                    );
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: isSubmitting
                              ? null
                              : () async {
                            final initial = recurrenceEndDate != null &&
                                recurrenceEndDate!.trim().isNotEmpty
                                ? _parseIsoDate(recurrenceEndDate!)
                                : _parseIsoDate(selectedDate).add(
                              const Duration(days: 90),
                            );

                            final picked = await _pickDate(
                              dialogContext,
                              initialDate: initial,
                            );

                            if (picked != null) {
                              setDialogState(() {
                                recurrenceEndDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Repeat Until (optional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  recurrenceEndDate == null ||
                                      recurrenceEndDate!.trim().isEmpty
                                      ? 'No end date'
                                      : _formatDateLabel(
                                    _parseIsoDate(recurrenceEndDate!),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (recurrenceEndDate != null &&
                                        recurrenceEndDate!.trim().isNotEmpty)
                                      IconButton(
                                        tooltip: 'Clear end date',
                                        onPressed: isSubmitting
                                            ? null
                                            : () {
                                          setDialogState(() {
                                            recurrenceEndDate = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear),
                                      ),
                                    const Icon(Icons.calendar_today_outlined),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) return;
                    if (selectedModule.id == null) return;

                    if (!_isEndTimeAfterStartTime(startTime, endTime)) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'End time must be later than start time.',
                            ),
                          ),
                        );
                      return;
                    }

                    if (isRecurring) {
                      if (selectedRecurringDays.isEmpty) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Select at least one weekday for a recurring session.',
                              ),
                            ),
                          );
                        return;
                      }

                      if (recurrenceEndDate != null &&
                          recurrenceEndDate!.trim().isNotEmpty) {
                        final startDateValue = _parseIsoDate(selectedDate);
                        final endDateValue =
                        _parseIsoDate(recurrenceEndDate!);

                        if (endDateValue.isBefore(startDateValue)) {
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Repeat until date must be on or after the start date.',
                                ),
                              ),
                            );
                          return;
                        }
                      }
                    }

                    setDialogState(() {
                      isSubmitting = true;
                    });

                    final recurrenceDaysText = isRecurring
                        ? (selectedRecurringDays.toList()..sort()).join(',')
                        : '';

                    final appState = context.read<AppState>();
                    appState.clearErrorMessage();

                    try {
                      if (isEditing) {
                        await _updateSession(
                          context: context,
                          id: existingSession.id!,
                          userId: existingSession.userId,
                          moduleId: selectedModule.id!,
                          title: titleController.text.trim(),
                          date: selectedDate,
                          startTime: startTime,
                          endTime: endTime,
                          room: roomController.text.trim(),
                          sessionType: existingSession.isGenerated
                              ? StudySession.manualType
                              : existingSession.sessionType,
                          isRecurring: isRecurring,
                          recurrencePattern: isRecurring
                              ? StudySession.recurrenceWeekly
                              : StudySession.recurrenceNone,
                          recurrenceDays: recurrenceDaysText,
                          recurrenceEndDate: isRecurring
                              ? recurrenceEndDate?.trim().isEmpty == true
                              ? null
                              : recurrenceEndDate
                              : null,
                        );
                      } else {
                        await _addSession(
                          context: context,
                          moduleId: selectedModule.id!,
                          title: titleController.text.trim(),
                          date: selectedDate,
                          startTime: startTime,
                          endTime: endTime,
                          room: roomController.text.trim(),
                          isRecurring: isRecurring,
                          recurrencePattern: isRecurring
                              ? StudySession.recurrenceWeekly
                              : StudySession.recurrenceNone,
                          recurrenceDays: recurrenceDaysText,
                          recurrenceEndDate: isRecurring
                              ? recurrenceEndDate?.trim().isEmpty == true
                              ? null
                              : recurrenceEndDate
                              : null,
                        );
                      }

                      final error = appState.errorMessage;
                      if (error != null && error.trim().isNotEmpty) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                        setDialogState(() {
                          isSubmitting = false;
                        });
                        return;
                      }

                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();

                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              isEditing
                                  ? 'Study session updated.'
                                  : 'Study session added.',
                            ),
                          ),
                        );
                    } catch (_) {
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        isSubmitting = false;
                      });
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEventDialog(
      BuildContext context, {
        PlannerEvent? existingEvent,
      }) {
    final isEditing = existingEvent != null;
    final formKey = GlobalKey<FormState>();

    String selectedDate = existingEvent?.date ?? _toIsoDate(_selectedWeekStart);
    String selectedType = existingEvent?.type ?? 'Work';
    String startTime = existingEvent?.startTime ?? '09:00';
    String endTime = existingEvent?.endTime ?? '10:00';

    bool isRecurring = existingEvent?.isRecurring ?? false;
    String recurrencePattern =
        existingEvent?.recurrencePattern ?? PlannerEvent.recurrenceNone;
    final selectedRecurringDays = <int>{
      ...(existingEvent?.recurrenceDayList ?? []),
    };
    String? recurrenceEndDate = existingEvent?.recurrenceEndDate;
    bool isSubmitting = false;

    final titleController = TextEditingController(
      text: existingEvent?.title ?? '',
    );

    if (isRecurring &&
        recurrencePattern == PlannerEvent.recurrenceWeekly &&
        selectedRecurringDays.isEmpty) {
      selectedRecurringDays.add(_parseIsoDate(selectedDate).weekday);
    }

    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Event' : 'Add Event'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        enabled: !isSubmitting,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Event Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an event title.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _eventTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: isSubmitting
                            ? null
                            : () async {
                          final picked = await _pickDate(
                            dialogContext,
                            initialDate: _parseIsoDate(selectedDate),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;

                              if (isRecurring &&
                                  recurrencePattern ==
                                      PlannerEvent.recurrenceWeekly &&
                                  selectedRecurringDays.isEmpty) {
                                selectedRecurringDays.add(
                                  _parseIsoDate(selectedDate).weekday,
                                );
                              }
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDateLabel(_parseIsoDate(selectedDate))),
                              const Icon(Icons.calendar_today_outlined),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start Time'),
                        subtitle: Text(startTime),
                        trailing: const Icon(Icons.access_time),
                        enabled: !isSubmitting,
                        onTap: isSubmitting
                            ? null
                            : () async {
                          final startParts = startTime.split(':');
                          final picked = await _pickTime(
                            dialogContext,
                            TimeOfDay(
                              hour: int.parse(startParts[0]),
                              minute: int.parse(startParts[1]),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startTime = picked;
                            });
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End Time'),
                        subtitle: Text(endTime),
                        trailing: const Icon(Icons.access_time),
                        enabled: !isSubmitting,
                        onTap: isSubmitting
                            ? null
                            : () async {
                          final endParts = endTime.split(':');
                          final picked = await _pickTime(
                            dialogContext,
                            TimeOfDay(
                              hour: int.parse(endParts[0]),
                              minute: int.parse(endParts[1]),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              endTime = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Repeat weekly'),
                        subtitle: Text(
                          isRecurring
                              ? 'This event will repeat every week.'
                              : 'Turn on to create a weekly recurring event.',
                        ),
                        value: isRecurring,
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                          setDialogState(() {
                            isRecurring = value;
                            recurrencePattern = value
                                ? PlannerEvent.recurrenceWeekly
                                : PlannerEvent.recurrenceNone;

                            if (value && selectedRecurringDays.isEmpty) {
                              selectedRecurringDays.add(
                                _parseIsoDate(selectedDate).weekday,
                              );
                            }

                            if (!value) {
                              selectedRecurringDays.clear();
                              recurrenceEndDate = null;
                            }
                          });
                        },
                      ),
                      if (isRecurring) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Repeat on',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _weekdayOptions.map((option) {
                            final isSelected =
                            selectedRecurringDays.contains(option.value);

                            return FilterChip(
                              label: Text(option.label),
                              selected: isSelected,
                              onSelected: isSubmitting
                                  ? null
                                  : (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedRecurringDays.add(option.value);
                                  } else {
                                    selectedRecurringDays.remove(
                                      option.value,
                                    );
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: isSubmitting
                              ? null
                              : () async {
                            final initial = recurrenceEndDate != null &&
                                recurrenceEndDate!.trim().isNotEmpty
                                ? _parseIsoDate(recurrenceEndDate!)
                                : _parseIsoDate(selectedDate).add(
                              const Duration(days: 90),
                            );

                            final picked = await _pickDate(
                              dialogContext,
                              initialDate: initial,
                            );

                            if (picked != null) {
                              setDialogState(() {
                                recurrenceEndDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Repeat Until (optional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  recurrenceEndDate == null ||
                                      recurrenceEndDate!.trim().isEmpty
                                      ? 'No end date'
                                      : _formatDateLabel(
                                    _parseIsoDate(recurrenceEndDate!),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (recurrenceEndDate != null &&
                                        recurrenceEndDate!.trim().isNotEmpty)
                                      IconButton(
                                        tooltip: 'Clear end date',
                                        onPressed: isSubmitting
                                            ? null
                                            : () {
                                          setDialogState(() {
                                            recurrenceEndDate = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear),
                                      ),
                                    const Icon(Icons.calendar_today_outlined),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) return;

                    if (!_isEndTimeAfterStartTime(startTime, endTime)) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'End time must be later than start time.',
                            ),
                          ),
                        );
                      return;
                    }

                    if (isRecurring) {
                      if (selectedRecurringDays.isEmpty) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Select at least one weekday for a recurring event.',
                              ),
                            ),
                          );
                        return;
                      }

                      if (recurrenceEndDate != null &&
                          recurrenceEndDate!.trim().isNotEmpty) {
                        final startDateValue = _parseIsoDate(selectedDate);
                        final endDateValue =
                        _parseIsoDate(recurrenceEndDate!);

                        if (endDateValue.isBefore(startDateValue)) {
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Repeat until date must be on or after the start date.',
                                ),
                              ),
                            );
                          return;
                        }
                      }
                    }

                    setDialogState(() {
                      isSubmitting = true;
                    });

                    final recurrenceDaysText = isRecurring
                        ? (selectedRecurringDays.toList()..sort()).join(',')
                        : '';

                    final appState = context.read<AppState>();
                    appState.clearErrorMessage();

                    try {
                      if (isEditing) {
                        await _updatePlannerEvent(
                          context: context,
                          id: existingEvent.id!,
                          title: titleController.text.trim(),
                          date: selectedDate,
                          startTime: startTime,
                          endTime: endTime,
                          type: selectedType,
                          isRecurring: isRecurring,
                          recurrencePattern: isRecurring
                              ? PlannerEvent.recurrenceWeekly
                              : PlannerEvent.recurrenceNone,
                          recurrenceDays: recurrenceDaysText,
                          recurrenceEndDate: isRecurring
                              ? recurrenceEndDate?.trim().isEmpty == true
                              ? null
                              : recurrenceEndDate
                              : null,
                        );
                      } else {
                        await _addPlannerEvent(
                          context: context,
                          title: titleController.text.trim(),
                          date: selectedDate,
                          startTime: startTime,
                          endTime: endTime,
                          type: selectedType,
                          isRecurring: isRecurring,
                          recurrencePattern: isRecurring
                              ? PlannerEvent.recurrenceWeekly
                              : PlannerEvent.recurrenceNone,
                          recurrenceDays: recurrenceDaysText,
                          recurrenceEndDate: isRecurring
                              ? recurrenceEndDate?.trim().isEmpty == true
                              ? null
                              : recurrenceEndDate
                              : null,
                        );
                      }

                      final error = appState.errorMessage;
                      if (error != null && error.trim().isNotEmpty) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                        setDialogState(() {
                          isSubmitting = false;
                        });
                        return;
                      }

                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();

                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              isEditing ? 'Event updated.' : 'Event added.',
                            ),
                          ),
                        );
                    } catch (_) {
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        isSubmitting = false;
                      });
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupItemsByDate(
      List<Map<String, dynamic>> items,
      ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final date in _datesForSelectedWeek()) {
      grouped[_toIsoDate(date)] = [];
    }

    for (final item in items) {
      final date = (item['date'] ?? '').toString();
      if (grouped.containsKey(date)) {
        grouped[date]!.add(item);
      }
    }

    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final aTime = (a['startTime'] ?? '').toString();
        final bTime = (b['startTime'] ?? '').toString();
        return aTime.compareTo(bTime);
      });
    }

    return grouped;
  }

  List<Map<String, dynamic>> _previewItemsForSelectedWeek(
      List<Map<String, dynamic>> previewSessions,
      ) {
    final weekStartIso = _toIsoDate(_selectedWeekStart);
    final weekEndIso = _toIsoDate(_endOfWeek(_selectedWeekStart));

    final filtered = previewSessions.where((session) {
      final date = (session['date'] ?? '').toString();
      return date.compareTo(weekStartIso) >= 0 &&
          date.compareTo(weekEndIso) <= 0;
    }).map((session) {
      return <String, dynamic>{
        ...session,
        'isEvent': 0,
        'isPreview': 1,
      };
    }).toList();

    filtered.sort((a, b) {
      final dateCompare =
      (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString());
      if (dateCompare != 0) return dateCompare;

      return (a['startTime'] ?? '')
          .toString()
          .compareTo((b['startTime'] ?? '').toString());
    });

    return filtered;
  }

  int _countSavedSessions(List<Map<String, dynamic>> items) {
    return items.where((item) => item['isEvent'] == 0).length;
  }

  int _countSavedEvents(List<Map<String, dynamic>> items) {
    return items.where((item) => item['isEvent'] == 1).length;
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
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
      ),
    );
  }

  Widget _buildHeaderSection({
    required BuildContext context,
    required List<DateTime> weekDates,
    required int savedSessionCount,
    required int savedEventCount,
    required int previewCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _goToPreviousMonth,
                icon: const Icon(Icons.keyboard_double_arrow_left),
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Month',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatMonthLabel(_selectedWeekStart),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _goToNextMonth,
                icon: const Icon(Icons.keyboard_double_arrow_right),
                tooltip: 'Next month',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: _goToPreviousWeek,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous week',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Week View',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatWeekRange(_selectedWeekStart),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _goToNextWeek,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next week',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _goToCurrentWeek,
                  icon: const Icon(Icons.today),
                  label: const Text('This Week'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryCard(
                label: 'Saved Sessions',
                value: '$savedSessionCount',
                icon: Icons.schedule,
              ),
              const SizedBox(width: 8),
              _buildSummaryCard(
                label: 'Events',
                value: '$savedEventCount',
                icon: Icons.event_note,
              ),
              const SizedBox(width: 8),
              _buildSummaryCard(
                label: 'Preview',
                value: '$previewCount',
                icon: Icons.auto_awesome,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: weekDates.map((date) {
              final isToday = _toIsoDate(date) == _toIsoDate(DateTime.now());

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.blue.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isToday
                          ? Colors.blue.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _weekdayShort(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Colors.blue.shade700
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTimetableContent({
    required BuildContext context,
    required List<Module> modules,
    required List<DateTime> weekDates,
    required Map<String, List<Map<String, dynamic>>> groupedSavedItems,
    required Map<String, List<Map<String, dynamic>>> groupedPreviewItems,
    required bool hasPreview,
    required AppState appState,
  }) {
    final content = <Widget>[];

    if (hasPreview) {
      content.add(
        Card(
          color: Colors.amber.shade50,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.amber.shade200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Generated preview for this week',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'These sessions are preview-only until you save them. They are shown separately from saved timetable items below.',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: appState.isSavingGeneratedSessions
                            ? null
                            : _handleSavePreview,
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
                            : _handleClearPreview,
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
      );
      content.add(const SizedBox(height: 16));
    }

    for (final date in weekDates) {
      final dateKey = _toIsoDate(date);
      final savedForDate = groupedSavedItems[dateKey] ?? [];
      final previewForDate = groupedPreviewItems[dateKey] ?? [];

      if (savedForDate.isEmpty && previewForDate.isEmpty) {
        content.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateLabel(date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    'No items scheduled.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      content.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDateLabel(date),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (savedForDate.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Saved Timetable Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                ),
                ...savedForDate.map((item) {
                  final isEvent = item['isEvent'] == 1;

                  if (isEvent) {
                    final event = PlannerEvent.fromMap(item);
                    final recurringSummary = _buildRecurringSummary(event);

                    return Card(
                      color: _eventCardColor(event.type),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _showEventDialog(
                          context,
                          existingEvent: event,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _eventAccentColor(event.type),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _eventIcon(event.type),
                                      size: 16,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      event.startTime,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      event.type,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _SessionChip(
                                          icon: Icons.schedule,
                                          label:
                                          '${event.startTime} - ${event.endTime}',
                                        ),
                                        _SessionChip(
                                          icon: _eventIcon(event.type),
                                          label: event.type,
                                        ),
                                        _SessionChip(
                                          icon: Icons.calendar_today_outlined,
                                          label: _formatCompactDateLabel(
                                            _parseIsoDate(event.date),
                                          ),
                                        ),
                                        if (event.isRecurring)
                                          const _SessionChip(
                                            icon: Icons.repeat,
                                            label: 'Weekly',
                                          ),
                                      ],
                                    ),
                                    if (recurringSummary != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        recurringSummary,
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: event.id != null
                                    ? () async {
                                  final confirmed = await _confirmDelete(
                                    context,
                                    title: event.title,
                                  );

                                  if (!confirmed) {
                                    return;
                                  }

                                  await _deletePlannerEvent(
                                    context,
                                    event.id!,
                                  );

                                  _showFeedbackMessage('Event deleted.');
                                }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final session = StudySession.fromMap(item);
                  final moduleName = item['moduleName'] ?? 'Unknown';
                  final moduleCode = item['moduleCode'] ?? '';
                  final sessionTitle = (item['title'] ?? '').toString().trim();
                  final isGenerated = session.isGenerated;
                  final recurringSummary = _buildSessionRecurringSummary(session);

                  return _SavedStudySessionCard(
                    session: session,
                    moduleName: moduleName.toString(),
                    moduleCode: moduleCode.toString(),
                    sessionTitle: sessionTitle,
                    isGenerated: isGenerated,
                    compactDateLabel: _formatCompactDateLabel(
                      _parseIsoDate(session.date),
                    ),
                    recurringSummary: recurringSummary,
                    onTap: () => _showSessionDialog(
                      context,
                      modules: modules,
                      existingSession: session,
                      existingDisplay: item,
                    ),
                    onDelete: session.id != null
                        ? () async {
                      final confirmed = await _confirmDelete(
                        context,
                        title: sessionTitle.isNotEmpty
                            ? sessionTitle
                            : '$moduleName ($moduleCode)',
                      );

                      if (!confirmed) return;

                      await _deleteSession(
                        context,
                        session.id!,
                      );

                      _showFeedbackMessage('Study session deleted.');
                    }
                        : null,
                  );
                }),
              ],
              if (previewForDate.isNotEmpty) ...[
                if (savedForDate.isNotEmpty) const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Generated Preview Sessions',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
                ...previewForDate.map((item) {
                  final startTime = (item['startTime'] ?? '').toString();
                  final endTime = (item['endTime'] ?? '').toString();
                  final title = (item['title'] ?? 'Study Session').toString();
                  final room = (item['room'] ?? 'Generated').toString();

                  return _PreviewStudySessionCard(
                    startTime: startTime,
                    endTime: endTime,
                    title: title,
                    room: room,
                  );
                }),
              ],
            ],
          ),
        ),
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final modules = appState.modules.map((map) => Module.fromMap(map)).toList();

    final savedItems = [
      ...appState.sessionsWithModules.map((session) => {
        ...session,
        'isEvent': 0,
        'isPreview': 0,
      }),
      ...appState.plannerEvents.map((event) => {
        ...event,
        'isEvent': 1,
        'isPreview': 0,
      }),
    ];

    savedItems.sort((a, b) {
      final dateCompare =
      (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString());
      if (dateCompare != 0) return dateCompare;

      return (a['startTime'] ?? '')
          .toString()
          .compareTo((b['startTime'] ?? '').toString());
    });

    final previewItems =
    _previewItemsForSelectedWeek(appState.generatedSessionPreview);

    final groupedSavedItems = _groupItemsByDate(savedItems);
    final groupedPreviewItems = _groupItemsByDate(previewItems);
    final weekDates = _datesForSelectedWeek();
    final hasPreview = previewItems.isNotEmpty;

    final hasAnyVisibleItems = savedItems.isNotEmpty || previewItems.isNotEmpty;

    final savedSessionCount = _countSavedSessions(savedItems);
    final savedEventCount = _countSavedEvents(savedItems);
    final previewCount = previewItems.length;

    final contentWidgets = _buildTimetableContent(
      context: context,
      modules: modules,
      weekDates: weekDates,
      groupedSavedItems: groupedSavedItems,
      groupedPreviewItems: groupedPreviewItems,
      hasPreview: hasPreview,
      appState: appState,
    );

    return Stack(
      children: [
        !hasAnyVisibleItems
            ? ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
          children: [
            _buildHeaderSection(
              context: context,
              weekDates: weekDates,
              savedSessionCount: savedSessionCount,
              savedEventCount: savedEventCount,
              previewCount: previewCount,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Center(
                child: Text(
                  'No timetable items for this week.\nTap + to add a study session or event.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
          children: [
            _buildHeaderSection(
              context: context,
              weekDates: weekDates,
              savedSessionCount: savedSessionCount,
              savedEventCount: savedEventCount,
              previewCount: previewCount,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: contentWidgets,
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showAddOptionsSheet(context, modules),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _SavedStudySessionCard extends StatelessWidget {
  final StudySession session;
  final String moduleName;
  final String moduleCode;
  final String sessionTitle;
  final bool isGenerated;
  final String compactDateLabel;
  final String? recurringSummary;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SavedStudySessionCard({
    required this.session,
    required this.moduleName,
    required this.moduleCode,
    required this.sessionTitle,
    required this.isGenerated,
    required this.compactDateLabel,
    required this.recurringSummary,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isGenerated ? Colors.blue.shade50 : null,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: isGenerated
                      ? Colors.blue.shade100
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      isGenerated ? Icons.auto_awesome : Icons.schedule,
                      size: 16,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.startTime,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessionTitle.isNotEmpty
                          ? sessionTitle
                          : '$moduleName ($moduleCode)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$moduleName ($moduleCode)',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SessionChip(
                          icon: Icons.schedule,
                          label: '${session.startTime} - ${session.endTime}',
                        ),
                        _SessionChip(
                          icon: Icons.location_on_outlined,
                          label: session.room,
                        ),
                        _SessionChip(
                          icon: Icons.calendar_today_outlined,
                          label: compactDateLabel,
                        ),
                        if (session.isRecurring)
                          const _SessionChip(
                            icon: Icons.repeat,
                            label: 'Weekly',
                          ),
                        if (isGenerated)
                          const _SessionChip(
                            icon: Icons.auto_awesome,
                            label: 'Generated',
                          ),
                      ],
                    ),
                    if (recurringSummary != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        recurringSummary!,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewStudySessionCard extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String title;
  final String room;

  const _PreviewStudySessionCard({
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.amber.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    startTime,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Not yet saved to timetable',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SessionChip(
                        icon: Icons.schedule,
                        label: '$startTime - $endTime',
                      ),
                      _SessionChip(
                        icon: Icons.location_on_outlined,
                        label: room,
                      ),
                      const _SessionChip(
                        icon: Icons.auto_awesome,
                        label: 'Preview',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SessionChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WeekdayOption {
  final int value;
  final String label;

  const _WeekdayOption({
    required this.value,
    required this.label,
  });
}