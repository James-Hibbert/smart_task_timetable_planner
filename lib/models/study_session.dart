class StudySession {
  final int? id;
  final int? userId;
  final int moduleId;
  final String? title;
  final String date;
  final String startTime;
  final String endTime;
  final String room;
  final String sessionType;

  final bool isRecurring;
  final String recurrencePattern;
  final String recurrenceDays;
  final String? recurrenceEndDate;

  static const String manualType = 'manual';
  static const String generatedType = 'generated';

  static const String recurrenceNone = 'none';
  static const String recurrenceWeekly = 'weekly';

  StudySession({
    this.id,
    this.userId,
    required this.moduleId,
    this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.room,
    this.sessionType = manualType,
    this.isRecurring = false,
    this.recurrencePattern = recurrenceNone,
    this.recurrenceDays = '',
    this.recurrenceEndDate,
  });

  bool get isManual => sessionType == manualType;
  bool get isGenerated => sessionType == generatedType;

  List<int> get recurrenceDayList {
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
      'userId': userId,
      'moduleId': moduleId,
      'title': title,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'sessionType': sessionType,
      'isRecurring': isRecurring ? 1 : 0,
      'recurrencePattern': recurrencePattern,
      'recurrenceDays': recurrenceDays,
      'recurrenceEndDate': recurrenceEndDate,
    };
  }

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as int?,
      userId: map['userId'] as int?,
      moduleId: map['moduleId'] is int
          ? map['moduleId'] as int
          : int.tryParse(map['moduleId'].toString()) ?? 0,
      title: map['title']?.toString(),
      date: map['date'].toString(),
      startTime: map['startTime'].toString(),
      endTime: map['endTime'].toString(),
      room: map['room'].toString(),
      sessionType: (map['sessionType'] ?? manualType).toString(),
      isRecurring: map['isRecurring'] == 1 || map['isRecurring'] == true,
      recurrencePattern:
      (map['recurrencePattern'] ?? recurrenceNone).toString(),
      recurrenceDays: (map['recurrenceDays'] ?? '').toString(),
      recurrenceEndDate: map['recurrenceEndDate']?.toString(),
    );
  }

  StudySession copyWith({
    int? id,
    int? userId,
    int? moduleId,
    String? title,
    String? date,
    String? startTime,
    String? endTime,
    String? room,
    String? sessionType,
    bool? isRecurring,
    String? recurrencePattern,
    String? recurrenceDays,
    String? recurrenceEndDate,
  }) {
    return StudySession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      sessionType: sessionType ?? this.sessionType,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
    );
  }
}