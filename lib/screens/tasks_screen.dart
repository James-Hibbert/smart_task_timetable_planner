import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/module.dart';
import '../models/task.dart';
import '../services/workload_service.dart';
import '../state/app_state.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _showIncompleteOnly = false;
  bool _showAtRiskOnly = false;
  String _sortOption = 'Nearest Deadline';
  String _searchQuery = '';

  final List<String> _priorityOptions = ['Low', 'Medium', 'High'];

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final year = localDate.year.toString().padLeft(4, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _isTaskAtRisk(Map<String, dynamic> taskMap) {
    final isCompleted = taskMap['isCompleted'] == 1;
    if (isCompleted) return false;

    final deadline = DateTime.parse(taskMap['deadline']);
    final deadlineDate = _dateOnly(deadline);
    final today = _dateOnly(DateTime.now());
    final estimatedHours = (taskMap['estimatedHours'] as num).toInt();

    final daysRemaining = deadlineDate.difference(today).inDays;

    if (daysRemaining < 0) return true;
    if (daysRemaining <= 2 && estimatedHours > 3) return true;

    return false;
  }

  bool _matchesSearch(Map<String, dynamic> taskMap) {
    if (_searchQuery.trim().isEmpty) return true;

    final query = _searchQuery.trim().toLowerCase();
    final title = (taskMap['title'] ?? '').toString().toLowerCase();
    final moduleName = (taskMap['moduleName'] ?? '').toString().toLowerCase();
    final moduleCode = (taskMap['moduleCode'] ?? '').toString().toLowerCase();
    final priority = (taskMap['priority'] ?? '').toString().toLowerCase();

    return title.contains(query) ||
        moduleName.contains(query) ||
        moduleCode.contains(query) ||
        priority.contains(query);
  }

  List<Map<String, dynamic>> _getFilteredAndSortedTaskData(
      List<Map<String, dynamic>> taskDisplayData,
      ) {
    List<Map<String, dynamic>> filtered = List.from(taskDisplayData);

    filtered = filtered.where(_matchesSearch).toList();

    if (_showIncompleteOnly) {
      filtered = filtered.where((task) => task['isCompleted'] == 0).toList();
    }

    if (_showAtRiskOnly) {
      filtered = filtered.where(_isTaskAtRisk).toList();
    }

    if (_sortOption == 'Nearest Deadline') {
      filtered.sort(
            (a, b) => DateTime.parse(a['deadline']).compareTo(
          DateTime.parse(b['deadline']),
        ),
      );
    } else if (_sortOption == 'Highest Priority') {
      int priorityValue(String priority) {
        switch (priority) {
          case 'High':
            return 3;
          case 'Medium':
            return 2;
          case 'Low':
            return 1;
          default:
            return 0;
        }
      }

      filtered.sort(
            (a, b) => priorityValue(
          b['priority'],
        ).compareTo(priorityValue(a['priority'])),
      );
    } else if (_sortOption == 'Highest Workload') {
      filtered.sort((a, b) {
        final scoreB =
        WorkloadService.calculateSingleTaskWorkloadScoreFromMap(b);
        final scoreA =
        WorkloadService.calculateSingleTaskWorkloadScoreFromMap(a);
        return scoreB.compareTo(scoreA);
      });
    }

    return filtered;
  }

  Future<void> _addTask({
    required BuildContext context,
    required String title,
    required int moduleId,
    required DateTime deadline,
    required int estimatedHours,
    required String priority,
  }) async {
    final task = Task(
      title: title,
      moduleId: moduleId,
      deadline: deadline,
      estimatedHours: estimatedHours,
      priority: priority,
      isCompleted: false,
    );

    await context.read<AppState>().addTask(task.toMap());
  }

  Future<void> _updateTask({
    required BuildContext context,
    required int id,
    required String title,
    required int moduleId,
    required DateTime deadline,
    required int estimatedHours,
    required String priority,
    required bool isCompleted,
  }) async {
    final task = Task(
      id: id,
      title: title,
      moduleId: moduleId,
      deadline: deadline,
      estimatedHours: estimatedHours,
      priority: priority,
      isCompleted: isCompleted,
    );

    await context.read<AppState>().updateTask(task.toMap());
  }

  Future<void> _deleteTask(BuildContext context, int id) async {
    await context.read<AppState>().deleteTask(id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task deleted.')),
    );
  }

  Future<void> _toggleTaskCompletion(BuildContext context, Task task) async {
    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
    );

    await context.read<AppState>().updateTask(updatedTask.toMap());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedTask.isCompleted
              ? 'Task marked as completed.'
              : 'Task marked as incomplete.',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTask(BuildContext context, Task task) async {
    if (task.id == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Text(
            'Are you sure you want to delete "${task.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && context.mounted) {
      await _deleteTask(context, task.id!);
    }
  }

  void _showNoModulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No Modules Available'),
        content: const Text(
          'Please add a module first before creating a task.',
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

  void _showTaskDialog(
      BuildContext context, {
        required List<Module> modules,
        Task? existingTask,
      }) {
    if (modules.isEmpty) {
      _showNoModulesDialog(context);
      return;
    }

    final isEditing = existingTask != null;
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController(
      text: existingTask?.title ?? '',
    );
    final hoursController = TextEditingController(
      text: existingTask?.estimatedHours.toString() ?? '',
    );

    final matchingModule = existingTask == null
        ? <Module>[]
        : modules.where((m) => m.id == existingTask.moduleId).toList();

    Module selectedModule =
    matchingModule.isNotEmpty ? matchingModule.first : modules.first;

    DateTime selectedDeadline =
    existingTask != null ? existingTask.deadline : _dateOnly(DateTime.now());

    String selectedPriority = existingTask?.priority ?? 'Medium';
    bool isCompleted = existingTask?.isCompleted ?? false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Task' : 'Add Task'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Task Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a task title.';
                          }
                          if (value.trim().length < 3) {
                            return 'Task title must be at least 3 characters.';
                          }
                          return null;
                        },
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
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedModule = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                        ),
                        items: _priorityOptions.map((priority) {
                          return DropdownMenuItem<String>(
                            value: priority,
                            child: Text(priority),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedPriority = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Estimated Hours',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter estimated hours.';
                          }

                          final parsed = int.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Estimated hours must be a whole number.';
                          }
                          if (parsed <= 0) {
                            return 'Estimated hours must be greater than 0.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: isSubmitting
                            ? null
                            : () async {
                          final pickedDate = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDeadline,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );

                          if (pickedDate != null) {
                            setDialogState(() {
                              selectedDeadline = _dateOnly(pickedDate);
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Deadline',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDate(selectedDeadline)),
                              const Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Completed'),
                          value: isCompleted,
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                            setDialogState(() {
                              isCompleted = value;
                            });
                          },
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

                    setDialogState(() {
                      isSubmitting = true;
                    });

                    try {
                      final estimatedHours =
                      int.parse(hoursController.text.trim());

                      if (isEditing) {
                        await _updateTask(
                          context: context,
                          id: existingTask.id!,
                          title: titleController.text.trim(),
                          moduleId: selectedModule.id!,
                          deadline: selectedDeadline,
                          estimatedHours: estimatedHours,
                          priority: selectedPriority,
                          isCompleted: isCompleted,
                        );
                      } else {
                        await _addTask(
                          context: context,
                          title: titleController.text.trim(),
                          moduleId: selectedModule.id!,
                          deadline: selectedDeadline,
                          estimatedHours: estimatedHours,
                          priority: selectedPriority,
                        );
                      }

                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              isEditing
                                  ? 'Task updated successfully.'
                                  : 'Task added successfully.',
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getRiskChipColor(bool isOverdue, bool isAtRisk) {
    if (isOverdue) return Colors.red;
    if (isAtRisk) return Colors.orange;
    return Colors.blueGrey;
  }

  String _getDaysRemainingText(Task task) {
    final today = _dateOnly(DateTime.now());
    final deadlineDate = _dateOnly(task.deadline);
    final daysRemaining = deadlineDate.difference(today).inDays;

    if (daysRemaining < 0) {
      return 'Overdue';
    }
    if (daysRemaining == 0) {
      return 'Due today';
    }
    if (daysRemaining == 1) {
      return 'Due tomorrow';
    }
    return '$daysRemaining days left';
  }

  int _getVisibleAtRiskCount(List<Map<String, dynamic>> tasks) {
    return tasks.where(_isTaskAtRisk).length;
  }

  int _getVisibleCompletedCount(List<Map<String, dynamic>> tasks) {
    return tasks.where((task) => task['isCompleted'] == 1).length;
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final modules = appState.modules.map((map) => Module.fromMap(map)).toList();
    final taskDisplayData = appState.tasksWithModules;
    final visibleTasks = _getFilteredAndSortedTaskData(taskDisplayData);

    if (appState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalVisible = visibleTasks.length;
    final atRiskVisible = _getVisibleAtRiskCount(visibleTasks);
    final completedVisible = _getVisibleCompletedCount(visibleTasks);

    return Stack(
      children: [
        taskDisplayData.isEmpty
            ? const Center(
          child: Text(
            'No tasks yet.\nTap + to add your first task.',
            textAlign: TextAlign.center,
          ),
        )
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildSummaryCard(
                        label: 'Visible Tasks',
                        value: '$totalVisible',
                        icon: Icons.checklist,
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        label: 'At Risk',
                        value: '$atRiskVisible',
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        label: 'Completed',
                        value: '$completedVisible',
                        icon: Icons.task_alt,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tasks, module, code, priority...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _sortOption,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Nearest Deadline',
                        child: Text('Nearest Deadline'),
                      ),
                      DropdownMenuItem(
                        value: 'Highest Priority',
                        child: Text('Highest Priority'),
                      ),
                      DropdownMenuItem(
                        value: 'Highest Workload',
                        child: Text('Highest Workload'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortOption = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Incomplete only'),
                          selected: _showIncompleteOnly,
                          onSelected: (selected) {
                            setState(() {
                              _showIncompleteOnly = selected;
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('At risk only'),
                          selected: _showAtRiskOnly,
                          onSelected: (selected) {
                            setState(() {
                              _showAtRiskOnly = selected;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visibleTasks.isEmpty
                  ? const Center(
                child: Text(
                  'No matching tasks found.',
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: visibleTasks.length,
                itemBuilder: (context, index) {
                  final display = visibleTasks[index];
                  final task = Task.fromMap(display);
                  final moduleName = display['moduleName'] ?? 'Unknown';
                  final moduleCode = display['moduleCode'] ?? '';

                  final today = _dateOnly(DateTime.now());
                  final deadlineDate = _dateOnly(task.deadline);

                  final isOverdue =
                      !task.isCompleted && deadlineDate.isBefore(today);

                  final isAtRisk = _isTaskAtRisk(display);
                  final workloadScore =
                  WorkloadService.calculateSingleTaskWorkloadScoreFromMap(
                    display,
                  );

                  return Card(
                    color: task.isCompleted
                        ? Colors.green.shade50
                        : isOverdue
                        ? Colors.red.shade50
                        : isAtRisk
                        ? Colors.orange.shade50
                        : null,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showTaskDialog(
                        context,
                        modules: modules,
                        existingTask: task,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: task.isCompleted,
                              onChanged: (_) =>
                                  _toggleTaskCompletion(context, task),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isOverdue)
                                        const Padding(
                                          padding:
                                          EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.warning,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                            FontWeight.w600,
                                            decoration: task.isCompleted
                                                ? TextDecoration
                                                .lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      Chip(
                                        label: Text(
                                          _getDaysRemainingText(task),
                                        ),
                                        visualDensity:
                                        VisualDensity.compact,
                                      ),
                                      Chip(
                                        label: Text(
                                          'Score: $workloadScore',
                                        ),
                                        visualDensity:
                                        VisualDensity.compact,
                                      ),
                                      Chip(
                                        label: Text(
                                          task.isCompleted
                                              ? 'Completed'
                                              : isOverdue
                                              ? 'Overdue'
                                              : isAtRisk
                                              ? 'At Risk'
                                              : 'On Track',
                                        ),
                                        backgroundColor: (task
                                            .isCompleted
                                            ? Colors.green
                                            : _getRiskChipColor(
                                          isOverdue,
                                          isAtRisk,
                                        ))
                                            .withOpacity(0.15),
                                        labelStyle: TextStyle(
                                          color: task.isCompleted
                                              ? Colors.green
                                              : _getRiskChipColor(
                                            isOverdue,
                                            isAtRisk,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        visualDensity:
                                        VisualDensity.compact,
                                      ),
                                      Chip(
                                        avatar: Icon(
                                          Icons.flag,
                                          size: 18,
                                          color: _getPriorityColor(
                                            task.priority,
                                          ),
                                        ),
                                        label: Text(task.priority),
                                        visualDensity:
                                        VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '$moduleName ($moduleCode)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Deadline: ${_formatDate(task.deadline)}',
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Estimated Hours: ${task.estimatedHours}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                IconButton(
                                  tooltip: 'Edit task',
                                  onPressed: () => _showTaskDialog(
                                    context,
                                    modules: modules,
                                    existingTask: task,
                                  ),
                                  icon: const Icon(Icons.edit),
                                ),
                                if (task.id != null)
                                  IconButton(
                                    tooltip: 'Delete task',
                                    onPressed: () =>
                                        _confirmDeleteTask(
                                          context,
                                          task,
                                        ),
                                    icon: const Icon(Icons.delete),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showTaskDialog(
              context,
              modules: modules,
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}