import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import '../models/enterprise.dart';
import '../models/agent.dart';
import '../models/prospect.dart';
import '../models/task.dart';
import '../models/chat_message.dart';
import '../models/app_notification.dart';


class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Active session state
  Enterprise? _currentEnterprise;
  Agent? _currentAgent;
  String? _currentUserRole; // 'enterprise' or 'agent'

  // Collections (In-Memory database)
  final Map<String, Enterprise> _enterprises = {};
  final Map<String, Agent> _agents = {};
  final Map<String, Prospect> _prospects = {};
  final Map<String, Task> _tasks = {};
  final List<ChatMessage> _chatMessages = [];
  final List<AppNotification> _notifications = [];

  // For credentials matching in offline/mock mode
  // key: email, value: {password, id, role}
  final Map<String, Map<String, String>> _credentials = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Getters
  Enterprise? get currentEnterprise => _currentEnterprise;
  Agent? get currentAgent => _currentAgent;
  String? get currentUserRole => _currentUserRole;
  bool get isLoggedIn => _currentEnterprise != null || _currentAgent != null;

  List<Enterprise> get allEnterprises => _enterprises.values.toList();
  List<Agent> get allAgents => _agents.values.toList();
  List<Prospect> get allProspects => _prospects.values.toList();
  List<Task> get allTasks => _tasks.values.toList();
  List<ChatMessage> get allChatMessages => List.unmodifiable(_chatMessages);
  List<AppNotification> get allNotifications => List.unmodifiable(_notifications);

  // Get path to local database file
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/g_crm_database.json');
  }

  // Initialize service & load local database
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final data = json.decode(jsonString);

        // Load Enterprises
        if (data['enterprises'] != null) {
          final Map<String, dynamic> ents = data['enterprises'];
          ents.forEach((k, v) {
            _enterprises[k] = Enterprise.fromMap(v);
          });
        }

        // Load Agents
        if (data['agents'] != null) {
          final Map<String, dynamic> ags = data['agents'];
          ags.forEach((k, v) {
            _agents[k] = Agent.fromMap(v);
          });
        }

        // Load Prospects
        if (data['prospects'] != null) {
          final Map<String, dynamic> pros = data['prospects'];
          pros.forEach((k, v) {
            _prospects[k] = Prospect.fromMap(v);
          });
        }

        // Load Tasks
        if (data['tasks'] != null) {
          final Map<String, dynamic> tks = data['tasks'];
          tks.forEach((k, v) {
            _tasks[k] = Task.fromMap(v);
          });
        }

        // Load Chat Messages
        if (data['chatMessages'] != null) {
          final List<dynamic> chats = data['chatMessages'];
          for (var v in chats) {
            _chatMessages.add(ChatMessage.fromMap(v));
          }
        }

        // Load Notifications
        if (data['notifications'] != null) {
          final List<dynamic> notifs = data['notifications'];
          for (var v in notifs) {
            _notifications.add(AppNotification.fromMap(v));
          }
        }

        // Load Credentials
        if (data['credentials'] != null) {
          final Map<String, dynamic> creds = data['credentials'];
          creds.forEach((k, v) {
            _credentials[k] = Map<String, String>.from(v);
          });
        }
      } else {
        // Initialize with demo data if empty
        _loadDemoData();
        await saveToDisk();
      }
    } catch (e) {
      debugPrint("Error loading local database: $e");
      _loadDemoData();
    }
    _initialized = true;
    notifyListeners();
  }

  // Save memory database to disk
  Future<void> saveToDisk() async {
    try {
      final file = await _localFile;
      final Map<String, dynamic> dbDump = {
        'enterprises': _enterprises.map((k, v) => MapEntry(k, v.toMap())),
        'agents': _agents.map((k, v) => MapEntry(k, v.toMap())),
        'prospects': _prospects.map((k, v) => MapEntry(k, v.toMap())),
        'tasks': _tasks.map((k, v) => MapEntry(k, v.toMap())),
        'chatMessages': _chatMessages.map((v) => v.toMap()).toList(),
        'notifications': _notifications.map((v) => v.toMap()).toList(),
        'credentials': _credentials,
      };
      await file.writeAsString(json.encode(dbDump), flush: true);
    } catch (e) {
      debugPrint("Error writing database to disk: $e");
    }
  }

  // Load sample demo data
  void _loadDemoData() {
    // Demo enterprise
    final entId = "demo_enterprise";
    final demoEnt = Enterprise(
      id: entId,
      name: "Sup'Elite Formation",
      email: "direction@supelite.com",
      formSettings: Enterprise.defaultSettings,
    );
    _enterprises[entId] = demoEnt;
    _credentials["direction@supelite.com"] = {
      "password": "password",
      "id": entId,
      "role": "enterprise",
    };

    // Demo agents
    final agentId1 = "agent_1";
    final demoAgent1 = Agent(
      id: agentId1,
      enterpriseId: entId,
      name: "Koffi Mensah",
      email: "koffi@supelite.com",
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );
    _agents[agentId1] = demoAgent1;
    _credentials["koffi@supelite.com"] = {
      "password": "password",
      "id": agentId1,
      "role": "agent",
    };

    final agentId2 = "agent_2";
    final demoAgent2 = Agent(
      id: agentId2,
      enterpriseId: entId,
      name: "Awa Diop",
      email: "awa@supelite.com",
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    );
    _agents[agentId2] = demoAgent2;
    _credentials["awa@supelite.com"] = {
      "password": "password",
      "id": agentId2,
      "role": "agent",
    };

    // Demo prospects
    final p1 = Prospect(
      id: "p1",
      enterpriseId: entId,
      agentId: agentId1,
      data: {
        "nom": "Soglo",
        "prenom": "Hubert",
        "telephone": "+22997000001",
        "email": "hubert.soglo@example.com",
        "entreprise": "Soglo Services",
        "note": "Intéressé par formation management"
      },
      status: "pending",
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    _prospects[p1.id] = p1;

    final p2 = Prospect(
      id: "p2",
      enterpriseId: entId,
      agentId: agentId1,
      data: {
        "nom": "Toure",
        "prenom": "Aminata",
        "telephone": "+22997000002",
        "email": "aminata@example.com",
        "entreprise": "Toure Shop",
        "note": "Rappeler le soir"
      },
      status: "unreachable",
      callAttempts: [
        CallAttempt(
          timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          verdict: 'unreachable',
          note: 'Numéro sonne mais pas de réponse',
        )
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    _prospects[p2.id] = p2;

    final p3 = Prospect(
      id: "p3",
      enterpriseId: entId,
      agentId: agentId1,
      data: {
        "nom": "Gomez",
        "prenom": "Carlos",
        "telephone": "+22997000003",
        "email": "",
        "entreprise": "Atelier Gomez",
        "note": "Pas intéressé pour le moment"
      },
      status: "non",
      callAttempts: [
        CallAttempt(
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          verdict: 'non',
          note: 'Trop cher',
        )
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    _prospects[p3.id] = p3;

    // Demo tasks
    final t1 = Task(
      id: "task_demo_1",
      enterpriseId: entId,
      agentId: agentId1,
      prospectIds: ["p1", "p2", "p3"],
      assignedAt: DateTime.now().subtract(const Duration(days: 1)),
      status: "pending",
    );
    _tasks[t1.id] = t1;
  }

  // ================= AUTHENTICATION ACTIONS =================

  Future<bool> signIn(String email, String password, String role) async {
    final credentials = _credentials[email.trim().toLowerCase()];
    if (credentials != null &&
        credentials['password'] == password &&
        credentials['role'] == role) {
      _currentUserRole = role;
      if (role == 'enterprise') {
        _currentEnterprise = _enterprises[credentials['id']];
        _currentAgent = null;
      } else {
        _currentAgent = _agents[credentials['id']];
        _currentEnterprise = _enterprises[_currentAgent?.enterpriseId];
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> signUpEnterprise(String name, String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (_credentials.containsKey(cleanEmail)) {
      return false; // Email already in use
    }

    final newId = "enterprise_${DateTime.now().millisecondsSinceEpoch}";
    final enterprise = Enterprise(
      id: newId,
      name: name.trim(),
      email: cleanEmail,
      formSettings: Enterprise.defaultSettings,
    );

    _enterprises[newId] = enterprise;
    _credentials[cleanEmail] = {
      "password": password,
      "id": newId,
      "role": "enterprise",
    };

    _currentUserRole = 'enterprise';
    _currentEnterprise = enterprise;
    _currentAgent = null;

    await saveToDisk();
    notifyListeners();
    return true;
  }

  void signOut() {
    _currentEnterprise = null;
    _currentAgent = null;
    _currentUserRole = null;
    notifyListeners();
  }

  // ================= ENTERPRISE ACTIONS =================

  // Add agent
  Future<bool> createAgent(String name, String email, String password) async {
    if (_currentEnterprise == null) return false;
    final cleanEmail = email.trim().toLowerCase();
    if (_credentials.containsKey(cleanEmail)) return false;

    final agentId = "agent_${DateTime.now().millisecondsSinceEpoch}";
    final agent = Agent(
      id: agentId,
      enterpriseId: _currentEnterprise!.id,
      name: name.trim(),
      email: cleanEmail,
      createdAt: DateTime.now(),
    );

    _agents[agentId] = agent;
    _credentials[cleanEmail] = {
      "password": password,
      "id": agentId,
      "role": "agent",
    };

    await saveToDisk();
    notifyListeners();
    return true;
  }

  // Get agents for current enterprise
  List<Agent> getAgentsForCurrentEnterprise() {
    if (_currentEnterprise == null) return [];
    return _agents.values
        .where((x) => x.enterpriseId == _currentEnterprise!.id)
        .toList();
  }

  // Update dynamic form configuration
  Future<void> updateFormSettings(List<ProspectFieldSetting> settings) async {
    if (_currentEnterprise == null) return;
    final updated = _currentEnterprise!.copyWith(formSettings: settings);
    _enterprises[updated.id] = updated;
    _currentEnterprise = updated;
    await saveToDisk();
    notifyListeners();
  }

  // Manage Message Templates
  Future<void> addMessageTemplate(String title, String content) async {
    if (_currentEnterprise == null) return;
    final newTemplate = MessageTemplate(
      id: "tmpl_${DateTime.now().millisecondsSinceEpoch}",
      title: title.trim(),
      content: content.trim(),
    );
    final updatedTemplates = List<MessageTemplate>.from(_currentEnterprise!.messageTemplates)..add(newTemplate);
    final updated = _currentEnterprise!.copyWith(messageTemplates: updatedTemplates);
    _enterprises[updated.id] = updated;
    _currentEnterprise = updated;
    await saveToDisk();
    notifyListeners();
  }

  Future<void> deleteMessageTemplate(String templateId) async {
    if (_currentEnterprise == null) return;
    final updatedTemplates = _currentEnterprise!.messageTemplates.where((t) => t.id != templateId).toList();
    final updated = _currentEnterprise!.copyWith(messageTemplates: updatedTemplates);
    _enterprises[updated.id] = updated;
    _currentEnterprise = updated;
    await saveToDisk();
    notifyListeners();
  }

  // Update Brevo SMTP / API settings
  Future<void> updateEnterpriseBrevoSettings(String apiKey, String senderEmail) async {
    if (_currentEnterprise == null) return;
    final updated = _currentEnterprise!.copyWith(
      brevoApiKey: apiKey.trim(),
      brevoSenderEmail: senderEmail.trim(),
    );
    _enterprises[updated.id] = updated;
    _currentEnterprise = updated;
    await saveToDisk();
    notifyListeners();
  }

  // Update Country Code
  Future<void> updateDefaultCountryCode(String code) async {
    if (_currentEnterprise == null) return;
    // Remove '+' if present
    final cleanCode = code.replaceAll('+', '').trim();
    final updated = _currentEnterprise!.copyWith(defaultCountryCode: cleanCode);
    _enterprises[updated.id] = updated;
    _currentEnterprise = updated;
    await saveToDisk();
    notifyListeners();
  }

  // Format phone number for WhatsApp/SMS
  String formatPhoneNumber(String phone) {
    // Remove all non-numeric characters
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If it starts with 00, replace with nothing (standardizing)
    if (cleanPhone.startsWith('00')) {
      cleanPhone = cleanPhone.substring(2);
    }
    
    // Get default country code from enterprise
    final String countryCode = _currentEnterprise?.defaultCountryCode ?? 
                              (_currentAgent?.enterpriseId != null ? 
                              _enterprises[_currentAgent!.enterpriseId]?.defaultCountryCode ?? '229' : '229');

    // If phone doesn't start with country code and is a local number (e.g., 10 digits for Benin)
    // We assume it needs the country code
    if (!cleanPhone.startsWith(countryCode)) {
      // Special case for Benin (229): The leading '0' MUST be kept in international format
      if (countryCode == '229') {
        // If it's a 10-digit number starting with 0, just prepend 229 without stripping 0
        return countryCode + cleanPhone;
      }

      // General case for other countries: strip local zero prefix
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }
      return countryCode + cleanPhone;
    }
    
    return cleanPhone;
  }

  // ================= PROSPECT ACTIONS =================


  // Assign a list of prospects to an agent
  Future<void> assignProspectsToAgent(String agentId, List<String> prospectIds) async {
    if (_currentEnterprise == null) return;
    
    // 1. Update each prospect to link it to the new agent
    for (var pid in prospectIds) {
      final p = _prospects[pid];
      if (p != null) {
        _prospects[pid] = p.copyWith(agentId: agentId);
      }
    }

    // 2. Create the task
    final taskId = "task_${DateTime.now().millisecondsSinceEpoch}";
    final newTask = Task(
      id: taskId,
      enterpriseId: _currentEnterprise!.id,
      agentId: agentId,
      prospectIds: prospectIds,
      assignedAt: DateTime.now(),
    );
    _tasks[taskId] = newTask;
    
    await saveToDisk();
    notifyListeners();

    // 3. Create notification for agent
    final notif = AppNotification(
      id: "notif_task_${DateTime.now().millisecondsSinceEpoch}",
      title: "Nouvelle tâche assignée",
      body: "Vous avez reçu ${prospectIds.length} nouveaux prospects à traiter.",
      timestamp: DateTime.now(),
      type: 'task',
      relatedId: taskId,
      targetUserId: agentId,
    );
    _notifications.add(notif);
    _notifyNewAppNotification(notif);
  }

  // Reset all assignments/tasks for the current enterprise
  Future<void> resetAllAssignments() async {
    if (_currentEnterprise == null) return;
    final entId = _currentEnterprise!.id;
    _tasks.removeWhere((key, task) => task.enterpriseId == entId);
    await saveToDisk();
    notifyListeners();
  }

  // Get prospects for the current enterprise
  List<Prospect> getProspectsForCurrentEnterprise() {
    if (_currentEnterprise == null) return [];
    return _prospects.values
        .where((x) => x.enterpriseId == _currentEnterprise!.id)
        .toList();
  }

  // Paginated prospects for enterprise history
  List<Prospect> getPaginatedProspects({
    required int page,
    required int pageSize,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (_currentEnterprise == null) return [];
    
    var list = _prospects.values
        .where((x) => x.enterpriseId == _currentEnterprise!.id)
        .toList();

    // Search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list.where((p) {
        return (p.data['nom'] ?? '').toLowerCase().contains(query) ||
               (p.data['prenom'] ?? '').toLowerCase().contains(query) ||
               (p.data['telephone'] ?? '').toLowerCase().contains(query);
      }).toList();
    }

    // Date filters
    if (startDate != null) {
      list = list.where((p) => p.createdAt.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      list = list.where((p) => p.createdAt.isBefore(endDate.add(const Duration(days: 1)))).toList();
    }

    // Sort by date descending
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Pagination
    final startIndex = page * pageSize;
    if (startIndex >= list.length) return [];
    
    final endIndex = (startIndex + pageSize) > list.length ? list.length : (startIndex + pageSize);
    return list.sublist(startIndex, endIndex);
  }

  int getTotalProspectCount({String? searchQuery, DateTime? startDate, DateTime? endDate}) {
    if (_currentEnterprise == null) return 0;
    
    var list = _prospects.values
        .where((x) => x.enterpriseId == _currentEnterprise!.id)
        .toList();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list.where((p) {
        return (p.data['nom'] ?? '').toLowerCase().contains(query) ||
               (p.data['prenom'] ?? '').toLowerCase().contains(query) ||
               (p.data['telephone'] ?? '').toLowerCase().contains(query);
      }).toList();
    }

    if (startDate != null) {
      list = list.where((p) => p.createdAt.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      list = list.where((p) => p.createdAt.isBefore(endDate.add(const Duration(days: 1)))).toList();
    }

    return list.length;
  }

  // Performance analytics: prospects collected per agent
  Map<String, int> getProspectCountPerAgent() {
    final map = <String, int>{};
    final agents = getAgentsForCurrentEnterprise();
    for (var agent in agents) {
      map[agent.name] = _prospects.values
          .where((x) => x.agentId == agent.id)
          .length;
    }
    return map;
  }

  // Performance analytics: calls success per agent
  Map<String, Map<String, int>> getCallPerformancePerAgent() {
    final map = <String, Map<String, int>>{};
    final agents = getAgentsForCurrentEnterprise();
    for (var agent in agents) {
      final agentProspects = _prospects.values.where((x) => x.agentId == agent.id);
      int ok = agentProspects.where((x) => x.status == 'Succès').length;
      int non = agentProspects.where((x) => x.status == 'Refus').length;
      int unreachable = agentProspects.where((x) => x.status == 'unreachable').length;
      int pending = agentProspects.where((x) => x.status == 'En attente').length;
      map[agent.name] = {
        'ok': ok,
        'non': non,
        'unreachable': unreachable,
        'pending': pending,
      };
    }
    return map;
  }

  // Get all tasks assigned to the current agent (even completed ones)
  List<Task> getAllTasksForCurrentAgent() {
    if (_currentAgent == null) return [];
    return _tasks.values
        .where((x) => x.agentId == _currentAgent!.id)
        .toList()
      ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
  }

  // Unassign a prospect from an agent
  Future<void> unassignProspect(String prospectId) async {
    // 1. Find all pending tasks containing this prospect
    bool changed = false;
    _tasks.forEach((taskId, task) {
      if (task.status == 'pending' && task.prospectIds.contains(prospectId)) {
        final newList = List<String>.from(task.prospectIds)..remove(prospectId);
        if (newList.isEmpty) {
          // If task becomes empty, we could remove it or just keep it
          _tasks[taskId] = task.copyWith(prospectIds: []);
        } else {
          _tasks[taskId] = task.copyWith(prospectIds: newList);
        }
        changed = true;
      }
    });

    if (changed) {
      await saveToDisk();
      notifyListeners();
    }
  }

  // Delete an agent and their credentials
  Future<void> deleteAgent(String agentId) async {
    final agent = _agents[agentId];
    if (agent == null) return;

    _credentials.remove(agent.email.toLowerCase());
    _agents.remove(agentId);
    
    // Also remove their tasks? Usually safer to keep history but for now let's clean up
    _tasks.removeWhere((k, v) => v.agentId == agentId);

    await saveToDisk();
    notifyListeners();
  }

  // Update agent details
  Future<void> updateAgent(String agentId, String name, String email) async {
    final agent = _agents[agentId];
    if (agent == null) return;

    final oldEmail = agent.email.toLowerCase();
    final newEmail = email.trim().toLowerCase();

    if (oldEmail != newEmail) {
      final creds = _credentials.remove(oldEmail);
      if (creds != null) {
        _credentials[newEmail] = creds;
      }
    }

    _agents[agentId] = agent.copyWith(name: name.trim(), email: newEmail);
    
    await saveToDisk();
    notifyListeners();
  }

  // ================= AGENT ACTIONS =================

  // Add a prospect (Field)
  Future<void> addProspect(Map<String, String> data) async {
    if (_currentAgent == null) return;
    final prospectId = "prospect_${DateTime.now().millisecondsSinceEpoch}";
    final newProspect = Prospect(
      id: prospectId,
      enterpriseId: _currentAgent!.enterpriseId,
      agentId: _currentAgent!.id,
      data: data,
      status: 'pending',
      createdAt: DateTime.now(),
      isSynced: true, // Mark synced immediately since this is offline-first unified DB
    );
    _prospects[prospectId] = newProspect;
    await saveToDisk();
    notifyListeners();
  }

  // Get tasks assigned to the current agent
  List<Task> getTasksForCurrentAgent() {
    if (_currentAgent == null) return [];
    return _tasks.values
        .where((x) => x.agentId == _currentAgent!.id && x.status == 'pending')
        .toList();
  }

  // Get prospects assigned to current agent via tasks
  List<Prospect> getAssignedProspectsForCurrentAgent() {
    if (_currentAgent == null) return [];
    final tasks = getTasksForCurrentAgent();
    final prospectIds = tasks.expand((x) => x.prospectIds).toSet();
    return _prospects.values
        .where((x) => prospectIds.contains(x.id))
        .toList();
  }

  // Update prospect status (Verdict from call)
  Future<void> updateProspectStatus(String prospectId, String status, {String note = ''}) async {
    final prospect = _prospects[prospectId];
    if (prospect == null) return;

    final attempt = CallAttempt(
      timestamp: DateTime.now(),
      verdict: status,
      note: note,
    );

    final updatedAttempts = List<CallAttempt>.from(prospect.callAttempts)..add(attempt);
    final updatedProspect = prospect.copyWith(
      status: status,
      callAttempts: updatedAttempts,
    );

    _prospects[prospectId] = updatedProspect;

    // Check if task is completed
    _checkTaskCompletionForAgent();

    await saveToDisk();
    notifyListeners();
  }

  // Check and mark tasks as completed if all prospects in it have been called
  void _checkTaskCompletionForAgent() {
    if (_currentAgent == null) return;
    final tasks = getTasksForCurrentAgent();
    for (var task in tasks) {
      bool allCalled = true;
      for (var pid in task.prospectIds) {
        final p = _prospects[pid];
        if (p == null || p.status == 'pending') {
          allCalled = false;
          break;
        }
      }
      if (allCalled) {
        _tasks[task.id] = task.copyWith(status: 'completed');
      }
    }
  }

  // Get unreachable prospects for current agent (for top header reminders)
  List<Prospect> getUnreachableProspectsForCurrentAgent() {
    if (_currentAgent == null) return [];
    return _prospects.values
        .where((x) => x.agentId == _currentAgent!.id && x.status == 'unreachable')
        .toList();
  }

  // ================= CSV GENERATION & SHARING =================

  // Generate CSV data for a list of prospects
  String generateProspectsCSV(List<Prospect> prospects) {
    if (prospects.isEmpty) return '';

    // Headers
    List<String> headers = ['ID', 'Date de création', 'Statut'];
    final fields = _currentEnterprise?.formSettings.where((x) => x.enabled).toList() ?? Enterprise.defaultSettings;
    for (var field in fields) {
      headers.add(field.label);
    }
    headers.addAll(['Appels passés', 'Dernier Verdict', 'Commentaire']);

    List<List<dynamic>> rows = [headers];

    for (var prospect in prospects) {
      List<dynamic> row = [
        prospect.id,
        prospect.createdAt.toIso8601String().substring(0, 10),
        _translateStatus(prospect.status),
      ];

      for (var field in fields) {
        row.add(prospect.data[field.id] ?? '');
      }

      final lastAttempt = prospect.callAttempts.isNotEmpty ? prospect.callAttempts.last : null;
      row.addAll([
        prospect.callAttempts.length.toString(),
        lastAttempt != null ? _translateStatus(lastAttempt.verdict) : 'Aucun',
        lastAttempt?.note ?? '',
      ]);

      rows.add(row);
    }

    return const CsvEncoder(fieldDelimiter: ';').convert(rows);
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'ok':
        return 'Intéressé (OK)';
      case 'non':
        return 'Pas intéressé (NON)';
      case 'unreachable':
        return 'Indisponible / Inaccessible';
      case 'pending':
      default:
        return 'En attente';
    }
  }

  Future<File> saveCSVToFile(String csvData) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/G_CRM_Prospection_${DateTime.now().millisecondsSinceEpoch}.csv');
    return await file.writeAsString(csvData);
  }

  // ================= EMAIL DE RELANCE GROUPÉE & QUOTA =================

  // Get count of emails sent today by the enterprise
  int getEmailsSentTodayCount() {
    if (_currentEnterprise == null) return 0;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return _currentEnterprise!.dailyEmailCounters[todayStr] ?? 0;
  }

  // Send an email (with validation of the 50 emails per day limit per enterprise)
  Future<bool> sendEmailToProspect({
    required String prospectId,
    required String subject,
    required String content,
  }) async {
    if (_currentEnterprise == null) return false;
    final prospect = _prospects[prospectId];
    if (prospect == null || prospect.email.isEmpty) return false;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final currentCount = _currentEnterprise!.dailyEmailCounters[todayStr] ?? 0;

    if (currentCount >= 50) {
      // Limit reached! Add notification to admin logs
      final agentName = _currentAgent?.name ?? 'Un agent';
      final notificationMsg = 
          "Tentative bloquée : L'agent $agentName a tenté d'envoyer un email à ${prospect.name} (${prospect.email}) mais la limite collective de 50 emails/jour a été atteinte.";
      
      final updatedNotifications = List<String>.from(_currentEnterprise!.adminNotifications)..add(notificationMsg);
      final updatedEnterprise = _currentEnterprise!.copyWith(adminNotifications: updatedNotifications);
      
      _enterprises[updatedEnterprise.id] = updatedEnterprise;
      _currentEnterprise = updatedEnterprise;
      
      await saveToDisk();
      notifyListeners();
      return false; // Email sending blocked
    }

    // Call Brevo API or simulated free SMTP integration
    final bool emailSentSuccessfully;
    if (_currentEnterprise!.brevoApiKey.isNotEmpty && _currentEnterprise!.brevoSenderEmail.isNotEmpty) {
      emailSentSuccessfully = await _sendEmailViaBrevo(prospect.email, subject, content);
    } else {
      emailSentSuccessfully = await _simulateEmailSending(prospect.email, subject, content);
    }

    if (emailSentSuccessfully) {
      // Increment daily email counter for the enterprise
      final updatedCounters = Map<String, int>.from(_currentEnterprise!.dailyEmailCounters);
      updatedCounters[todayStr] = currentCount + 1;

      final updatedEnterprise = _currentEnterprise!.copyWith(dailyEmailCounters: updatedCounters);
      _enterprises[updatedEnterprise.id] = updatedEnterprise;
      _currentEnterprise = updatedEnterprise;

      await saveToDisk();
      notifyListeners();
      return true;
    }

    return false;
  }

  // ================= CHAT ACTIONS =================

  // Send a message
  Future<void> sendChatMessage({
    required String agentId,
    required String content,
  }) async {
    if (_currentEnterprise == null && _currentAgent == null) return;

    final String enterpriseId = _currentEnterprise?.id ?? _currentAgent!.enterpriseId;
    final String senderId = _currentUserRole == 'enterprise' ? enterpriseId : _currentAgent!.id;
    final String senderName = _currentUserRole == 'enterprise' ? _currentEnterprise!.name : _currentAgent!.name;

    final message = ChatMessage(
      id: "chat_${DateTime.now().millisecondsSinceEpoch}",
      enterpriseId: enterpriseId,
      agentId: agentId,
      senderId: senderId,
      senderName: senderName,
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    _chatMessages.add(message);
    await saveToDisk();
    notifyListeners();

    // Create notification
    final notif = AppNotification(
      id: "notif_msg_${DateTime.now().millisecondsSinceEpoch}",
      title: "Nouveau message",
      body: "${senderName}: ${content}",
      timestamp: DateTime.now(),
      type: 'message',
      relatedId: agentId,
      targetUserId: _currentUserRole == 'enterprise' ? agentId : enterpriseId,
    );
    _notifications.add(notif);
    _notifyNewAppNotification(notif);
  }

  // Notification stream for in-app alerts
  final _notifController = StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get onNewNotification => _notifController.stream;

  void _notifyNewAppNotification(AppNotification notification) {
    _notifController.add(notification);
  }

  @override
  void dispose() {
    _notifController.close();
    super.dispose();
  }

  // Get messages for a specific conversation (Agent <-> Enterprise)
  List<ChatMessage> getChatMessages(String agentId) {
    final String enterpriseId = _currentEnterprise?.id ?? _currentAgent?.enterpriseId ?? '';
    if (enterpriseId.isEmpty) return [];

    return _chatMessages.where((m) => 
      m.enterpriseId == enterpriseId && m.agentId == agentId
    ).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // Mark all messages as read for a conversation
  Future<void> markMessagesAsRead(String agentId) async {
    final String enterpriseId = _currentEnterprise?.id ?? _currentAgent?.enterpriseId ?? '';
    final String currentUserId = _currentUserRole == 'enterprise' ? enterpriseId : (_currentAgent?.id ?? '');
    
    bool changed = false;
    for (int i = 0; i < _chatMessages.length; i++) {
      final m = _chatMessages[i];
      if (m.enterpriseId == enterpriseId && 
          m.agentId == agentId && 
          m.senderId != currentUserId && 
          !m.isRead) {
        _chatMessages[i] = m.copyWith(isRead: true);
        changed = true;
      }
    }

    if (changed) {
      await saveToDisk();
      notifyListeners();
    }
  }

  // Get unread messages count for the current user
  int getUnreadMessagesCount({String? forAgentId}) {
    final String enterpriseId = _currentEnterprise?.id ?? _currentAgent?.enterpriseId ?? '';
    final String currentUserId = _currentUserRole == 'enterprise' ? enterpriseId : (_currentAgent?.id ?? '');

    return _chatMessages.where((m) {
      bool isTargetConversation = true;
      if (forAgentId != null) {
        isTargetConversation = m.agentId == forAgentId;
      }
      return m.enterpriseId == enterpriseId && 
             isTargetConversation &&
             m.senderId != currentUserId && 
             !m.isRead;
    }).length;
  }

  // Get unread notifications count for current user
  int getUnreadNotificationsCount() {
    final String currentUserId = _currentUserRole == 'enterprise' 
        ? (_currentEnterprise?.id ?? '') 
        : (_currentAgent?.id ?? '');
    
    return _notifications.where((n) => n.targetUserId == currentUserId && !n.isRead).length;
  }

  // Get notifications for current user
  List<AppNotification> getMyNotifications() {
    final String currentUserId = _currentUserRole == 'enterprise' 
        ? (_currentEnterprise?.id ?? '') 
        : (_currentAgent?.id ?? '');
    
    return _notifications.where((n) => n.targetUserId == currentUserId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    final String currentUserId = _currentUserRole == 'enterprise' 
        ? (_currentEnterprise?.id ?? '') 
        : (_currentAgent?.id ?? '');
    
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].targetUserId == currentUserId && !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }

    if (changed) {
      await saveToDisk();
      notifyListeners();
    }
  }

  Future<bool> _sendEmailViaBrevo(String to, String subject, String body) async {
    if (_currentEnterprise == null) return false;
    final apiKey = _currentEnterprise!.brevoApiKey;
    final senderEmail = _currentEnterprise!.brevoSenderEmail;
    final senderName = _currentEnterprise!.name;

    try {
      final response = await http.post(
        Uri.parse('https://api.brevo.com/v3/smtp/email'),
        headers: {
          'accept': 'application/json',
          'api-key': apiKey,
          'content-type': 'application/json',
        },
        body: json.encode({
          'sender': {
            'name': senderName,
            'email': senderEmail,
          },
          'to': [
            {
              'email': to,
            }
          ],
          'subject': subject,
          'htmlContent': '<html><body>${body.replaceAll('\n', '<br>')}</body></html>',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint("Email sent successfully via Brevo to $to");
        return true;
      } else {
        debugPrint("Failed to send email via Brevo. Status: ${response.statusCode}, Body: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error sending email via Brevo: $e");
      return false;
    }
  }

  Future<bool> _simulateEmailSending(String to, String subject, String body) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }


  // Clear notifications for enterprise admin
  Future<void> clearAdminNotifications() async {
    if (_currentEnterprise == null) return;
    final updated = _currentEnterprise!.copyWith(adminNotifications: []);
    _enterprises[updated.id] = updated;
    _currentEnterprise = updated;
    await saveToDisk();
    notifyListeners();
  }

  // Send a test email to verify credentials
  Future<bool> sendTestEmail(String destinationEmail) async {
    if (_currentEnterprise == null) return false;
    return await _sendEmailViaBrevo(
      destinationEmail,
      "Test de configuration Brevo - G-CRM",
      "Félicitations !\n\nVotre configuration de service de messagerie Brevo sur G-CRM fonctionne parfaitement.\n\nCordialement,\nL'équipe G-CRM.",
    );
  }

  // Send the CSV prospect report to the enterprise email directly via Brevo
  Future<bool> sendReportToEnterprise(List<Prospect> prospects) async {
    if (_currentEnterprise == null) return false;
    final enterpriseEmail = _currentEnterprise!.email;
    if (enterpriseEmail.isEmpty) return false;

    final csvString = generateProspectsCSV(prospects);
    final agentName = _currentAgent?.name ?? 'Agent';
    
    final subject = "Rapport de prospection - $agentName";
    final body = "Bonjour,\n\nVous trouverez ci-joint le rapport de prospection de l'agent $agentName clôturé le ${DateTime.now().toLocal().toString().substring(0, 19)}.\n\nCordialement,\nL'équipe G-CRM.";

    // Convert CSV to Base64
    final bytes = utf8.encode(csvString);
    final base64Csv = base64.encode(bytes);

    if (_currentEnterprise!.brevoApiKey.isNotEmpty && _currentEnterprise!.brevoSenderEmail.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('https://api.brevo.com/v3/smtp/email'),
          headers: {
            'accept': 'application/json',
            'api-key': _currentEnterprise!.brevoApiKey,
            'content-type': 'application/json',
          },
          body: json.encode({
            'sender': {
              'name': _currentEnterprise!.name,
              'email': _currentEnterprise!.brevoSenderEmail,
            },
            'to': [
              {
                'email': enterpriseEmail,
              }
            ],
            'subject': subject,
            'htmlContent': '<html><body>${body.replaceAll('\n', '<br>')}</body></html>',
            'attachment': [
              {
                'name': 'Rapport_Prospection_${agentName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv',
                'content': base64Csv,
              }
            ]
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          debugPrint("Report email sent successfully via Brevo to $enterpriseEmail");
          return true;
        } else {
          debugPrint("Failed to send report email via Brevo. Status: ${response.statusCode}, Body: ${response.body}");
          return false;
        }
      } catch (e) {
        debugPrint("Error sending report email via Brevo: $e");
        return false;
      }
    } else {
      // Simulation if Brevo is not configured
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
  }
}

