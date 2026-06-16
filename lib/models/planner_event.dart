class PlannerEvent {
  final int? id;
  final String title;
  final String date;
  final String startTime;
  final String endTime;
  final String type;

  final bool isRecurring;
  final String recurrencePattern; // 'none' or 'weekly'
  final String recurrenceDays; // e.g. '1,3,5'
  final String? recurrenceEndDate;

  static const String recurrenceNone = 'none';
  static const String recurrenceWeekly = 'weekly';

  PlannerEvent({
    this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.isRecurring = false,
    this.recurrencePattern = recurrenceNone,
    this.recurrenceDays = '',
    this.recurrenceEndDate,
  });

  List<int> get recurrenceDayList {
    if (recurrenceDays.trim().isEmpty) return [];

    return recurrenceDays
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'type': type,
      'isRecurring': isRecurring ? 1 : 0,
      'recurrencePattern': recurrencePattern,
      'recurrenceDays': recurrenceDays,
      'recurrenceEndDate': recurrenceEndDate,
    };
  }

  factory PlannerEvent.fromMap(Map<String, dynamic> map) {
    return PlannerEvent(
      id: map['id'],
      title: (map['title'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      startTime: (map['startTime'] ?? '').toString(),
      endTime: (map['endTime'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      isRecurring: map['isRecurring'] == 1 || map['isRecurring'] == true,
      recurrencePattern:
      (map['recurrencePattern'] ?? recurrenceNone).toString(),
      recurrenceDays: (map['recurrenceDays'] ?? '').toString(),
      recurrenceEndDate: map['recurrenceEndDate']?.toString(),
    );
  }

  PlannerEvent copyWith({
    int? id,
    String? title,
    String? date,
    String? startTime,
    String? endTime,
    String? type,
    bool? isRecurring,
    String? recurrencePattern,
    String? recurrenceDays,
    String? recurrenceEndDate,
  }) {
    return PlannerEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
    );
  }
}