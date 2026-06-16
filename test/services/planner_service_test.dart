import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:smart_task_timetable_planner/database/database_helper.dart';
import 'package:smart_task_timetable_planner/repositories/planner_event_repository.dart';
import 'package:smart_task_timetable_planner/repositories/session_repository.dart';
import 'package:smart_task_timetable_planner/repositories/task_repository.dart';
import 'package:smart_task_timetable_planner/services/planner_service.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  late MockDatabaseHelper dbHelper;
  late TaskRepository taskRepository;
  late SessionRepository sessionRepository;
  late PlannerEventRepository plannerEventRepository;
  late PlannerService plannerService;

  setUp(() {
    dbHelper = MockDatabaseHelper();

    taskRepository = TaskRepository(dbHelper: dbHelper);
    sessionRepository = SessionRepository(dbHelper: dbHelper);
    plannerEventRepository = PlannerEventRepository(dbHelper: dbHelper);

    plannerService = PlannerService(
      taskRepository: taskRepository,
      sessionRepository: sessionRepository,
      plannerEventRepository: plannerEventRepository,
    );
  });

  group('PlannerService', () {
    test('buildPlannerPreview returns study plan and generated sessions',
            () async {
          when(() => dbHelper.getTasksWithModules(userId: 1)).thenAnswer(
                (_) async => [
              {
                'title': 'Final Report',
                'moduleId': 1,
                'deadline':
                DateTime.now().add(const Duration(days: 2)).toIso8601String(),
                'estimatedHours': 2,
                'priority': 'High',
                'isCompleted': 0,
              }
            ],
          );

          when(() => dbHelper.getBlockingSessionsWithModules(userId: 1))
              .thenAnswer((_) async => []);

          when(() => dbHelper.getPlannerEvents(userId: 1))
              .thenAnswer((_) async => []);

          final result = await plannerService.buildPlannerPreview(userId: 1);

          expect(result.studyPlan, isNotEmpty);
          expect(result.generatedSessions, isNotEmpty);
          expect(result.hasPreview, isTrue);

          verifyNever(() => dbHelper.replaceGeneratedSessions(
            userId: any(named: 'userId'),
            generatedSessions: any(named: 'generatedSessions'),
          ));
        });

    test('regenerateGeneratedSessionsFromTasks saves generated sessions',
            () async {
          when(() => dbHelper.getTasksWithModules(userId: 1)).thenAnswer(
                (_) async => [
              {
                'title': 'Revision',
                'moduleId': 1,
                'deadline':
                DateTime.now().add(const Duration(days: 1)).toIso8601String(),
                'estimatedHours': 1,
                'priority': 'High',
                'isCompleted': 0,
              }
            ],
          );

          when(() => dbHelper.getBlockingSessionsWithModules(userId: 1))
              .thenAnswer((_) async => []);

          when(() => dbHelper.getPlannerEvents(userId: 1))
              .thenAnswer((_) async => []);

          when(() => dbHelper.replaceGeneratedSessions(
            userId: any(named: 'userId'),
            generatedSessions: any(named: 'generatedSessions'),
          )).thenAnswer((_) async {});

          await plannerService.regenerateGeneratedSessionsFromTasks(userId: 1);

          verify(() => dbHelper.replaceGeneratedSessions(
            userId: 1,
            generatedSessions: any(named: 'generatedSessions'),
          )).called(1);
        });

    test('buildPlannerPreview uses blocking sessions and planner events',
            () async {
          final now = DateTime.now();
          final todayDate =
              '${now.year.toString().padLeft(4, '0')}-'
              '${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}';

          when(() => dbHelper.getTasksWithModules(userId: 1)).thenAnswer(
                (_) async => [
              {
                'title': 'Testing Task',
                'moduleId': 1,
                'deadline':
                DateTime.now().add(const Duration(days: 1)).toIso8601String(),
                'estimatedHours': 1,
                'priority': 'High',
                'isCompleted': 0,
              }
            ],
          );

          when(() => dbHelper.getBlockingSessionsWithModules(userId: 1))
              .thenAnswer(
                (_) async => [
              {
                'date': todayDate,
                'startTime': '09:00',
                'endTime': '10:00',
                'sessionType': 'manual',
              }
            ],
          );

          when(() => dbHelper.getPlannerEvents(userId: 1)).thenAnswer(
                (_) async => [
              {
                'date': todayDate,
                'startTime': '13:00',
                'endTime': '14:00',
              }
            ],
          );

          final result = await plannerService.buildPlannerPreview(userId: 1);

          expect(result.generatedSessions, isNotEmpty);
        });

    test('buildPlannerPreview sorts generated sessions by date then time',
            () async {
          when(() => dbHelper.getTasksWithModules(userId: 1)).thenAnswer(
                (_) async => [
              {
                'title': 'Large Task',
                'moduleId': 1,
                'deadline':
                DateTime.now().add(const Duration(days: 2)).toIso8601String(),
                'estimatedHours': 3,
                'priority': 'High',
                'isCompleted': 0,
              }
            ],
          );

          when(() => dbHelper.getBlockingSessionsWithModules(userId: 1))
              .thenAnswer((_) async => []);

          when(() => dbHelper.getPlannerEvents(userId: 1))
              .thenAnswer((_) async => []);

          final result = await plannerService.buildPlannerPreview(userId: 1);

          expect(result.generatedSessions, isNotEmpty);

          for (int i = 0; i < result.generatedSessions.length - 1; i++) {
            final current = result.generatedSessions[i];
            final next = result.generatedSessions[i + 1];

            final currentDate = current['date'].toString();
            final nextDate = next['date'].toString();

            if (currentDate == nextDate) {
              expect(
                current['startTime']
                    .toString()
                    .compareTo(next['startTime'].toString()) <=
                    0,
                isTrue,
              );
            } else {
              expect(currentDate.compareTo(nextDate) <= 0, isTrue);
            }
          }
        });

    test('preview does not save generated sessions', () async {
      when(() => dbHelper.getTasksWithModules(userId: 1)).thenAnswer(
            (_) async => [
          {
            'title': 'Preview Only Task',
            'moduleId': 1,
            'deadline':
            DateTime.now().add(const Duration(days: 2)).toIso8601String(),
            'estimatedHours': 2,
            'priority': 'Medium',
            'isCompleted': 0,
          }
        ],
      );

      when(() => dbHelper.getBlockingSessionsWithModules(userId: 1))
          .thenAnswer((_) async => []);

      when(() => dbHelper.getPlannerEvents(userId: 1))
          .thenAnswer((_) async => []);

      await plannerService.buildPlannerPreview(userId: 1);

      verifyNever(() => dbHelper.replaceGeneratedSessions(
        userId: any(named: 'userId'),
        generatedSessions: any(named: 'generatedSessions'),
      ));
    });

    test('empty planner inputs return empty preview', () async {
      when(() => dbHelper.getTasksWithModules(userId: 1))
          .thenAnswer((_) async => []);

      when(() => dbHelper.getBlockingSessionsWithModules(userId: 1))
          .thenAnswer((_) async => []);

      when(() => dbHelper.getPlannerEvents(userId: 1))
          .thenAnswer((_) async => []);

      final result = await plannerService.buildPlannerPreview(userId: 1);

      expect(result.studyPlan, isEmpty);
      expect(result.generatedSessions, isEmpty);
      expect(result.hasPreview, isFalse);
    });
  });
}