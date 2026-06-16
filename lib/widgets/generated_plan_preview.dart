import 'package:flutter/material.dart';

class GeneratedPlanPreview extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;

  const GeneratedPlanPreview({
    super.key,
    required this.sessions,
  });

  Map<String, List<Map<String, dynamic>>> _groupSessionsByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final session in sessions) {
      final date = (session['date'] ?? '').toString().trim();
      if (date.isEmpty) continue;

      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(Map<String, dynamic>.from(session));
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return {
      for (final entry in sortedEntries)
        entry.key: _sortSessionsByTime(entry.value),
    };
  }

  List<Map<String, dynamic>> _sortSessionsByTime(
      List<Map<String, dynamic>> daySessions,
      ) {
    final sorted = List<Map<String, dynamic>>.from(daySessions);

    sorted.sort((a, b) {
      final startA = (a['startTime'] ?? '').toString().trim();
      final startB = (b['startTime'] ?? '').toString().trim();
      return startA.compareTo(startB);
    });

    return sorted;
  }

  DateTime? _tryParseDate(String isoDate) {
    try {
      return DateTime.parse(isoDate);
    } catch (_) {
      return null;
    }
  }

  String _formatDisplayDate(String isoDate) {
    final date = _tryParseDate(isoDate);
    if (date == null) return isoDate;

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

    final weekday = _weekdayName(date.weekday);
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString();

    return '$weekday $day $month $year';
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
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

  String _buildTimeRange(Map<String, dynamic> session) {
    final startTime = (session['startTime'] ?? '').toString().trim();
    final endTime = (session['endTime'] ?? '').toString().trim();

    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      return '$startTime - $endTime';
    }

    if (startTime.isNotEmpty) {
      return startTime;
    }

    if (endTime.isNotEmpty) {
      return endTime;
    }

    return 'Time not available';
  }

  String _buildSessionTitle(Map<String, dynamic> session) {
    final title = (session['title'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;

    final taskTitle = (session['taskTitle'] ?? '').toString().trim();
    if (taskTitle.isNotEmpty) return taskTitle;

    return 'Untitled study session';
  }

  String? _buildSessionSubtitle(Map<String, dynamic> session) {
    final moduleName = (session['moduleName'] ?? '').toString().trim();
    final moduleCode = (session['moduleCode'] ?? '').toString().trim();
    final taskTitle = (session['taskTitle'] ?? '').toString().trim();
    final sessionType = (session['sessionType'] ?? '').toString().trim();
    final room = (session['room'] ?? '').toString().trim();
    final notes = (session['notes'] ?? '').toString().trim();

    final moduleDisplay = [
      if (moduleName.isNotEmpty) moduleName,
      if (moduleCode.isNotEmpty) '($moduleCode)',
    ].join(moduleCode.isNotEmpty && moduleName.isNotEmpty ? ' ' : '');

    final title = _buildSessionTitle(session);

    final parts = <String>[
      if (moduleDisplay.isNotEmpty) moduleDisplay,
      if (taskTitle.isNotEmpty && taskTitle != title) taskTitle,
      if (sessionType.isNotEmpty) sessionType,
      if (room.isNotEmpty && room.toLowerCase() != 'generated') room,
      if (notes.isNotEmpty) notes,
    ];

    if (parts.isEmpty) return null;

    return parts.join(' • ');
  }

  double _sessionDurationHours(Map<String, dynamic> session) {
    final startTime = (session['startTime'] ?? '').toString().trim();
    final endTime = (session['endTime'] ?? '').toString().trim();

    if (startTime.isEmpty || endTime.isEmpty) return 0;

    try {
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      if (startParts.length != 2 || endParts.length != 2) return 0;

      final startMinutes =
          (int.parse(startParts[0]) * 60) + int.parse(startParts[1]);
      final endMinutes = (int.parse(endParts[0]) * 60) + int.parse(endParts[1]);

      final durationMinutes = endMinutes - startMinutes;
      if (durationMinutes <= 0) return 0;

      return durationMinutes / 60.0;
    } catch (_) {
      return 0;
    }
  }

  String _formatHours(double hours) {
    if (hours <= 0) return '0h';

    if (hours == hours.roundToDouble()) {
      return '${hours.toInt()}h';
    }

    return '${hours.toStringAsFixed(1)}h';
  }

  String _buildDaySummary(List<Map<String, dynamic>> daySessions) {
    final count = daySessions.length;
    final totalHours = daySessions.fold<double>(
      0,
          (sum, session) => sum + _sessionDurationHours(session),
    );

    final countText =
    count == 1 ? '1 generated session' : '$count generated sessions';
    final hoursText = _formatHours(totalHours);

    return '$countText • $hoursText planned';
  }

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'No generated sessions yet.',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final grouped = _groupSessionsByDate();
    final totalPreviewHours = sessions.fold<double>(
      0,
          (sum, session) => sum + _sessionDurationHours(session),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewSummaryBanner(
          sessionCount: sessions.length,
          totalHoursText: _formatHours(totalPreviewHours),
        ),
        const SizedBox(height: 14),
        ...grouped.entries.map((entry) {
          final isoDate = entry.key;
          final daySessions = entry.value;
          final displayDate = _formatDisplayDate(isoDate);

          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewDateHeader(
                  displayDate: displayDate,
                  isoDate: isoDate,
                  daySummary: _buildDaySummary(daySessions),
                ),
                const SizedBox(height: 10),
                ...daySessions.map(
                      (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GeneratedSessionCard(
                      timeRange: _buildTimeRange(session),
                      title: _buildSessionTitle(session),
                      subtitle: _buildSessionSubtitle(session),
                      durationText:
                      _formatHours(_sessionDurationHours(session)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PreviewSummaryBanner extends StatelessWidget {
  final int sessionCount;
  final String totalHoursText;

  const _PreviewSummaryBanner({
    required this.sessionCount,
    required this.totalHoursText,
  });

  @override
  Widget build(BuildContext context) {
    final sessionText =
    sessionCount == 1 ? '1 preview session' : '$sessionCount preview sessions';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preview Only',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$sessionText • $totalHoursText total planned. These sessions are not saved to the timetable yet.',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewDateHeader extends StatelessWidget {
  final String displayDate;
  final String isoDate;
  final String daySummary;

  const _PreviewDateHeader({
    required this.displayDate,
    required this.isoDate,
    required this.daySummary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayDate,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isoDate,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            daySummary,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedSessionCard extends StatelessWidget {
  final String timeRange;
  final String title;
  final String? subtitle;
  final String durationText;

  const _GeneratedSessionCard({
    required this.timeRange,
    required this.title,
    required this.subtitle,
    required this.durationText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 78),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                ),
                const SizedBox(height: 6),
                Text(
                  timeRange,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  durationText,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Generated Preview',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}