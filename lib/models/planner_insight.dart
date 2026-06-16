enum InsightType {
  warning,
  recommendation,
  positive,
  info,
}

class PlannerInsight {
  final String title;
  final String message;
  final InsightType type;

  final String? reason;
  final String? action;

  final String? actionLabel;
  final String? actionKey;

  final double confidence;
  final String? explanation;

  const PlannerInsight({
    required this.title,
    required this.message,
    required this.type,
    this.reason,
    this.action,
    this.actionLabel,
    this.actionKey,
    this.confidence = 0.5,
    this.explanation,
  });

  bool get hasAction =>
      actionLabel != null &&
          actionLabel!.trim().isNotEmpty &&
          actionKey != null &&
          actionKey!.trim().isNotEmpty;

  bool get hasExplanation =>
      explanation != null && explanation!.trim().isNotEmpty;

  bool get hasReason => reason != null && reason!.trim().isNotEmpty;
}