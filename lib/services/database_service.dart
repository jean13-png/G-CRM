import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_config.dart';
import '../models/enterprise.dart';
import '../models/agent.dart';
import '../models/prospect.dart';
import '../models/task.dart';
import '../models/chat_message.dart';
import '../models/app_notification.dart';
import 'sms_service.dart';
import 'whatsapp_service.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Active session state
  Enterprise? _currentEnterprise;
  Agent? _currentAgent;
  String? _currentUserRole; // 'enterprise' or 'agent'

  // Collections (Cached from Firestore)
  final Map<String, Enterprise> _enterprises = {};
  final Map<String, Agent> _agents = {};
  final Map<String, Prospect> _prospects = {};
  final Map<String, Task> _tasks = {};
  final List<ChatMessage> _chatMessages = [];
  final List<AppNotification> _notifications = [];
  final Set<String> _notifiedIds = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Stream Subscriptions
  StreamSubscription? _agentsSubscription;
  StreamSubscription? _prospectsSubscription;
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _enterpriseSubscription;

  // State for Global Communication Process
  bool _isCommOperationRunning = false;
  int _commProgressCurrent = 0;
  int _commProgressTotal = 0;
  String _commOperationLabel = '';
  List<String> _commOperationLogs = [];

  bool get isCommOperationRunning => _isCommOperationRunning;
  int get commProgressCurrent => _commProgressCurrent;
  int get commProgressTotal => _commProgressTotal;
  String get commOperationLabel => _commOperationLabel;
  List<String> get commOperationLogs => _commOperationLogs;

  void updateCommOperation({
    required bool isRunning,
    int? current,
    int? total,
    String? label,
    String? log,
    bool reset = false,
  }) {
    if (reset) {
      _isCommOperationRunning = false;
      _commProgressCurrent = 0;
      _commProgressTotal = 0;
      _commOperationLabel = '';
      _commOperationLogs = [];
    } else {
      _isCommOperationRunning = isRunning;
      if (current != null) _commProgressCurrent = current;
      if (total != null) _commProgressTotal = total;
      if (label != null) _commOperationLabel = label;
      if (log != null) _commOperationLogs.add(log);
    }
    notifyListeners();
  }

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

  // Initialize service & check Firebase auth status
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        // Check if user is enterprise
        final entDoc = await FirebaseFirestore.instance.collection('enterprises').doc(userId).get();
        if (entDoc.exists && entDoc.data() != null) {
          _currentUserRole = 'enterprise';
          _currentEnterprise = Enterprise.fromMap(entDoc.data()!);
          _enterprises[userId] = _currentEnterprise!;
          _currentAgent = null;
          _initializeListeners('enterprise', userId, userId);
        } else {
          // Check if user is agent
          final agentDoc = await FirebaseFirestore.instance.collection('agents').doc(userId).get();
          if (agentDoc.exists && agentDoc.data() != null) {
            _currentUserRole = 'agent';
            _currentAgent = Agent.fromMap(agentDoc.data()!);
            _agents[userId] = _currentAgent!;
            
            // Get corresponding enterprise
            final entId = _currentAgent!.enterpriseId;
            final agentEntDoc = await FirebaseFirestore.instance.collection('enterprises').doc(entId).get();
            if (agentEntDoc.exists && agentEntDoc.data() != null) {
              _currentEnterprise = Enterprise.fromMap(agentEntDoc.data()!);
              _enterprises[entId] = _currentEnterprise!;
            }
            _initializeListeners('agent', userId, entId);
          } else {
            // Out of sync, sign out
            await FirebaseAuth.instance.signOut();
          }
        }
      }
    } catch (e) {
      debugPrint("Error initializing Firebase DatabaseService: $e");
    }
    _initialized = true;
    notifyListeners();
  }

  // Cancel all active Firestore subscriptions
  void _cancelAllSubscriptions() {
    _agentsSubscription?.cancel();
    _prospectsSubscription?.cancel();
    _tasksSubscription?.cancel();
    _messagesSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _enterpriseSubscription?.cancel();
  }

  // Set up real-time sync listeners based on user role
  void _initializeListeners(String role, String userId, String enterpriseId) {
    _cancelAllSubscriptions();
    final firestore = FirebaseFirestore.instance;

    // Listen to Notifications
    _notificationsSubscription = firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _notifications.clear();
      for (var doc in snapshot.docs) {
        try {
          final notif = AppNotification.fromMap(doc.data());
          _notifications.add(notif);

          // If unread and not yet popped up in this session, trigger in-app alert stream
          if (!notif.isRead && !_notifiedIds.contains(notif.id)) {
            _notifiedIds.add(notif.id);
            _notifyNewAppNotification(notif);
          }
        } catch (e) {
          debugPrint("Error parsing notification: $e");
        }
      }
      notifyListeners();
    });

    if (role == 'enterprise') {
      // Listen to Enterprise settings
      _enterpriseSubscription = firestore
          .collection('enterprises')
          .doc(userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          _currentEnterprise = Enterprise.fromMap(snapshot.data()!);
          _enterprises[userId] = _currentEnterprise!;
          notifyListeners();
        }
      });

      // Listen to Agents
      _agentsSubscription = firestore
          .collection('agents')
          .where('enterpriseId', isEqualTo: enterpriseId)
          .snapshots()
          .listen((snapshot) {
        _agents.clear();
        for (var doc in snapshot.docs) {
          try {
            final agent = Agent.fromMap(doc.data());
            _agents[agent.id] = agent;
          } catch (e) {
            debugPrint("Error parsing agent: $e");
          }
        }
        notifyListeners();
      });

      // Listen to Prospects
      _prospectsSubscription = firestore
          .collection('prospects')
          .where('enterpriseId', isEqualTo: enterpriseId)
          .snapshots()
          .listen((snapshot) {
        _prospects.clear();
        for (var doc in snapshot.docs) {
          try {
            final prospect = Prospect.fromMap(doc.data());
            _prospects[prospect.id] = prospect;
          } catch (e) {
            debugPrint("Error parsing prospect: $e");
          }
        }
        notifyListeners();
      });

      // Listen to Tasks
      _tasksSubscription = firestore
          .collection('tasks')
          .where('enterpriseId', isEqualTo: enterpriseId)
          .snapshots()
          .listen((snapshot) {
        _tasks.clear();
        for (var doc in snapshot.docs) {
          try {
            final task = Task.fromMap(doc.data());
            _tasks[task.id] = task;
          } catch (e) {
            debugPrint("Error parsing task: $e");
          }
        }
        notifyListeners();
      });

      // Listen to Chat Messages
      _messagesSubscription = firestore
          .collection('chatMessages')
          .where('enterpriseId', isEqualTo: enterpriseId)
          .snapshots()
          .listen((snapshot) {
        _chatMessages.clear();
        for (var doc in snapshot.docs) {
          try {
            _chatMessages.add(ChatMessage.fromMap(doc.data()));
          } catch (e) {
            debugPrint("Error parsing chat message: $e");
          }
        }
        notifyListeners();
      });

    } else if (role == 'agent') {
      // Listen to Agent profile
      _agentsSubscription = firestore
          .collection('agents')
          .doc(userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          _currentAgent = Agent.fromMap(snapshot.data()!);
          _agents[userId] = _currentAgent!;
          notifyListeners();
        }
      });

      // Listen to Enterprise settings
      _enterpriseSubscription = firestore
          .collection('enterprises')
          .doc(enterpriseId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          _currentEnterprise = Enterprise.fromMap(snapshot.data()!);
          _enterprises[enterpriseId] = _currentEnterprise!;
          notifyListeners();
        }
      });

      // Listen to Prospects assigned to this agent
      _prospectsSubscription = firestore
          .collection('prospects')
          .where('agentId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        _prospects.clear();
        for (var doc in snapshot.docs) {
          try {
            final prospect = Prospect.fromMap(doc.data());
            _prospects[prospect.id] = prospect;
          } catch (e) {
            debugPrint("Error parsing prospect: $e");
          }
        }
        notifyListeners();
      });

      // Listen to Tasks assigned to this agent
      _tasksSubscription = firestore
          .collection('tasks')
          .where('agentId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        _tasks.clear();
        for (var doc in snapshot.docs) {
          try {
            final task = Task.fromMap(doc.data());
            _tasks[task.id] = task;
          } catch (e) {
            debugPrint("Error parsing task: $e");
          }
        }
        notifyListeners();
      });

      // Listen to Chat messages involving this agent
      _messagesSubscription = firestore
          .collection('chatMessages')
          .where('agentId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        _chatMessages.clear();
        for (var doc in snapshot.docs) {
          try {
            _chatMessages.add(ChatMessage.fromMap(doc.data()));
          } catch (e) {
            debugPrint("Error parsing chat message: $e");
          }
        }
        notifyListeners();
      });
    }
  }

  // ================= AUTHENTICATION ACTIONS =================

  Future<bool> signIn(String email, String password, String role) async {
    try {
      final UserCredential creds = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final userId = creds.user!.uid;

      if (role == 'enterprise') {
        final entDoc = await FirebaseFirestore.instance.collection('enterprises').doc(userId).get();
        if (entDoc.exists && entDoc.data() != null) {
          _currentUserRole = 'enterprise';
          _currentEnterprise = Enterprise.fromMap(entDoc.data()!);
          _enterprises[userId] = _currentEnterprise!;
          _currentAgent = null;
          _initializeListeners('enterprise', userId, userId);
          notifyListeners();
          return true;
        } else {
          await FirebaseAuth.instance.signOut();
          return false;
        }
      } else {
        final agentDoc = await FirebaseFirestore.instance.collection('agents').doc(userId).get();
        if (agentDoc.exists && agentDoc.data() != null) {
          _currentUserRole = 'agent';
          _currentAgent = Agent.fromMap(agentDoc.data()!);
          _agents[userId] = _currentAgent!;
          
          final entId = _currentAgent!.enterpriseId;
          final agentEntDoc = await FirebaseFirestore.instance.collection('enterprises').doc(entId).get();
          if (agentEntDoc.exists && agentEntDoc.data() != null) {
            _currentEnterprise = Enterprise.fromMap(agentEntDoc.data()!);
            _enterprises[entId] = _currentEnterprise!;
          }
          _initializeListeners('agent', userId, entId);
          notifyListeners();
          return true;
        } else {
          await FirebaseAuth.instance.signOut();
          return false;
        }
      }
    } catch (e) {
      debugPrint("Sign in error: $e");
      return false;
    }
  }

  Future<bool> signUpEnterprise(String name, String email, String password) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final UserCredential creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final userId = creds.user!.uid;

      final enterprise = Enterprise(
        id: userId,
        name: name.trim(),
        email: cleanEmail,
        formSettings: Enterprise.defaultSettings,
      );

      await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(userId)
          .set(enterprise.toMap())
          .timeout(const Duration(seconds: 10));

      _currentUserRole = 'enterprise';
      _currentEnterprise = enterprise;
      _enterprises[userId] = enterprise;
      _currentAgent = null;

      _initializeListeners('enterprise', userId, userId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Sign up enterprise error: $e");
      return false;
    }
  }

  Future<void> signOut() async {
    _cancelAllSubscriptions();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Error during signOut: $e");
    }
    _currentEnterprise = null;
    _currentAgent = null;
    _currentUserRole = null;
    _notifiedIds.clear();
    notifyListeners();
  }

  // ================= ENTERPRISE ACTIONS =================

  // Add agent (using secondary FirebaseApp config to avoid administrative session hijacking)
  Future<bool> createAgent(String name, String email, String password) async {
    if (_currentEnterprise == null) return false;
    final cleanEmail = email.trim().toLowerCase();

    try {
      final appName = "agent_creation_${DateTime.now().millisecondsSinceEpoch}";
      final tempApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final UserCredential tempCred = await tempAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final agentId = tempCred.user!.uid;
      
      await tempApp.delete();

      final agent = Agent(
        id: agentId,
        enterpriseId: _currentEnterprise!.id,
        name: name.trim(),
        email: cleanEmail,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('agents').doc(agentId).set(agent.toMap());
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Create agent error: $e");
      return false;
    }
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
    try {
      await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
        'formSettings': settings.map((s) => s.toMap()).toList(),
      });
    } catch (e) {
      debugPrint("Error updating form settings: $e");
    }
  }

  // Manage Message Templates
  Future<void> addMessageTemplate(String title, String content) async {
    if (_currentEnterprise == null) return;
    try {
      final newTemplate = MessageTemplate(
        id: "tmpl_${DateTime.now().millisecondsSinceEpoch}",
        title: title.trim(),
        content: content.trim(),
      );
      final updatedTemplates = List<MessageTemplate>.from(_currentEnterprise!.messageTemplates)..add(newTemplate);
      await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
        'messageTemplates': updatedTemplates.map((t) => t.toMap()).toList(),
      });
    } catch (e) {
      debugPrint("Error adding message template: $e");
    }
  }

  Future<void> deleteMessageTemplate(String templateId) async {
    if (_currentEnterprise == null) return;
    try {
      final updatedTemplates = _currentEnterprise!.messageTemplates.where((t) => t.id != templateId).toList();
      await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
        'messageTemplates': updatedTemplates.map((t) => t.toMap()).toList(),
      });
    } catch (e) {
      debugPrint("Error deleting message template: $e");
    }
  }

  // Update Brevo SMTP / API settings
  Future<void> updateEnterpriseBrevoSettings(String apiKey, String senderEmail) async {
    if (_currentEnterprise == null) return;
    try {
      await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
        'brevoApiKey': apiKey.trim(),
        'brevoSenderEmail': senderEmail.trim(),
      });
    } catch (e) {
      debugPrint("Error updating Brevo settings: $e");
    }
  }

  // Update Country Code
  Future<void> updateDefaultCountryCode(String code) async {
    if (_currentEnterprise == null) return;
    final cleanCode = code.replaceAll('+', '').trim();
    try {
      await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
        'defaultCountryCode': cleanCode,
      });
    } catch (e) {
      debugPrint("Error updating country code: $e");
    }
  }

  // Update Auto Assign Setting
  Future<void> updateAutoAssignToAgent(bool value) async {
    if (_currentEnterprise == null) return;
    try {
      await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
        'autoAssignToAgent': value,
      });
    } catch (e) {
      debugPrint("Error updating auto assign setting: $e");
    }
  }

  // Update Custom Verdicts
  Future<void> updateCustomVerdicts(List<String> verdicts) async {
    if (_currentEnterprise == null) return;
    try {
      await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
        'customVerdicts': verdicts,
      });
    } catch (e) {
      debugPrint("Error updating custom verdicts: $e");
    }
  }

  // Update Africa's Talking settings (Géré globalement via AppConfig)
  Future<void> updateAfricaTalkingSettings(String apiKey, String username) async {
    debugPrint("updateAfricaTalkingSettings is deprecated - use AppConfig instead");
  }

  // Update Twilio settings (Géré globalement via AppConfig)
  Future<void> updateTwilioSettings(String accountSid, String authToken, String phoneNumber) async {
    debugPrint("updateTwilioSettings is deprecated - use AppConfig instead");
  }

  // Format phone number for WhatsApp/SMS
  String formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('00')) {
      cleanPhone = cleanPhone.substring(2);
    }
    
    final String countryCode = _currentEnterprise?.defaultCountryCode ?? 
                              (_currentAgent?.enterpriseId != null ? 
                              _enterprises[_currentAgent!.enterpriseId]?.defaultCountryCode ?? '229' : '229');

    if (!cleanPhone.startsWith(countryCode)) {
      if (countryCode == '229') {
        return countryCode + cleanPhone;
      }
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }
      return countryCode + cleanPhone;
    }
    return cleanPhone;
  }

  // ================= QUOTAS MANAGEMENT =================
  Future<bool> checkAndConsumeQuota(String type, int amount) async {
    final enterprise = _currentEnterprise;
    if (enterprise == null) return false;

    int remaining = 0;
    String fieldName = '';

    if (type == 'appel_manuel') {
      remaining = enterprise.appelsManuelsRestants;
      fieldName = 'appelsManuelsRestants';
    } else if (type == 'sms_manuel') {
      remaining = enterprise.smsManuelsRestants;
      fieldName = 'smsManuelsRestants';
    } else if (type == 'whatsapp_manuel') {
      remaining = enterprise.whatsappManuelsRestants;
      fieldName = 'whatsappManuelsRestants';
    } else if (type == 'sms_groupe') {
      remaining = enterprise.smsGroupesRestants;
      fieldName = 'smsGroupesRestants';
    } else if (type == 'email_groupe') {
      remaining = enterprise.emailsGroupesRestants;
      fieldName = 'emailsGroupesRestants';
    } else if (type == 'prospect') {
      remaining = enterprise.prospectsRestants;
      fieldName = 'prospectsRestants';
    } else {
      return true; // Not managed yet
    }

    if (remaining < amount) {
      return false;
    }

    final newRemaining = remaining - amount;

    await FirebaseFirestore.instance
        .collection('enterprises')
        .doc(enterprise.id)
        .update({
      fieldName: newRemaining,
    });

    // Check thresholds for notifications
    final maxQuota = _getMaxQuotaForDb(enterprise.planId, type);
    if (maxQuota > 0) {
      final double percentUsed = (maxQuota - newRemaining) / maxQuota;
      final int previousPercentUsed = (maxQuota - remaining) / maxQuota >= 0 ? ((maxQuota - remaining) / maxQuota * 100).toInt() : 0;
      final int currentPercentUsed = (percentUsed * 100).toInt();
      
      String alertMsg = '';
      if (newRemaining == 0 && remaining > 0) {
        alertMsg = "Alerte : Vos crédits de $type sont épuisés (100%) ! Les actions sont bloquées. Veuillez passer au plan supérieur.";
      } else if (currentPercentUsed >= 90 && previousPercentUsed < 90) {
        alertMsg = "Attention : Vos crédits de $type seront bientôt épuisés (90% utilisés).";
      } else if (currentPercentUsed >= 80 && previousPercentUsed < 80) {
        alertMsg = "Information : Vous avez utilisé 80% de vos crédits de $type.";
      }

      if (alertMsg.isNotEmpty) {
        final notifs = List<String>.from(enterprise.adminNotifications);
        notifs.add("${DateTime.now().toIso8601String().split('T')[0]} - $alertMsg");
        
        await FirebaseFirestore.instance
            .collection('enterprises')
            .doc(enterprise.id)
            .update({
          'adminNotifications': notifs,
        });
      }
    }

    return true;
  }

  int _getMaxQuotaForDb(String plan, String type) {
    if (plan == 'DISCOVERY') {
      if (type == 'appel_manuel') return 250;
      if (type == 'sms_manuel') return 250;
      if (type == 'whatsapp_manuel') return 100;
      if (type == 'prospect') return 50;
    } else if (plan == 'STARTER') {
      if (type == 'appel_manuel') return 600;
      if (type == 'sms_manuel') return 600;
      if (type == 'whatsapp_manuel') return 400;
      if (type == 'prospect') return 800;
    } else if (plan == 'PRO') {
      if (type == 'appel_manuel') return 3500;
      if (type == 'sms_manuel') return 3500;
      if (type == 'whatsapp_manuel') return 1800;
      if (type == 'prospect') return 5000;
    } else if (plan == 'BUSINESS') {
      if (type == 'appel_manuel') return 10000;
      if (type == 'sms_manuel') return 10000;
      if (type == 'whatsapp_manuel') return 5000;
      if (type == 'prospect') return 20000;
    }
    return 100;
  }

  // ================= PROSPECT ACTIONS =================

  // Assign a list of prospects to an agent
  Future<void> assignProspectsToAgent(String agentId, List<String> prospectIds) async {
    if (_currentEnterprise == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    
    // 1. Update each prospect to link it to the new agent and reset status to pending
    for (var pid in prospectIds) {
      final docRef = FirebaseFirestore.instance.collection('prospects').doc(pid);
      batch.update(docRef, {
        'agentId': agentId,
        'status': 'pending',
      });
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
    final taskDocRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    batch.set(taskDocRef, newTask.toMap());
    
    // 3. Create notification for agent
    final notifId = "notif_task_${DateTime.now().millisecondsSinceEpoch}";
    final notif = AppNotification(
      id: notifId,
      title: "Nouvelle tâche assignée",
      body: "Vous avez reçu ${prospectIds.length} nouveaux prospects à traiter.",
      timestamp: DateTime.now(),
      type: 'task',
      relatedId: taskId,
      targetUserId: agentId,
    );
    final notifDocRef = FirebaseFirestore.instance.collection('notifications').doc(notifId);
    batch.set(notifDocRef, notif.toMap());

    await batch.commit();
  }

  // Reset all assignments/tasks for the current enterprise
  Future<void> resetAllAssignments() async {
    if (_currentEnterprise == null) return;
    final entId = _currentEnterprise!.id;

    final batch = FirebaseFirestore.instance.batch();

    // 1. Delete all tasks for this enterprise
    final tasksQuery = await FirebaseFirestore.instance
        .collection('tasks')
        .where('enterpriseId', isEqualTo: entId)
        .get();

    for (var doc in tasksQuery.docs) {
      batch.delete(doc.reference);
    }

    // 2. Clear agentId and reset status for all prospects
    final prospectsQuery = await FirebaseFirestore.instance
        .collection('prospects')
        .where('enterpriseId', isEqualTo: entId)
        .get();

    for (var doc in prospectsQuery.docs) {
      batch.update(doc.reference, {
        'agentId': '',
        'status': 'pending',
      });
    }

    await batch.commit();
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

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
      int ok = agentProspects.where((x) => x.status == 'Succès' || x.status == 'ok').length;
      int non = agentProspects.where((x) => x.status == 'Refus' || x.status == 'non').length;
      int unreachable = agentProspects.where((x) => x.status == 'Injoignable' || x.status == 'unreachable').length;
      int pending = agentProspects.where((x) => x.status == 'En attente' || x.status == 'pending').length;
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
    final tasksQuery = await FirebaseFirestore.instance
        .collection('tasks')
        .where('enterpriseId', isEqualTo: _currentEnterprise?.id)
        .where('status', isEqualTo: 'pending')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    bool changed = false;

    for (var doc in tasksQuery.docs) {
      final task = Task.fromMap(doc.data());
      if (task.prospectIds.contains(prospectId)) {
        final newList = List<String>.from(task.prospectIds)..remove(prospectId);
        batch.update(doc.reference, {
          'prospectIds': newList,
        });
        changed = true;
      }
    }

    if (changed) {
      final prospectDocRef = FirebaseFirestore.instance.collection('prospects').doc(prospectId);
      batch.update(prospectDocRef, {
        'agentId': '',
        'status': 'pending',
      });
      await batch.commit();
    }
  }

  // Delete an agent
  Future<void> deleteAgent(String agentId) async {
    try {
      await FirebaseFirestore.instance.collection('agents').doc(agentId).delete();
      
      final tasksQuery = await FirebaseFirestore.instance
          .collection('tasks')
          .where('agentId', isEqualTo: agentId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tasksQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Delete agent error: $e");
    }
  }

  // Update agent details
  Future<void> updateAgent(String agentId, String name, String email) async {
    try {
      await FirebaseFirestore.instance.collection('agents').doc(agentId).update({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
      });
    } catch (e) {
      debugPrint("Update agent error: $e");
    }
  }

  // ================= AGENT ACTIONS =================

  // Add a prospect (Field)
  Future<void> addProspect(Map<String, String> data, {bool isWhatsApp = false}) async {
    if (_currentAgent == null) return;
    final prospectId = "prospect_${DateTime.now().millisecondsSinceEpoch}";
    final enterpriseId = _currentAgent!.enterpriseId;
    
    // Check if auto-assignment is enabled for this enterprise
    final bool autoAssign = _currentEnterprise?.autoAssignToAgent ?? 
                           _enterprises[enterpriseId]?.autoAssignToAgent ?? false;

    // Determine if it's a WhatsApp number: check if numeroWhatsApp field is set or if the checkbox was ticked
    bool finalIsWhatsApp = isWhatsApp;
    if (data.containsKey('numeroWhatsApp') && data['numeroWhatsApp'] != null && data['numeroWhatsApp']!.isNotEmpty) {
      finalIsWhatsApp = true;
    }

    final newProspect = Prospect(
      id: prospectId,
      enterpriseId: enterpriseId,
      agentId: _currentAgent!.id,
      data: data,
      status: 'pending',
      isWhatsApp: finalIsWhatsApp,
      createdAt: DateTime.now(),
      isSynced: true,
    );

    final batch = FirebaseFirestore.instance.batch();
    batch.set(FirebaseFirestore.instance.collection('prospects').doc(prospectId), newProspect.toMap());

    // If auto-assign is on, create a task immediately
    if (autoAssign) {
      final taskId = "task_auto_${DateTime.now().millisecondsSinceEpoch}";
      final newTask = Task(
        id: taskId,
        enterpriseId: enterpriseId,
        agentId: _currentAgent!.id,
        prospectIds: [prospectId],
        assignedAt: DateTime.now(),
      );
      batch.set(FirebaseFirestore.instance.collection('tasks').doc(taskId), newTask.toMap());
    }

    await batch.commit();
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

    await FirebaseFirestore.instance.collection('prospects').doc(prospectId).update({
      'status': status,
      'callAttempts': updatedAttempts.map((x) => x.toMap()).toList(),
    });

    _checkTaskCompletionForAgent();
  }

  // Update prospect tracking (Suivis 1-8)
  Future<void> updateProspectSuivi({
    required String prospectId,
    required int index,
    required String resume,
    String? observation,
    String? decision,
  }) async {
    final prospect = _prospects[prospectId];
    if (prospect == null) return;

    final List<Suivi> updatedSuivis = List<Suivi>.from(prospect.suivis);
    if (index >= 0 && index < 8) {
      updatedSuivis[index] = Suivi(date: DateTime.now(), resume: resume);
    }

    final Map<String, dynamic> updates = {
      'suivis': updatedSuivis.map((x) => x.toMap()).toList(),
    };

    if (observation != null) updates['observation'] = observation;
    if (decision != null) updates['decision'] = decision;

    await FirebaseFirestore.instance.collection('prospects').doc(prospectId).update(updates);
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
        FirebaseFirestore.instance.collection('tasks').doc(task.id).update({
          'status': 'completed',
        });
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
      final agentName = _currentAgent?.name ?? 'Un agent';
      final notificationMsg = 
          "Tentative bloquée : L'agent $agentName a tenté d'envoyer un email à ${prospect.name} (${prospect.email}) mais la limite collective de 50 emails/jour a été atteinte.";
      
      final updatedNotifications = List<String>.from(_currentEnterprise!.adminNotifications)..add(notificationMsg);
      
      await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
        'adminNotifications': updatedNotifications,
      });
      return false;
    }

    final bool emailSentSuccessfully;
    if (AppConfig.brevoApiKey.isNotEmpty && AppConfig.brevoSenderEmail.isNotEmpty) {
      emailSentSuccessfully = await _sendEmailViaBrevo(
        prospect.email,
        subject,
        content,
        customSenderEmail: _currentEnterprise?.email,
        customSenderName: _currentEnterprise?.name,
      );
    } else {
      emailSentSuccessfully = await _simulateEmailSending(prospect.email, subject, content);
    }

    if (emailSentSuccessfully) {
      final updatedCounters = Map<String, int>.from(_currentEnterprise!.dailyEmailCounters);
      updatedCounters[todayStr] = currentCount + 1;

      await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
        'dailyEmailCounters': updatedCounters,
      });
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

    final messageId = "chat_${DateTime.now().millisecondsSinceEpoch}";
    final message = ChatMessage(
      id: messageId,
      enterpriseId: enterpriseId,
      agentId: agentId,
      senderId: senderId,
      senderName: senderName,
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    // Save chat message
    await FirebaseFirestore.instance.collection('chatMessages').doc(messageId).set(message.toMap());

    // Create notification
    final targetUserId = _currentUserRole == 'enterprise' ? agentId : enterpriseId;
    final notifId = "notif_msg_${DateTime.now().millisecondsSinceEpoch}";
    final notif = AppNotification(
      id: notifId,
      title: _currentUserRole == 'enterprise' ? "Message de l'entreprise" : "Message de ${senderName}",
      body: content.trim(),
      timestamp: DateTime.now(),
      type: 'message',
      relatedId: agentId,
      targetUserId: targetUserId,
    );
    await FirebaseFirestore.instance.collection('notifications').doc(notifId).set(notif.toMap());
  }

  // Notification stream for in-app alerts
  final _notifController = StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get onNewNotification => _notifController.stream;

  void _notifyNewAppNotification(AppNotification notification) {
    _notifController.add(notification);
  }

  @override
  void dispose() {
    _cancelAllSubscriptions();
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
    
    final messagesQuery = await FirebaseFirestore.instance
        .collection('chatMessages')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .where('agentId', isEqualTo: agentId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    bool changed = false;

    for (var doc in messagesQuery.docs) {
      final m = ChatMessage.fromMap(doc.data());
      if (m.senderId != currentUserId && !m.isRead) {
        batch.update(doc.reference, {'isRead': true});
        changed = true;
      }
    }

    if (changed) {
      await batch.commit();
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
    
    final notifsQuery = await FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUserId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    bool changed = false;

    for (var doc in notifsQuery.docs) {
      batch.update(doc.reference, {'isRead': true});
      changed = true;
    }

    if (changed) {
      await batch.commit();
    }
  }

  Future<bool> _sendEmailViaBrevo(String to, String subject, String body, {String? customSenderEmail, String? customSenderName}) async {
    final apiKey = AppConfig.brevoApiKey;
    final senderEmail = customSenderEmail ?? AppConfig.brevoSenderEmail;
    final senderName = customSenderName ?? AppConfig.brevoSenderName;

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
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }

  // Clear notifications for enterprise admin
  Future<void> clearAdminNotifications() async {
    if (_currentEnterprise == null) return;
    await FirebaseFirestore.instance.collection('enterprises').doc(_currentEnterprise!.id).update({
      'adminNotifications': [],
    });
  }

  // Send a test email to verify credentials
  Future<bool> sendTestEmail(String destinationEmail) async {
    if (_currentEnterprise == null) return false;
    return await _sendEmailViaBrevo(
      destinationEmail,
      "Test de configuration Brevo - G-CRM",
      "Félicitations !\n\nVotre configuration de service de messagerie Brevo sur G-CRM fonctionne parfaitement.\n\nCordialement,\nL'équipe G-CRM.",
      customSenderEmail: _currentEnterprise?.email,
      customSenderName: _currentEnterprise?.name,
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

    final bytes = utf8.encode(csvString);
    final base64Csv = base64.encode(bytes);

    if (AppConfig.brevoApiKey.isNotEmpty && AppConfig.brevoSenderEmail.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('https://api.brevo.com/v3/smtp/email'),
          headers: {
            'accept': 'application/json',
            'api-key': AppConfig.brevoApiKey,
            'content-type': 'application/json',
          },
          body: json.encode({
            'sender': {
              'name': _currentEnterprise?.name ?? AppConfig.brevoSenderName,
              'email': _currentEnterprise?.email ?? AppConfig.brevoSenderEmail,
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
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
  }

  // ===================== BULK COMMUNICATION METHODS =====================

  // Send bulk emails via Brevo
  Future<bool> sendBulkEmail(List<Prospect> prospects, String subject, String body) async {
    if (AppConfig.brevoApiKey.isEmpty || AppConfig.brevoSenderEmail.isEmpty) {
      return false;
    }

    // Filter prospects with emails
    final prospectsWithEmail = prospects.where((p) => p.data['email'] != null && p.data['email']!.isNotEmpty).toList();
    if (prospectsWithEmail.isEmpty) return false;

    try {
      // Send one by one to avoid Brevo bulk issues for small lists
      for (final prospect in prospectsWithEmail) {
        final toEmail = prospect.data['email']!;
        await _sendEmailViaBrevo(
          toEmail,
          subject,
          body,
          customSenderEmail: _currentEnterprise?.email,
          customSenderName: _currentEnterprise?.name,
        );
        await Future.delayed(const Duration(milliseconds: 100)); // Rate limit
      }
      return true;
    } catch (e) {
      debugPrint("Error sending bulk emails: $e");
      return false;
    }
  }

  // Send bulk SMS via Africa's Talking (Simplifié pour l'utilisateur)
  // Fallback sur le Local Android Gateway si Africa's Talking non configuré
  Future<bool> sendBulkSms(List<Prospect> prospects, String message) async {
    // Filter prospects with phone numbers
    final prospectsWithPhone = prospects.where((p) => p.data['telephone'] != null && p.data['telephone']!.isNotEmpty).toList();
    if (prospectsWithPhone.isEmpty) return false;

    // Format phone numbers
    final List<String> phoneNumbers = prospectsWithPhone.map((p) => formatPhoneNumber(p.data['telephone']!)).toList();
    final enterpriseId = _currentEnterprise?.id ?? 'local';

    // Essayer d'abord avec Africa's Talking (plus simple pour l'utilisateur)
    if (AppConfig.africaTalkingApiKey.isNotEmpty && AppConfig.africaTalkingUsername.isNotEmpty) {
      try {
        final success = await _sendSmsViaAfricaTalking(phoneNumbers, message);
        if (success) {
          debugPrint('Bulk SMS envoyé avec succès via Africa\'s Talking');
          return true;
        }
      } catch (e) {
        debugPrint("Erreur avec Africa's Talking: $e, tentative avec Local Gateway...");
      }
    }

    // Fallback sur le Local Android Gateway
    try {
      final result = await SmsService.sendBulkSms(phoneNumbers, message, enterpriseId);
      debugPrint('Bulk SMS result via Local Gateway: $result');
      return result['success'] ?? false;
    } catch (e) {
      debugPrint("Error sending bulk SMS: $e");
      return false;
    }
  }

  // Envoyer SMS via Africa's Talking
  Future<bool> _sendSmsViaAfricaTalking(List<String> phoneNumbers, String message) async {
    try {
      const String url = 'https://api.africastalking.com/version1/messaging';
      
      debugPrint("Using AT Credentials for SMS: Username=${AppConfig.africaTalkingUsername}, APIKey=${AppConfig.africaTalkingApiKey.substring(0, 5)}...");
      
      // Formater les numéros en +XXXXXXXXX
      final formattedNumbers = phoneNumbers.map((num) {
        if (!num.startsWith('+')) {
          return '+$num';
        }
        return num;
      }).join(',');

      final body = {
        'username': AppConfig.africaTalkingUsername,
        'to': formattedNumbers,
        'message': message,
        'from': AppConfig.africaTalkingPhoneNumber.isEmpty ? null : AppConfig.africaTalkingPhoneNumber,
      };

      // Filtrer les valeurs nulles
      final filteredBody = Map.fromEntries(
        body.entries.where((entry) => entry.value != null)
      );

      debugPrint("Sending SMS via Africa's Talking to: $formattedNumbers");

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'apiKey': AppConfig.africaTalkingApiKey,
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: filteredBody,
      );

      debugPrint("AT SMS Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error sending SMS via Africa's Talking: $e");
      rethrow;
    }
  }

  // Open WhatsApp with pre-filled message for each prospect (semi-manual)
  Future<void> openWhatsAppBulk(List<Prospect> prospects, String message) async {
    // Filter prospects with phone numbers
    final prospectsWithPhone = prospects.where((p) => p.data['telephone'] != null && p.data['telephone']!.isNotEmpty).toList();
    if (prospectsWithPhone.isEmpty) return;

    // Open first one, user can do others manually
    final firstProspect = prospectsWithPhone.first;
    final phoneNumber = formatPhoneNumber(firstProspect.data['telephone']!);
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = 'https://wa.me/$phoneNumber?text=$encodedMessage';

    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    }
  }

  // Initiate automated calls via Africa's Talking
  Future<bool> initiateAutoCalls(List<Prospect> prospects, String messageText) async {
    if (AppConfig.africaTalkingApiKey.isEmpty || AppConfig.africaTalkingUsername.isEmpty) {
      return false;
    }

    // Filter prospects with phone numbers
    final prospectsWithPhone = prospects.where((p) => p.data['telephone'] != null && p.data['telephone']!.isNotEmpty).toList();
    if (prospectsWithPhone.isEmpty) return false;

    try {
      // Africa's Talking Voice API endpoint
      const String url = 'https://voice.africastalking.com/call';
      
      debugPrint("Using AT Credentials: Username=${AppConfig.africaTalkingUsername}, APIKey=${AppConfig.africaTalkingApiKey.substring(0, 5)}...");
      
      // We process one by one or via bulk if AT supports it
      for (final prospect in prospectsWithPhone) {
        final phoneNumber = formatPhoneNumber(prospect.data['telephone']!);
        
        final body = {
          'username': AppConfig.africaTalkingUsername,
          'from': AppConfig.africaTalkingPhoneNumber.isEmpty ? '+229' : AppConfig.africaTalkingPhoneNumber,
          'to': '+$phoneNumber',
        };
        
        debugPrint("Calling $phoneNumber with body: $body");

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'apiKey': AppConfig.africaTalkingApiKey,
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body,
        );

        debugPrint("AT Voice Response: ${response.statusCode} - ${response.body}");

        if (response.statusCode != 200 && response.statusCode != 201) {
          debugPrint("Failed to initiate call to $phoneNumber. Status: ${response.statusCode}");
        }
      }

      debugPrint("Attempted to initiate auto calls for ${prospectsWithPhone.length} prospects via Africa's Talking");
      return true;
    } catch (e) {
      debugPrint("Error initiating auto calls: $e");
      return false;
    }
  }
}
