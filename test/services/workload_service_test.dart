import 'package:flutter_test/flutter_test.dart';
import 'package:smart_task_timetable_planner/services/workload_service.dart';

void main() {
  group('WorkloadService', () {
    test('calculateSingleTaskWorkloadScoreFromMap returns 0 for completed task',
            () {
          final task = {
            'title': 'Report',
            'deadline': DateTime.now()
                .add(const Duration(days: 5))
                .toIso8601String(),
            'estimatedHours': 5,
            'priority': 'High',
            'isCompleted': 1,
          };

          final score =
          WorkloadService.calculateSingleTaskWorkloadScoreFromMap(task);

          expect(score, 0);
        });

    // Verifies that completed tasks are excluded from generated study plans
    test('generateStudyPlanFromMaps excludes completed tasks', () {
      final taskMaps = [
        {
          'title': 'Completed Task',
          'moduleId': 1,
          'deadline': DateTime.now()
              .add(const Duration(days: 3))
              .toIso8601String(),
          'estimatedHours': 4,
          'priority': 'High',
          'isCompleted': 1,
        },
        {
          'title': 'Active Task',
          'moduleId': 1,
          'deadline': DateTime.now()
              .add(const Duration(days: 3))
              .toIso8601String(),
          'estimatedHours': 4,
          'priority': 'High',
          'isCompleted': 0,
        },
      ];

      final plan = WorkloadService.generateStudyPlanFromMaps(taskMaps);
      final allItems = plan.values.expand((items) => items).toList();

      expect(allItems.any((item) => item.contains('Completed Task')), isFalse);
      expect(allItems.any((item) => item.contains('Active Task')), isTrue);
    });

    test('generateStudyPlanFromMaps distributes work across multiple days', () {
      final taskMaps = [
        {
          'title': 'Dissertation',
          'moduleId': 1,
          'deadline': DateTime.now()
              .add(const Duration(days: 4))
              .toIso8601String(),
          'estimatedHours': 6,
          'priority': 'Medium',
          'isCompleted': 0,
        },
      ];

      final plan = WorkloadService.generateStudyPlanFromMaps(taskMaps);

      final nonEmptyDays =
          plan.entries.where((entry) => entry.value.isNotEmpty).length;

      expect(nonEmptyDays, greaterThan(1));
    });

    test('generateSessionBlocksFromTaskMaps creates session blocks', () {
      final taskMaps = [
        {
          'title': 'Coursework',
          'moduleId': 2,
          'deadline': DateTime.now()
              .add(const Duration(days: 2))
              .toIso8601String(),
          'estimatedHours': 2,
          'priority': 'High',
          'isCompleted': 0,
        },
      ];

      final sessions =
      WorkloadService.generateSessionBlocksFromTaskMaps(taskMaps);

      expect(sessions, isNotEmpty);
      expect(sessions.first['title'], 'Coursework');
      expect(sessions.first['date'], isNotNull);
      expect(sessions.first['startTime'], isNotNull);
      expect(sessions.first['endTime'], isNotNull);
    });

    test('generateSessionBlocksFromTaskMaps respects blocking sessions', () {
      final now = DateTime.now();
      final todayDate =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final taskMaps = [
        {
          'title': 'Revision',
          'moduleId': 1,
          'deadline':
          DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'estimatedHours': 1,
          'priority': 'High',
          'isCompleted': 0,
        },
      ];

      final existingSessions = [
        {
          'date': todayDate,
          'startTime': '09:00',
          'endTime': '10:00',
        }
      ];

      final sessions = WorkloadService.generateSessionBlocksFromTaskMaps(
        taskMaps,
        existingSessionMaps: existingSessions,
      );

      expect(sessions, isNotEmpty);

      final firstSessionStart = sessions.first['startTime'] as String;
      expect(firstSessionStart, isNot('09:00'));
      expect(firstSessionStart, isNot('10:00'));
    });

    test('classifyWorkload returns expected labels', () {
      expect(WorkloadService.classifyWorkload(1.5), 'Low');
      expect(WorkloadService.classifyWorkload(3.0), 'Moderate');
      expect(WorkloadService.classifyWorkload(5.0), 'High');
      expect(WorkloadService.classifyWorkload(6.5), 'Critical');
    });

    test('getRiskWarningsFromMaps detects overdue tasks', () {
      final taskMaps = [
        {
          'title': 'Late Submission',
          'moduleId': 1,
          'deadline':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'estimatedHours': 5,
          'priority': 'High',
          'isCompleted': 0,
        },
      ];

      final warnings = WorkloadService.getRiskWarningsFromMaps(taskMaps);

      expect(warnings, isNotEmpty);
      expect(
        warnings.any((warning) => warning.contains('Late Submission is overdue')),
        isTrue,
      );
    });

    test('no tasks returns empty study plan', () {
      final plan = WorkloadService.generateStudyPlanFromMaps([]);
      expect(plan.isEmpty, true);
    });

    test('all completed tasks return empty study plan', () {
      final taskMaps = [
        {
          'title': 'Finished Coursework',
          'moduleId': 1,
          'deadline':
          DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'estimatedHours': 3,
          'priority': 'Medium',
          'isCompleted': 1,
        }
      ];

      final plan = WorkloadService.generateStudyPlanFromMaps(taskMaps);

      final hasAnyItems = plan.values.any((items) => items.isNotEmpty);
      expect(hasAnyItems, false);
    });
  });
}