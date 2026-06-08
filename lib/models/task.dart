import 'dart:convert';

class Task {
  final String id;
  final String enterpriseId;
  final String agentId;
  final List<String> prospectIds;
  final String status; // 'pending', 'completed'
  final DateTime assignedAt;

  Task({
    required this.id,
    required this.enterpriseId,
    required this.agentId,
    required this.prospectIds,
    this.status = 'pending',
    required this.assignedAt,
  });

  Task copyWith({
    String? id,
    String? enterpriseId,
    String? agentId,
    List<String>? prospectIds,
    String? status,
    DateTime? assignedAt,
  }) {
    return Task(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      agentId: agentId ?? this.agentId,
      prospectIds: prospectIds ?? this.prospectIds,
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'agentId': agentId,
      'prospectIds': prospectIds,
      'status': status,
      'assignedAt': assignedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      enterpriseId: map['enterpriseId'] ?? '',
      agentId: map['agentId'] ?? '',
      prospectIds: List<String>.from(map['prospectIds'] ?? []),
      status: map['status'] ?? 'pending',
      assignedAt: map['assignedAt'] != null
          ? DateTime.parse(map['assignedAt'])
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));
}
