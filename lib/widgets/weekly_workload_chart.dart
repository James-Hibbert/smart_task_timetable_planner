import 'package:flutter/material.dart';

class WeeklyWorkloadChart extends StatelessWidget {
  final Map<String, double> dailyLoad;

  const WeeklyWorkloadChart({
    super.key,
    required this.dailyLoad,
  });

  List<String> _orderedDates() {
    final dates = dailyLoad.keys.toList()
      ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));
    return dates;
  }

  DateTime? _tryParseIsoDate(String isoDate) {
    try {
      return DateTime.parse(isoDate);
    } catch (_) {
      return null;
    }
  }

  String _shortDayNameFromIsoDate(String isoDate) {
    final date = _tryParseIsoDate(isoDate);
    if (date == null) return '';

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

  String _dayNumberFromIsoDate(String isoDate) {
    final date = _tryParseIsoDate(isoDate);
    if (date == null) return '';
    return date.day.toString();
  }

  bool _isToday(String isoDate) {
    final date = _tryParseIsoDate(isoDate);
    if (date == null) return false;

    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatHours(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}h';
    }
    return '${value.toStringAsFixed(1)}h';
  }

  Color _getBarColor(double hours) {
    if (hours >= 6) return Colors.red;
    if (hours >= 4) return Colors.orange;
    if (hours >= 2) return Colors.blue;
    if (hours > 0) return Colors.green;
    return Colors.grey.shade300;
  }

  double _totalHours(List<String> orderedDates) {
    return orderedDates.fold<double>(
      0,
          (sum, date) => sum + (dailyLoad[date] ?? 0),
    );
  }

  double _averageHours(List<String> orderedDates) {
    if (orderedDates.isEmpty) return 0;
    return _totalHours(orderedDates) / orderedDates.length;
  }

  String _busiestDayLabel(List<String> orderedDates) {
    if (orderedDates.isEmpty) return 'N/A';

    String? bestDate;
    double bestValue = -1;

    for (final date in orderedDates) {
      final value = dailyLoad[date] ?? 0;
      if (value > bestValue) {
        bestValue = value;
        bestDate = date;
      }
    }

    if (bestDate == null || bestValue <= 0) {
      return 'No workload';
    }

    return '${_shortDayNameFromIsoDate(bestDate)} ${_dayNumberFromIsoDate(bestDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final orderedDates = _orderedDates();

    final maxValue = orderedDates
        .map((date) => dailyLoad[date] ?? 0)
        .fold<double>(0, (max, value) => value > max ? value : max);

    final totalHours = _totalHours(orderedDates);
    final averageHours = _averageHours(orderedDates);
    final busiestDay = _busiestDayLabel(orderedDates);

    const trackHeight = 130.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.insights),
                SizedBox(width: 8),
                Text(
                  'Weekly Workload Chart',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ChartStatItem(
                    label: 'Total',
                    value: _formatHours(totalHours),
                  ),
                ),
                Expanded(
                  child: _ChartStatItem(
                    label: 'Average',
                    value: _formatHours(averageHours),
                  ),
                ),
                Expanded(
                  child: _ChartStatItem(
                    label: 'Busiest Day',
                    value: busiestDay,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (orderedDates.isEmpty || maxValue == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No weekly workload data yet.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: orderedDates.map((date) {
                    final value = dailyLoad[date] ?? 0;
                    final heightFactor = maxValue == 0 ? 0.0 : value / maxValue;
                    final barHeight = trackHeight * heightFactor.clamp(0.0, 1.0);
                    final isToday = _isToday(date);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _formatHours(value),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isToday ? Colors.blue.shade700 : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: trackHeight,
                              alignment: Alignment.bottomCenter,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isToday
                                      ? Colors.blue.shade200
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Container(
                                height: value == 0 ? 4 : barHeight,
                                decoration: BoxDecoration(
                                  color: _getBarColor(value),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Colors.blue.shade50
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _shortDayNameFromIsoDate(date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isToday
                                          ? Colors.blue.shade700
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    _dayNumberFromIsoDate(date),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isToday
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade700,
                                      fontWeight: isToday
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: const [
                _LegendItem(color: Colors.green, label: 'Low'),
                _LegendItem(color: Colors.blue, label: 'Moderate'),
                _LegendItem(color: Colors.orange, label: 'High'),
                _LegendItem(color: Colors.red, label: 'Critical'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _ChartStatItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}