/// Represents a proactive check-in or follow-up scheduled by AIRA or agreed with the user.
enum CheckInStatus {
  pending,
  delivered,
  completed,
  snoozed,
  cancelled,
}

enum CheckInCategory {
  agreedCheckin,
  taskFollowup,
  morningPlanning,
  eveningReflection,
  projectContinuation,
}

class CheckInItem {
  final String id;
  final String title;
  final String reason;
  final CheckInCategory category;
  final DateTime targetTime;
  final CheckInStatus status;
  final String? relatedTaskId;
  final String? relatedProject;
  final DateTime? deliveredAt;
  final DateTime? snoozeUntil;
  final DateTime createdAt;
  final String? customPrompt;

  const CheckInItem({
    required this.id,
    required this.title,
    required this.reason,
    this.category = CheckInCategory.agreedCheckin,
    required this.targetTime,
    this.status = CheckInStatus.pending,
    this.relatedTaskId,
    this.relatedProject,
    this.deliveredAt,
    this.snoozeUntil,
    required this.createdAt,
    this.customPrompt,
  });

  bool get isDue {
    if (status == CheckInStatus.completed || status == CheckInStatus.cancelled) {
      return false;
    }
    final now = DateTime.now();
    if (status == CheckInStatus.snoozed && snoozeUntil != null) {
      return now.isAfter(snoozeUntil!);
    }
    return now.isAfter(targetTime);
  }

  CheckInItem copyWith({
    String? title,
    String? reason,
    CheckInCategory? category,
    DateTime? targetTime,
    CheckInStatus? status,
    String? relatedTaskId,
    String? relatedProject,
    DateTime? deliveredAt,
    DateTime? snoozeUntil,
    String? customPrompt,
  }) {
    return CheckInItem(
      id: id,
      title: title ?? this.title,
      reason: reason ?? this.reason,
      category: category ?? this.category,
      targetTime: targetTime ?? this.targetTime,
      status: status ?? this.status,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
      relatedProject: relatedProject ?? this.relatedProject,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      createdAt: createdAt,
      customPrompt: customPrompt ?? this.customPrompt,
    );
  }

  factory CheckInItem.fromJson(Map<String, dynamic> json) {
    return CheckInItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      reason: json['reason'] ?? '',
      category: CheckInCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => CheckInCategory.agreedCheckin,
      ),
      targetTime: json['target_time'] != null
          ? DateTime.tryParse(json['target_time']) ?? DateTime.now()
          : DateTime.now(),
      status: CheckInStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CheckInStatus.pending,
      ),
      relatedTaskId: json['related_task_id'],
      relatedProject: json['related_project'],
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'])
          : null,
      snoozeUntil: json['snooze_until'] != null
          ? DateTime.tryParse(json['snooze_until'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      customPrompt: json['custom_prompt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'reason': reason,
      'category': category.name,
      'target_time': targetTime.toIso8601String(),
      'status': status.name,
      'related_task_id': relatedTaskId,
      'related_project': relatedProject,
      'delivered_at': deliveredAt?.toIso8601String(),
      'snooze_until': snoozeUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'custom_prompt': customPrompt,
    };
  }
}
