class FileTracking {
  final String fileId;
  final String currentStage;
  final FileStages stages;
  final bool isDelayed;
  final DateTime? slaDeadline;

  FileTracking({
    required this.fileId,
    required this.currentStage,
    required this.stages,
    required this.isDelayed,
    this.slaDeadline,
  });

  factory FileTracking.fromJson(Map<String, dynamic> json) {
    return FileTracking(
      fileId: json['file_id'],
      currentStage: json['current_stage'],
      stages: FileStages.fromJson(json['stages']),
      isDelayed: json['is_delayed'] ?? false,
      slaDeadline: json['sla_deadline'] != null
          ? DateTime.parse(json['sla_deadline'])
          : null,
    );
  }
}

class FileStages {
  final FileStage initiated;
  final FileStage verified;
  final FileStage approved;
  final FileStage closed;

  FileStages({
    required this.initiated,
    required this.verified,
    required this.approved,
    required this.closed,
  });

  factory FileStages.fromJson(Map<String, dynamic> json) {
    return FileStages(
      initiated: FileStage.fromJson(json['initiated'] ?? {}),
      verified: FileStage.fromJson(json['verified'] ?? {}),
      approved: FileStage.fromJson(json['approved'] ?? {}),
      closed: FileStage.fromJson(json['closed'] ?? {}),
    );
  }
}

class FileStage {
  final bool completed;
  final DateTime? timestamp;
  final String? actorId;

  FileStage({required this.completed, this.timestamp, this.actorId});

  factory FileStage.fromJson(Map<String, dynamic> json) {
    return FileStage(
      completed: json['completed'] ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : null,
      actorId: json['actor_id'],
    );
  }
}
