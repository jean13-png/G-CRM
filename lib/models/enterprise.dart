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
  final String brevoApiKey;
  final String brevoSenderEmail;
  final List<MessageTemplate> messageTemplates;

  Enterprise({
    required this.id,
    required this.name,
    required this.email,
    this.logoUrl,
    required this.formSettings,
    this.dailyEmailCounters = const {},
    this.adminNotifications = const [],
    this.brevoApiKey = '',
    this.brevoSenderEmail = '',
    this.messageTemplates = const [],
  });

  static List<ProspectFieldSetting> get defaultSettings => [
    ProspectFieldSetting(id: 'nom', label: 'Nom', required: true, enabled: true),
    ProspectFieldSetting(id: 'prenom', label: 'Prénom', required: true, enabled: true),
    ProspectFieldSetting(id: 'telephone', label: 'Téléphone', required: true, enabled: true),
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
    String? brevoApiKey,
    String? brevoSenderEmail,
    List<MessageTemplate>? messageTemplates,
  }) {
    return Enterprise(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      formSettings: formSettings ?? this.formSettings,
      dailyEmailCounters: dailyEmailCounters ?? this.dailyEmailCounters,
      adminNotifications: adminNotifications ?? this.adminNotifications,
      brevoApiKey: brevoApiKey ?? this.brevoApiKey,
      brevoSenderEmail: brevoSenderEmail ?? this.brevoSenderEmail,
      messageTemplates: messageTemplates ?? this.messageTemplates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'logoUrl': logoUrl,
      'formSettings': formSettings.map((x) => x.toMap()).toList(),
      'dailyEmailCounters': dailyEmailCounters,
      'adminNotifications': adminNotifications,
      'brevoApiKey': brevoApiKey,
      'brevoSenderEmail': brevoSenderEmail,
      'messageTemplates': messageTemplates.map((x) => x.toMap()).toList(),
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
      brevoApiKey: map['brevoApiKey'] ?? '',
      brevoSenderEmail: map['brevoSenderEmail'] ?? '',
      messageTemplates: map['messageTemplates'] != null
          ? List<MessageTemplate>.from(
              map['messageTemplates'].map((x) => MessageTemplate.fromMap(x)))
          : const [],
    );
  }

  String toJson() => json.encode(toMap());

  factory Enterprise.fromJson(String source) => Enterprise.fromMap(json.decode(source));
}
