class Task {
  final int? id;
  final String title;
  final int moduleId;
  final DateTime deadline;
  final int estimatedHours;
  final String priority;
  final bool isCompleted;

  Task({
    this.id,
    required this.title,
    required this.moduleId,
    required this.deadline,
    required this.estimatedHours,
    required this.priority,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'moduleId': moduleId,
      'deadline': deadline.toIso8601String(),
      'estimatedHours': estimatedHours,
      'priority': priority,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      moduleId: map['moduleId'],
      deadline: DateTime.parse(map['deadline']),
      estimatedHours: map['estimatedHours'],
      priority: map['priority'],
      isCompleted: map['isCompleted'] == 1,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    int? moduleId,
    DateTime? deadline,
    int? estimatedHours,
    String? priority,
    bool? isCompleted,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      moduleId: moduleId ?? this.moduleId,
      deadline: deadline ?? this.deadline,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}