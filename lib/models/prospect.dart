import 'dart:convert';

class CallAttempt {
  final DateTime timestamp;
  final String verdict; // 'ok', 'non', 'unreachable'
  final String note;

  CallAttempt({
    required this.timestamp,
    required this.verdict,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'verdict': verdict,
      'note': note,
    };
  }

  factory CallAttempt.fromMap(Map<String, dynamic> map) {
    return CallAttempt(
      timestamp: map['timestamp'] != null 
          ? DateTime.parse(map['timestamp']) 
          : DateTime.now(),
      verdict: map['verdict'] ?? '',
      note: map['note'] ?? '',
    );
  }
}

class Suivi {
  final DateTime? date;
  final String resume;

  Suivi({
    this.date,
    this.resume = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date?.toIso8601String(),
      'resume': resume,
    };
  }

  factory Suivi.fromMap(Map<String, dynamic> map) {
    return Suivi(
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      resume: map['resume'] ?? '',
    );
  }
}

class Prospect {
  final String id;
  final String enterpriseId;
  final String agentId;
  final Map<String, String> data; // e.g. {'nom': 'Dupont', 'telephone': '098...'}
  final String status; // 'pending', 'ok', 'non', 'unreachable'
  final List<CallAttempt> callAttempts;
  final List<Suivi> suivis; // Strictly 8 slots
  final String observation;
  final String decision;
  final bool isWhatsApp;
  final DateTime createdAt;
  final bool isSynced; // Local vs Firebase synchronization state

  Prospect({
    required this.id,
    required this.enterpriseId,
    required this.agentId,
    required this.data,
    this.status = 'pending',
    this.callAttempts = const [],
    List<Suivi>? suivis,
    this.observation = '',
    this.decision = '',
    this.isWhatsApp = false,
    required this.createdAt,
    this.isSynced = false,
  }) : suivis = suivis ?? List.generate(8, (_) => Suivi());

  Prospect copyWith({
    String? id,
    String? enterpriseId,
    String? agentId,
    Map<String, String>? data,
    String? status,
    List<CallAttempt>? callAttempts,
    List<Suivi>? suivis,
    String? observation,
    String? decision,
    bool? isWhatsApp,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return Prospect(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      agentId: agentId ?? this.agentId,
      data: data ?? this.data,
      status: status ?? this.status,
      callAttempts: callAttempts ?? this.callAttempts,
      suivis: suivis ?? this.suivis,
      observation: observation ?? this.observation,
      decision: decision ?? this.decision,
      isWhatsApp: isWhatsApp ?? this.isWhatsApp,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'agentId': agentId,
      'data': data,
      'status': status,
      'callAttempts': callAttempts.map((x) => x.toMap()).toList(),
      'suivis': suivis.map((x) => x.toMap()).toList(),
      'observation': observation,
      'decision': decision,
      'isWhatsApp': isWhatsApp,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  factory Prospect.fromMap(Map<String, dynamic> map) {
    return Prospect(
      id: map['id'] ?? '',
      enterpriseId: map['enterpriseId'] ?? '',
      agentId: map['agentId'] ?? '',
      data: Map<String, String>.from(map['data'] ?? {}),
      status: map['status'] ?? 'pending',
      callAttempts: map['callAttempts'] != null
          ? List<CallAttempt>.from(
              map['callAttempts'].map((x) => CallAttempt.fromMap(x)))
          : const [],
      suivis: map['suivis'] != null
          ? List<Suivi>.from(map['suivis'].map((x) => Suivi.fromMap(x)))
          : List.generate(8, (_) => Suivi()),
      observation: map['observation'] ?? '',
      decision: map['decision'] ?? '',
      isWhatsApp: map['isWhatsApp'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      isSynced: map['isSynced'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory Prospect.fromJson(String source) => Prospect.fromMap(json.decode(source));

  // Helper getters
  String get name => '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
  String get phone => data['telephone'] ?? '';
  String get email => data['email'] ?? '';
}
