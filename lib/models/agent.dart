import 'dart:convert';

class Agent {
  final String id;
  final String enterpriseId;
  final String name;
  final String email;
  final DateTime createdAt;
  final bool isActive;

  Agent({
    required this.id,
    required this.enterpriseId,
    required this.name,
    required this.email,
    required this.createdAt,
    this.isActive = true,
  });

  Agent copyWith({
    String? id,
    String? enterpriseId,
    String? name,
    String? email,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return Agent(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'name': name,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory Agent.fromMap(Map<String, dynamic> map) {
    return Agent(
      id: map['id'] ?? '',
      enterpriseId: map['enterpriseId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory Agent.fromJson(String source) => Agent.fromMap(json.decode(source));
}
