import 'dart:convert';

class ProspectFieldSetting {
  final String id;
  final String label;
  final bool required;
  final bool enabled;

  ProspectFieldSetting({
    required this.id,
    required this.label,
    required this.required,
    required this.enabled,
  });

  ProspectFieldSetting copyWith({
    String? id,
    String? label,
    bool? required,
    bool? enabled,
  }) {
    return ProspectFieldSetting(
      id: id ?? this.id,
      label: label ?? this.label,
      required: required ?? this.required,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'required': required,
      'enabled': enabled,
    };
  }

  factory ProspectFieldSetting.fromMap(Map<String, dynamic> map) {
    return ProspectFieldSetting(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      required: map['required'] ?? false,
      enabled: map['enabled'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory ProspectFieldSetting.fromJson(String source) => ProspectFieldSetting.fromMap(json.decode(source));
}

class MessageTemplate {
  final String id;
  final String title;
  final String content;

  MessageTemplate({
    required this.id,
    required this.title,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
    };
  }

  factory MessageTemplate.fromMap(Map<String, dynamic> map) {
    return MessageTemplate(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
    );
  }
}

class Enterprise {
  final String id;
  final String name;
  final String email;
  final String? logoUrl;
  final List<ProspectFieldSetting> formSettings;
  final Map<String, int> dailyEmailCounters;
  final List<String> adminNotifications;
  final List<MessageTemplate> messageTemplates;
  final String defaultCountryCode; // e.g., "229" for Benin
  final bool autoAssignToAgent; // If true, prospects added by agents are auto-assigned for follow-up
  final List<String> customVerdicts; // Custom call outcomes defined by enterprise

  Enterprise({
    required this.id,
    required this.name,
    required this.email,
    this.logoUrl,
    required this.formSettings,
    this.dailyEmailCounters = const {},
    this.adminNotifications = const [],
    this.messageTemplates = const [],
    this.defaultCountryCode = '229',
    this.autoAssignToAgent = false,
    this.customVerdicts = const [],
  });

  static List<String> get platformDefaultVerdicts => [
    'Succès',
    'Refus',
    'Injoignable',
    'En attente',
    'Rendez-vous',
  ];

  static List<ProspectFieldSetting> get defaultSettings => [
    ProspectFieldSetting(id: 'nom', label: 'Nom', required: true, enabled: true),
    ProspectFieldSetting(id: 'prenom', label: 'Prénom', required: true, enabled: true),
    ProspectFieldSetting(id: 'telephone', label: 'Numéro de Téléphone', required: true, enabled: true),
    ProspectFieldSetting(id: 'numeroWhatsApp', label: 'Numéro WhatsApp', required: false, enabled: false),
    ProspectFieldSetting(id: 'email', label: 'Email', required: false, enabled: true),
    ProspectFieldSetting(id: 'entreprise', label: 'Entreprise prospectée', required: false, enabled: true),
    ProspectFieldSetting(id: 'note', label: 'Note / Commentaire', required: false, enabled: true),
  ];

  Enterprise copyWith({
    String? id,
    String? name,
    String? email,
    String? logoUrl,
    List<ProspectFieldSetting>? formSettings,
    Map<String, int>? dailyEmailCounters,
    List<String>? adminNotifications,
    List<MessageTemplate>? messageTemplates,
    String? defaultCountryCode,
    bool? autoAssignToAgent,
    List<String>? customVerdicts,
  }) {
    return Enterprise(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      formSettings: formSettings ?? this.formSettings,
      dailyEmailCounters: dailyEmailCounters ?? this.dailyEmailCounters,
      adminNotifications: adminNotifications ?? this.adminNotifications,
      messageTemplates: messageTemplates ?? this.messageTemplates,
      defaultCountryCode: defaultCountryCode ?? this.defaultCountryCode,
      autoAssignToAgent: autoAssignToAgent ?? this.autoAssignToAgent,
      customVerdicts: customVerdicts ?? this.customVerdicts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'logoUrl': logoUrl,
      'formSettings': formSettings.map((s) => s.toMap()).toList(),
      'dailyEmailCounters': dailyEmailCounters,
      'adminNotifications': adminNotifications,
      'messageTemplates': messageTemplates.map((t) => t.toMap()).toList(),
      'defaultCountryCode': defaultCountryCode,
      'autoAssignToAgent': autoAssignToAgent,
      'customVerdicts': customVerdicts,
    };
  }

  factory Enterprise.fromMap(Map<String, dynamic> map) {
    return Enterprise(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      logoUrl: map['logoUrl'],
      formSettings: map['formSettings'] != null
          ? List<ProspectFieldSetting>.from(
              map['formSettings'].map((x) => ProspectFieldSetting.fromMap(x)))
          : defaultSettings,
      dailyEmailCounters: Map<String, int>.from(map['dailyEmailCounters'] ?? {}),
      adminNotifications: List<String>.from(map['adminNotifications'] ?? []),
      messageTemplates: map['messageTemplates'] != null
          ? List<MessageTemplate>.from(
              map['messageTemplates'].map((x) => MessageTemplate.fromMap(x)))
          : const [],
      defaultCountryCode: map['defaultCountryCode'] ?? '229',
      autoAssignToAgent: map['autoAssignToAgent'] ?? false,
      customVerdicts: List<String>.from(map['customVerdicts'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());

  factory Enterprise.fromJson(String source) => Enterprise.fromMap(json.decode(source));
}
