import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../models/enterprise.dart';
import '../../models/agent.dart';
import '../../models/prospect.dart';
import '../../theme.dart';
import '../auth/role_selection_screen.dart';
import '../chat/chat_screen.dart';
import '../chat/enterprise_chat_list_screen.dart';
import '../notifications/notification_screen.dart';
import '../../services/pdf_service.dart';
import '../agent/prospect_detail_screen.dart';
import '../../app_config.dart';
import '../../services/whatsapp_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'subscription_screen.dart';

import 'package:intl/intl.dart';

class EnterpriseDashboard extends StatefulWidget {
  const EnterpriseDashboard({super.key});

  @override
  State<EnterpriseDashboard> createState() => _EnterpriseDashboardState();
}

class _EnterpriseDashboardState extends State<EnterpriseDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final companyName = db.currentEnterprise?.name ?? 'Entreprise';

    final List<Widget> children = [
      const _AnalyticsTab(),
      const _AgentsTab(),
      const _HistoryTab(),
      const _CommunicationTab(),
      const _TaskAssignmentTab(),
      const _SettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(companyName),
        actions: [
          Stack(
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none, color: AppTheme.secondaryColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationScreen()),
                  );
                },
              ),
              if (db.getUnreadNotificationsCount() > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      db.getUnreadNotificationsCount().toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                tooltip: 'Messagerie',
                icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.secondaryColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EnterpriseChatListScreen()),
                  );
                },
              ),
              if (db.getUnreadMessagesCount() > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      db.getUnreadMessagesCount().toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Abonnements',
            icon: const Icon(Icons.credit_card_outlined, color: AppTheme.primaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout, color: AppTheme.errorColor),
            onPressed: () async {
              await db.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: db.isInitialized 
          ? children[_currentIndex]
          : const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textLight,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Équipe',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send_outlined),
            activeIcon: Icon(Icons.send),
            label: 'Communication',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in_outlined),
            activeIcon: Icon(Icons.assignment_turned_in),
            label: 'Tâches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}

// ================= 1. ANALYTICS TAB =================
class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  Widget _buildQuotaSection(DatabaseService db) {
    final enterprise = db.currentEnterprise;
    if (enterprise == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Crédits de prospection",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.secondaryColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Plan ${enterprise.planId}",
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQuotaGauge("Appels Manuels", enterprise.appelsManuelsRestants, _getMaxQuota(enterprise.planId, 'appels')),
            const SizedBox(height: 12),
            _buildQuotaGauge("SMS Manuels", enterprise.smsManuelsRestants, _getMaxQuota(enterprise.planId, 'sms')),
            const SizedBox(height: 12),
            _buildQuotaGauge("WhatsApp Manuels", enterprise.whatsappManuelsRestants, _getMaxQuota(enterprise.planId, 'whatsapp')),
          ],
        ),
      ),
    );
  }

  int _getMaxQuota(String plan, String type) {
    if (plan == 'DISCOVERY') {
      if (type == 'appels') return 300;
      if (type == 'sms') return 300;
      if (type == 'whatsapp') return 150;
    } else if (plan == 'STARTER') {
      if (type == 'appels') return 600;
      if (type == 'sms') return 600;
      if (type == 'whatsapp') return 400;
    } else if (plan == 'PRO') {
      if (type == 'appels') return 3500;
      if (type == 'sms') return 3500;
      if (type == 'whatsapp') return 1800;
    } else if (plan == 'BUSINESS') {
      if (type == 'appels') return 10000;
      if (type == 'sms') return 10000;
      if (type == 'whatsapp') return 5000;
    }
    return 100; // default
  }

  Widget _buildQuotaGauge(String label, int remaining, int max) {
    final int used = max - remaining;
    final double percent = max > 0 ? (used / max).clamp(0.0, 1.0) : 0;
    final Color color = percent > 0.8 ? AppTheme.errorColor : (percent > 0.5 ? AppTheme.warningColor : AppTheme.successColor);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text("$used / $max", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final List<Prospect> prospects = db.getProspectsForCurrentEnterprise();
    final agents = db.getAgentsForCurrentEnterprise();

    final total = prospects.length;
    final ok = prospects.where((x) => x.status == 'ok' || x.status == 'Succès').length;
    final non = prospects.where((x) => x.status == 'non' || x.status == 'Refus').length;
    final unreachable = prospects.where((x) => x.status == 'unreachable' || x.status == 'Injoignable').length;

    final agentCounts = db.getProspectCountPerAgent();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/banner.png',
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink(); // Fallback if missing
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Admin Blocked Emails Notifications
          if (db.currentEnterprise != null && db.currentEnterprise!.adminNotifications.isNotEmpty) ...[
            Card(
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 22),
                            SizedBox(width: 8),
                            Text(
                              "Alertes de Relance (Quota Expiré)",
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor, fontSize: 13),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => db.clearAdminNotifications(),
                          child: const Text("Effacer", style: TextStyle(color: AppTheme.errorColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...db.currentEnterprise!.adminNotifications.reversed.map((notif) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.arrow_right, size: 16, color: AppTheme.textLight),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              notif,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textDark, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 16),
          
          _buildQuotaSection(db),
          
          const SizedBox(height: 24),

          const Text(
            "Vue d'ensemble de la prospection",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 16),
          
          // PDF Export Button
          ElevatedButton.icon(
            onPressed: prospects.isEmpty ? null : () => PdfService.exportFicheCRM(prospects),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Exporter la Fiche CRM Globale (PDF)"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Prospects',
                  total.toString(),
                  Icons.group,
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Intéressés (OK)',
                  ok.toString(),
                  Icons.check_circle,
                  AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Indisponibles',
                  unreachable.toString(),
                  Icons.phone_missed,
                  AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Refusés',
                  non.toString(),
                  Icons.cancel,
                  AppTheme.errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Agents Activity List
          const Text(
            "Performance des Agents",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 12),
          
          if (agents.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Aucun agent enregistré pour le moment. Allez sur l'onglet 'Équipe' pour en ajouter.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textLight, fontSize: 13),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                final count = agentCounts[agent.name] ?? 0;
                final callPerf = db.getCallPerformancePerAgent()[agent.name] ?? {'ok': 0, 'non': 0, 'unreachable': 0, 'pending': 0};
                final unreadAgentMessages = db.getUnreadMessagesCount(forAgentId: agent.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              agent.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') _showEditAgentDialog(context, agent);
                                if (val == 'delete') _showDeleteAgentDialog(context, agent);
                                if (val == 'prospects') _showAgentProspectsDialog(context, agent);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Modifier")])),
                                const PopupMenuItem(value: 'prospects', child: Row(children: [Icon(Icons.list, size: 18), SizedBox(width: 8), Text("Voir ses prospects")])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppTheme.errorColor), SizedBox(width: 8), Text("Supprimer", style: TextStyle(color: AppTheme.errorColor))])),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          agent.email,
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMiniStat('Succès', callPerf['ok']!, AppTheme.successColor),
                                  _buildMiniStat('Refus', callPerf['non']!, AppTheme.errorColor),
                                  _buildMiniStat('Injoign.', callPerf['unreachable']!, AppTheme.warningColor),
                                  _buildMiniStat('Attente', callPerf['pending']!, AppTheme.textLight),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          agentId: agent.id,
                                          agentName: agent.name,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor),
                                  tooltip: 'Contacter l\'agent',
                                ),
                                if (unreadAgentMessages > 0)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.errorColor,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        unreadAgentMessages.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showEditAgentDialog(BuildContext context, Agent agent) {
    final nameController = TextEditingController(text: agent.name);
    final emailController = TextEditingController(text: agent.email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier l'agent"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nom")),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<DatabaseService>(context, listen: false)
                  .updateAgent(agent.id, nameController.text, emailController.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Sauvegarder"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAgentDialog(BuildContext context, Agent agent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer l'agent"),
        content: Text("Voulez-vous vraiment supprimer ${agent.name} ? Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              await Provider.of<DatabaseService>(context, listen: false).deleteAgent(agent.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAgentProspectsDialog(BuildContext context, Agent agent) {
    showDialog(
      context: context,
      builder: (context) {
        final db = Provider.of<DatabaseService>(context);
        final agentProspects = db.allProspects.where((p) => p.agentId == agent.id).toList();

        return AlertDialog(
          title: Text("Prospects de ${agent.name}"),
          content: SizedBox(
            width: double.maxFinite,
            child: agentProspects.isEmpty
                ? const Text("Aucun prospect géré.")
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: agentProspects.length,
                    itemBuilder: (context, index) {
                      final p = agentProspects[index];
                      return ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProspectDetailScreen(prospectId: p.id),
                            ),
                          );
                        },
                        title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text("Statut: ${p.status}", style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove, color: AppTheme.errorColor, size: 20),
                          tooltip: "Retirer de cet agent",
                          onPressed: () async {
                            await db.unassignProspect(p.id);
                            // After unassigning, we might want to refresh UI or close dialog
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, int val, Color color) {
    return Column(
      children: [
        Text(
          val.toString(),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppTheme.textLight),
        ),
      ],
    );
  }
}

// ================= 2. AGENTS MANAGEMENT TAB =================
class _AgentsTab extends StatefulWidget {
  const _AgentsTab();

  @override
  State<_AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<_AgentsTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAgent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isCreating = true);
    final db = Provider.of<DatabaseService>(context, listen: false);

    final success = await db.createAgent(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
    );

    setState(() => _isCreating = false);

    if (context.mounted) {
      if (success) {
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Compte Agent créé avec succès !"),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cet email est déjà utilisé par un autre utilisateur."),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final agents = db.getAgentsForCurrentEnterprise();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Registration Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Créer un nouveau compte Agent",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Nom de l'agent",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.isEmpty ? "Entrez le nom de l'agent" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Adresse email de l'agent",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Entrez l'email de l'agent";
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                          return "Email invalide";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: "Mot de passe de l'agent",
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v == null || v.isEmpty || v.length < 6 ? "Mot de passe de 6 caractères min." : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isCreating ? null : _createAgent,
                      icon: const Icon(Icons.person_add),
                      label: Text(_isCreating ? "Création..." : "Ajouter l'Agent"),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Agents List Header
          Text(
            "Liste de vos Agents (${agents.length})",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
          ),
          const SizedBox(height: 12),

          if (agents.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "Aucun agent enregistré pour le moment.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textLight),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _showAgentProspectsDialog(context, agent),
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.person),
                    ),
                    title: Text(agent.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(agent.email),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'edit') _showEditAgentDialog(context, agent);
                        if (val == 'delete') _showDeleteAgentDialog(context, agent);
                        if (val == 'assign') _showAssignToAgentDialog(context, agent);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Modifier")]),
                        ),
                        const PopupMenuItem(
                          value: 'assign',
                          child: Row(children: [Icon(Icons.person_add, size: 18), SizedBox(width: 8), Text("Attribuer des prospects")]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: AppTheme.errorColor),
                              SizedBox(width: 8),
                              Text("Supprimer", style: TextStyle(color: AppTheme.errorColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showEditAgentDialog(BuildContext context, Agent agent) {
    final nameController = TextEditingController(text: agent.name);
    final emailController = TextEditingController(text: agent.email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier l'agent"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nom")),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<DatabaseService>(context, listen: false)
                  .updateAgent(agent.id, nameController.text, emailController.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Sauvegarder"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAgentDialog(BuildContext context, Agent agent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer l'agent"),
        content: Text("Voulez-vous vraiment supprimer ${agent.name} ? Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              await Provider.of<DatabaseService>(context, listen: false).deleteAgent(agent.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAgentProspectsDialog(BuildContext context, Agent agent) {
    showDialog(
      context: context,
      builder: (context) {
        final db = Provider.of<DatabaseService>(context);
        final agentProspects = db.allProspects.where((p) => p.agentId == agent.id).toList();

        return AlertDialog(
          title: Text("Prospects de ${agent.name}"),
          content: SizedBox(
            width: double.maxFinite,
            child: agentProspects.isEmpty
                ? const Text("Aucun prospect géré.")
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: agentProspects.length,
                    itemBuilder: (context, index) {
                      final p = agentProspects[index];
                      return ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProspectDetailScreen(prospectId: p.id),
                            ),
                          );
                        },
                        title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text("Statut: ${p.status}", style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove, color: AppTheme.errorColor, size: 20),
                          tooltip: "Retirer de cet agent",
                          onPressed: () async {
                            await db.unassignProspect(p.id);
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
          ],
        );
      },
    );
  }

  void _showAssignToAgentDialog(BuildContext context, Agent agent) {
    showDialog(
      context: context,
      builder: (context) {
        final db = Provider.of<DatabaseService>(context);
        final unassignedProspects = db.allProspects.where((p) => p.agentId == null || p.agentId!.isEmpty).toList();
        final Set<String> selectedIds = {};

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("Attribuer à ${agent.name}"),
            content: SizedBox(
              width: double.maxFinite,
              child: unassignedProspects.isEmpty
                  ? const Text("Aucun prospect libre à attribuer.")
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Sélectionnez les prospects à confier à cet agent :", style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: unassignedProspects.length,
                            itemBuilder: (context, index) {
                              final p = unassignedProspects[index];
                              final isSelected = selectedIds.contains(p.id);
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(p.name, style: const TextStyle(fontSize: 14)),
                                subtitle: Text(p.data['telephone'] ?? '', style: const TextStyle(fontSize: 11)),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) selectedIds.add(p.id);
                                    else selectedIds.remove(p.id);
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: selectedIds.isEmpty ? null : () async {
                  await db.assignProspectsToAgent(agent.id, selectedIds.toList());
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("Attribuer"),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================= 3. HISTORIQUE TAB =================
class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  int _currentPage = 0;
  final int _pageSize = 10;
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    
    final prospects = db.getPaginatedProspects(
      page: _currentPage,
      pageSize: _pageSize,
      searchQuery: _searchQuery,
      startDate: _startDate,
      endDate: _endDate,
    );

    final totalCount = db.getTotalProspectCount(
      searchQuery: _searchQuery,
      startDate: _startDate,
      endDate: _endDate,
    );

    final totalPages = (totalCount / _pageSize).ceil();

    return Column(
      children: [
        // Filters Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: "Rechercher par nom, tel...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = ''))
                    : null,
                ),
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _currentPage = 0;
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked.start;
                            _endDate = picked.end;
                            _currentPage = 0;
                          });
                        }
                      },
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        _startDate == null 
                          ? "Filtrer par date" 
                          : "${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  if (_startDate != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _startDate = null;
                        _endDate = null;
                        _currentPage = 0;
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: prospects.isEmpty
              ? const Center(child: Text("Aucun prospect trouvé."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: prospects.length,
                  itemBuilder: (context, index) {
                    final p = prospects[index];
                    return _buildHistoryTile(p);
                  },
                ),
        ),

        // Pagination Footer
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                ),
                Text("Page ${_currentPage + 1} sur $totalPages"),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTile(Prospect p) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          "${p.data['prenom'] ?? ''} ${p.data['nom'] ?? 'Inconnu'}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Le ${DateFormat('dd/MM/yyyy').format(p.createdAt)} - Statut: ${p.status.toUpperCase()}",
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _infoRow("Téléphone", p.data['telephone'] ?? 'N/A'),
                _infoRow("Email", p.data['email'] ?? 'N/A'),
                _infoRow("Entreprise", p.data['entreprise'] ?? 'N/A'),
                _infoRow("Note", p.data['note'] ?? 'N/A'),
                _infoRow("Agent responsable", db.allAgents.firstWhere((a) => a.id == p.agentId, orElse: () => Agent(id: '', enterpriseId: '', name: 'Non assigné', email: '', createdAt: DateTime.now())).name),
                const Divider(),
                const SizedBox(height: 8),
                const Text("Actions rapides:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProspectDetailScreen(prospectId: p.id),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text("Voir le suivi détaillé", style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAssignDialog(context, p),
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text("Réattribuer l'agent", style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Historique des appels:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                if (p.callAttempts.isEmpty)
                  const Text("Aucun appel tenté.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic))
                else
                  ...p.callAttempts.map((a) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "- ${DateFormat('dd/MM HH:mm').format(a.timestamp)} : ${_translateStatus(a.verdict)} (${a.note})",
                      style: const TextStyle(fontSize: 11),
                    ),
                  )),
              ],
            ),
          )
        ],
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'Succès': return 'Succès';
      case 'Refus': return 'Refus';
      case 'unreachable': return 'Injoignable';
      case 'En attente': return 'En attente';
      default: return status.toUpperCase();
    }
  }

  void _showAssignDialog(BuildContext context, Prospect p) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final agents = db.getAgentsForCurrentEnterprise();
    String? selectedAgentId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Attribuer ${p.name}"),
          content: agents.isEmpty
              ? const Text("Aucun agent disponible.")
              : DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Choisir un agent"),
                  items: agents.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (val) => setDialogState(() => selectedAgentId = val),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: selectedAgentId == null ? null : () async {
                await db.assignProspectsToAgent(selectedAgentId!, [p.id]);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${p.name} attribué !"), backgroundColor: AppTheme.successColor),
                  );
                }
              },
              child: const Text("Confirmer"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

// ================= 4. COMMUNICATION / MESSAGERIE GROUPÉE TAB =================
enum _CommView { serviceList, prospectSelection, progress }
enum _CommService { sms, call, email, whatsapp }

class _CommunicationTab extends StatefulWidget {
  const _CommunicationTab();

  @override
  State<_CommunicationTab> createState() => _CommunicationTabState();
}

class _CommunicationTabState extends State<_CommunicationTab> {
  _CommView _currentView = _CommView.serviceList;
  _CommService? _selectedService;
  
  final Set<String> _selectedProspectIds = {};
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _limitController = TextEditingController(text: "10");
  
  String _activeFilter = 'all'; // all, recently, threeDaysAgo, unreachable, topN
  String? _selectedTemplate;
  
  // Progress tracking
  int _progressCurrent = 0;
  int _progressTotal = 0;
  int _progressSuccess = 0;
  int _progressFail = 0;
  bool _isOperationRunning = false;
  List<String> _operationLogs = [];

  @override
  void dispose() {
    _messageController.dispose();
    _subjectController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _resetState() {
    setState(() {
      _currentView = _CommView.serviceList;
      _selectedService = null;
      _selectedProspectIds.clear();
      _messageController.clear();
      _subjectController.clear();
      _selectedTemplate = null;
      _progressCurrent = 0;
      _progressTotal = 0;
      _progressSuccess = 0;
      _progressFail = 0;
      _isOperationRunning = false;
      _operationLogs.clear();
    });
  }

  List<Prospect> _applyAdvancedFilter(List<Prospect> prospects) {
    final now = DateTime.now();
    List<Prospect> filtered = List.from(prospects);

    switch (_activeFilter) {
      case 'recently':
        filtered = filtered.where((p) => now.difference(p.createdAt).inHours <= 24).toList();
        break;
      case 'threeDaysAgo':
        filtered = filtered.where((p) {
          final diff = now.difference(p.createdAt).inDays;
          return diff >= 3 && diff < 4;
        }).toList();
        break;
      case 'unreachable':
        filtered = filtered.where((p) => p.status == 'Injoignable' || p.status == 'unreachable').toList();
        break;
      case 'topN':
        final limit = int.tryParse(_limitController.text) ?? 10;
        filtered = filtered.take(limit).toList();
        break;
    }
    return filtered;
  }

  Future<void> _startOperation(DatabaseService db, List<Prospect> targets) async {
    if (targets.isEmpty) return;
    
    if (_selectedService == _CommService.email && _subjectController.text.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sujet requis pour l'email.")));
      return;
    }
    if (_messageController.text.isEmpty && _selectedService != _CommService.whatsapp) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message requis.")));
       return;
    }

    if (mounted) {
      setState(() {
        _currentView = _CommView.progress;
        _progressTotal = targets.length;
        _progressCurrent = 0;
        _progressSuccess = 0;
        _progressFail = 0;
        _isOperationRunning = true;
        _operationLogs.add("Démarrage de l'opération : ${_getServiceLabel(_selectedService!)}");
      });
    }

    // Mettre à jour l'état global dans DatabaseService
    db.updateCommOperation(
      isRunning: true,
      total: targets.length,
      current: 0,
      label: _getServiceLabel(_selectedService!),
      log: "Démarrage de l'opération : ${_getServiceLabel(_selectedService!)}",
    );

    // Cas spécial pour WhatsApp : envoi direct avec délai anti-ban
    if (_selectedService == _CommService.whatsapp) {
      final enterpriseId = db.currentEnterprise?.id;
      if (enterpriseId != null) {
        for (var i = 0; i < targets.length; i++) {
          if (!db.isCommOperationRunning) {
            _operationLogs.add("🛑 Opération annulée.");
            if (mounted) setState(() => _isOperationRunning = false);
            break;
          }
          if (!mounted) break;

          final p = targets[i];
          final name = "${p.data['prenom'] ?? ''} ${p.data['nom'] ?? ''}";
          String errorMsg = "";
          bool success = false;

          try {
            final result = await WhatsAppService.sendSingleMessage(
              enterpriseId: enterpriseId,
              phone: p.data['telephone'] ?? '',
              message: _messageController.text,
            );
            success = result['success'] == true;
            if (!success) {
              errorMsg = result['error'] ?? "Échec";
            }
          } catch (e) {
            errorMsg = "Erreur technique";
          }

          // Mettre à jour la progression locale et globale
          final logMessage = success ? "✅ Succès: $name" : "❌ $errorMsg: $name";
          
          if (mounted) {
            setState(() {
              _progressCurrent = i + 1;
              if (success) {
                _progressSuccess++;
              } else {
                _progressFail++;
              }
              _operationLogs.add(logMessage);
            });
          }

          db.updateCommOperation(
            isRunning: true,
            current: i + 1,
            log: logMessage,
          );

          // Délai anti-ban aléatoire entre 5 et 15 secondes (sauf pour le dernier message)
          if (i < targets.length - 1 && db.isCommOperationRunning) {
            final randomDelay = 5 + Random().nextInt(11);
            final delayLog = "⏳ Pause anti-ban ${randomDelay}s...";
            if (mounted) {
              setState(() {
                _operationLogs.add(delayLog);
              });
            }
            db.updateCommOperation(isRunning: true, log: delayLog);
            
            // Attendre par petits intervalles pour réagir à l'annulation
            for (int d = 0; d < randomDelay * 10; d++) {
              if (!db.isCommOperationRunning || !mounted) break;
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }
        }

        if (mounted) {
          setState(() {
            _isOperationRunning = false;
            if (db.isCommOperationRunning) _operationLogs.add("Opération terminée.");
          });
        }
        db.updateCommOperation(isRunning: false);
      }
      return;
    }

    // Traitements normaux pour les autres services
    for (var i = 0; i < targets.length; i++) {
      if (!db.isCommOperationRunning) {
        if (mounted) {
          setState(() {
            _isOperationRunning = false;
            _operationLogs.add("🛑 Opération annulée.");
          });
        }
        break;
      }
      if (!mounted) break;
      
      final p = targets[i];
      final name = "${p.data['prenom'] ?? ''} ${p.data['nom'] ?? ''}";
      
      bool success = false;
      try {
        switch (_selectedService!) {
          case _CommService.email:
            success = await db.sendEmailToProspect(
              prospectId: p.id, 
              subject: _subjectController.text, 
              content: _messageController.text
            ).timeout(const Duration(seconds: 30), onTimeout: () => false);
            break;
          case _CommService.sms:
            success = await db.sendBulkSms([p], _messageController.text).timeout(const Duration(seconds: 30), onTimeout: () => false);
            break;
          case _CommService.call:
            success = await db.initiateAutoCalls([p], _messageController.text).timeout(const Duration(seconds: 30), onTimeout: () => false);
            break;
          case _CommService.whatsapp:
            // Déjà traité ci-dessus
            break;
        }
      } catch (e) {
        success = false;
      }

      final logMessage = success ? "✅ Succès : $name" : "❌ Échec : $name";

      if (mounted) {
        setState(() {
          _progressCurrent = i + 1;
          if (success) {
            _progressSuccess++;
          } else {
            _progressFail++;
          }
          _operationLogs.add(logMessage);
        });
      }

      db.updateCommOperation(
        isRunning: true,
        current: i + 1,
        log: logMessage,
      );
      
      // Petit délai entre les opérations
      if (db.isCommOperationRunning) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (mounted) {
      setState(() {
        _isOperationRunning = false;
        if (db.isCommOperationRunning) _operationLogs.add("Opération terminée.");
      });
    }
    db.updateCommOperation(isRunning: false);
  }

  String _getServiceLabel(_CommService service) {
    switch (service) {
      case _CommService.sms: return "SMS Groupé";
      case _CommService.call: return "Appel Automatique";
      case _CommService.email: return "Email Groupé";
      case _CommService.whatsapp: return "WhatsApp Groupé";
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    
    // Si une opération globale est en cours mais qu'on n'est pas sur la vue de progression,
    // on force l'affichage de la progression si on est dans l'onglet communication.
    if (db.isCommOperationRunning && _currentView != _CommView.progress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentView = _CommView.progress;
            _isOperationRunning = true;
            _progressTotal = db.commProgressTotal;
            _progressCurrent = db.commProgressCurrent;
            // On ne peut pas facilement récupérer les logs détaillés ici sans changer plus de code,
            // mais on synchronise au moins l'état de la vue.
          });
        }
      });
    }

    switch (_currentView) {
      case _CommView.serviceList:
        return _buildServiceList();
      case _CommView.prospectSelection:
        return _buildProspectSelection(db);
      case _CommView.progress:
        return _buildProgressView();
    }
  }

  Widget _buildServiceList() {
    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: 0.85, // Donne plus de hauteur aux cartes pour éviter les débordements
      children: [
        _buildServiceCard(_CommService.sms, Icons.sms, Colors.green, "Envoyez des SMS à vos prospects en un clic.", isAvailable: false),
        _buildServiceCard(_CommService.call, Icons.phone_callback, Colors.orange, "Lancez des appels automatisés avec message vocal.", isAvailable: false),
        _buildServiceCard(_CommService.email, Icons.email, Colors.blue, "Envoyez des emails personnalisés en masse.", isAvailable: true),
        _buildServiceCard(_CommService.whatsapp, Icons.chat, Colors.teal, "Contactez vos prospects via WhatsApp (Automatisé).", isAvailable: false),
      ],
    );
  }

  Widget _buildServiceCard(_CommService service, IconData icon, Color color, String desc, {bool isAvailable = true}) {
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5,
      child: InkWell(
        onTap: () async {
          if (!isAvailable) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Service momentanément indisponible ou en cours de développement."),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          final db = Provider.of<DatabaseService>(context, listen: false);
        
        // Vérification spéciale pour WhatsApp
        if (service == _CommService.whatsapp) {
          final enterpriseId = db.currentEnterprise?.id;
          if (enterpriseId != null) {
            final statusResult = await WhatsAppService.getInstanceStatus(enterpriseId);
            if (statusResult['status'] != 'connected') {
              // Redirection vers les paramètres si non connecté
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Veuillez connecter votre WhatsApp dans les paramètres d'abord."),
                    backgroundColor: Colors.orange,
                  ),
                );
                // On peut imaginer une logique ici pour forcer l'onglet paramètres, 
                // mais pour l'instant on informe l'utilisateur.
              }
              return;
            }
          }
        }

        setState(() {
          _selectedService = service;
          _currentView = _CommView.prospectSelection;
        });
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                _getServiceLabel(service),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  desc,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildProspectSelection(DatabaseService db) {
    final allProspects = db.getProspectsForCurrentEnterprise();
    final filteredProspects = _applyAdvancedFilter(allProspects);
    final templates = db.currentEnterprise?.messageTemplates ?? [];
    final selectedTargets = filteredProspects.where((p) => _selectedProspectIds.contains(p.id)).toList();

    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.secondaryColor),
            onPressed: () => setState(() => _currentView = _CommView.serviceList),
          ),
          title: Text(_getServiceLabel(_selectedService!), style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        
        // Advanced Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip("Tous", 'all'),
              _buildFilterChip("Dernières 24h", 'recently'),
              _buildFilterChip("Il y a 3 jours", 'three_days'), // In code logic it was threeDaysAgo, fixing below
              _buildFilterChip("Injoignables", 'unreachable'),
              _buildFilterChip("Top N", 'topN'),
            ],
          ),
        ),

        if (_activeFilter == 'topN')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("Nombre de prospects : ", style: TextStyle(fontSize: 13)),
                SizedBox(
                  width: 60,
                  height: 35,
                  child: TextField(
                    controller: _limitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8), border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),

        // Message Section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (templates.isNotEmpty)
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(labelText: "Modèle de message", border: OutlineInputBorder()),
                  value: _selectedTemplate,
                  items: [const DropdownMenuItem(value: null, child: Text("Aucun")), ...templates.map((t) => DropdownMenuItem(value: t.content, child: Text(t.title)))],
                  onChanged: (val) => setState(() { _selectedTemplate = val; if (val != null) _messageController.text = val; }),
                ),
              const SizedBox(height: 12),
              if (_selectedService == _CommService.email)
                TextField(controller: _subjectController, decoration: const InputDecoration(labelText: "Sujet de l'email", border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Votre message...", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),

        // Selection Summary & Action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${_selectedProspectIds.length} sélectionné(s)", style: const TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: _selectedProspectIds.isEmpty ? null : () => _startOperation(db, selectedTargets),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                child: const Text("DÉMARRER"),
              ),
            ],
          ),
        ),

        const Divider(),
        
        // Multi-select actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedProspectIds.addAll(filteredProspects.map((p) => p.id))),
                icon: const Icon(Icons.check_box),
                label: const Text("Tout cocher"),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedProspectIds.clear()),
                icon: const Icon(Icons.check_box_outline_blank),
                label: const Text("Tout décocher"),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            itemCount: filteredProspects.length,
            itemBuilder: (context, index) {
              final p = filteredProspects[index];
              final isSelected = _selectedProspectIds.contains(p.id);
              return CheckboxListTile(
                value: isSelected,
                title: Text("${p.data['prenom'] ?? ''} ${p.data['nom'] ?? ''}"),
                subtitle: Text(p.status, style: TextStyle(fontSize: 12, color: _getStatusColor(p.status))),
                onChanged: (_) => setState(() => isSelected ? _selectedProspectIds.remove(p.id) : _selectedProspectIds.add(p.id)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _activeFilter == value || (_activeFilter == 'threeDaysAgo' && value == 'three_days');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 12)),
        selected: isSelected,
        onSelected: (val) => setState(() {
          if (value == 'three_days') _activeFilter = 'threeDaysAgo';
          else _activeFilter = value;
          _selectedProspectIds.clear();
        }),
        selectedColor: AppTheme.primaryColor,
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildProgressView() {
    final double percent = _progressTotal > 0 ? _progressCurrent / _progressTotal : 0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isOperationRunning ? "Opération en cours..." : "Opération terminée",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                  ),
                  const SizedBox(height: 30),
                  
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 20,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${(_progressCurrent)} / $_progressTotal traités (${(percent * 100).toInt()}%)",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem("Succès", _progressSuccess, Colors.green),
                      _buildStatItem("Échecs", _progressFail, Colors.red),
                      _buildStatItem("Total", _progressTotal, Colors.blue),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  const Text("Journal d'activité", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  // Logs - Fixed height instead of Expanded to avoid overflow issues in tight constraints
                  Container(
                    height: 200, // Hauteur fixe pour les logs
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _operationLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            _operationLogs[_operationLogs.length - 1 - index],
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  if (!_isOperationRunning)
                    ElevatedButton(
                      onPressed: _resetState,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text("RETOUR AU MENU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  else
                    OutlinedButton(
                      onPressed: () {
                        final db = Provider.of<DatabaseService>(context, listen: false);
                        db.updateCommOperation(isRunning: false);
                        if (mounted) {
                          setState(() {
                            _isOperationRunning = false;
                            _operationLogs.add("🛑 Demande d'arrêt envoyée...");
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text("ANNULER L'OPÉRATION", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Succès': return AppTheme.successColor;
      case 'Refus': return AppTheme.errorColor;
      case 'Injoignable':
      case 'unreachable': return AppTheme.warningColor;
      default: return Colors.grey;
    }
  }
}

// ================= 5. PARAMÈTRES / CONFIGURATION TAB =================
class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  int _activeSettingIndex = 0; // 0: Form, 2: App Config, 3: Verdicts, 4: Modèles, 5: WhatsApp
  List<ProspectFieldSetting> _tempSettings = [];
  bool _isLoaded = false;

  final _apiKeyController = TextEditingController();
  final _senderEmailController = TextEditingController();
  final _countryCodeController = TextEditingController();
  final _verdictController = TextEditingController();
  final _templateTitleController = TextEditingController();
  final _templateContentController = TextEditingController();
  final _africaTalkingApiKeyController = TextEditingController();
  final _africaTalkingUsernameController = TextEditingController();
  final _whatsappPhoneNumberController = TextEditingController();
  final _brevoFormKey = GlobalKey<FormState>();
  bool _testingEmail = false;
  
  // WhatsApp State
  String? _whatsappStatus;
  String? _whatsappQrCode;
  String? _whatsappPairingCode;
  bool _isConnectingWhatsapp = false;
  bool _usePairingCode = false;
  bool _whatsappTabLoaded = false;
  int _whatsappPollAttempts = 0;
  bool _monitorFetchQr = false;
  String? _pairingPhoneUsed;
  Timer? _whatsappStatusTimer;
  Map<String, dynamic>? _queueStatus;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _senderEmailController.dispose();
    _countryCodeController.dispose();
    _verdictController.dispose();
    _templateTitleController.dispose();
    _templateContentController.dispose();
    _africaTalkingApiKeyController.dispose();
    _africaTalkingUsernameController.dispose();
    _whatsappPhoneNumberController.dispose();
    _whatsappStatusTimer?.cancel();
    super.dispose();
  }

  void _applyConnectionInfo(Map<String, dynamic> info) {
    final status = info['status'] as String? ?? 'disconnected';
    final qr = info['qrCode'] as String?;

    if (status == 'connected') {
      _whatsappStatus = 'connected';
      _whatsappQrCode = null;
    } else if (qr != null && qr.isNotEmpty) {
      _whatsappStatus = 'qr_ready';
      _whatsappQrCode = qr;
    } else if (status == 'connecting' || status == 'close') {
      _whatsappStatus = 'instance_exists';
      _whatsappQrCode = null;
    } else {
      _whatsappStatus = status == 'disconnected' ? null : status;
      _whatsappQrCode = null;
    }
  }

  Uint8List _decodeQrImage(String raw) {
    final base64Str = raw.contains(',') ? raw.split(',').last : raw;
    return Uint8List.fromList(base64Decode(base64Str));
  }

  Future<void> _loadWhatsAppState(String enterpriseId) async {
    try {
      final exists = await WhatsAppService.instanceExists(enterpriseId);
      if (!mounted) return;

      if (!exists) {
        setState(() {
          _whatsappStatus = null;
          _whatsappQrCode = null;
          _whatsappPairingCode = null;
        });
        return;
      }

      final info = await WhatsAppService.getInstanceStatus(enterpriseId);
      if (!mounted) return;
      setState(() => _applyConnectionInfo(info));
    } catch (_) {
      if (mounted) setState(() => _whatsappStatus = null);
    }
  }

  String? _validateWhatsAppPhone(String input) {
    final clean = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return 'Veuillez entrer votre numéro WhatsApp';
    if (!clean.startsWith('229')) {
      return 'Le numéro doit commencer par 229 (ex: 2290157543682)';
    }
    if (clean.length < 12 || clean.length > 13) {
      return 'Numéro invalide. Format: 229XXXXXXXX';
    }
    return null;
  }

  Future<void> _resetWhatsAppInstance(String enterpriseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser WhatsApp ?'),
        content: const Text(
          'Cela supprime la connexion WhatsApp en cours.\n'
          'L\'opération peut prendre jusqu\'à 1 minute.\n'
          'Vous pourrez ensuite vous reconnecter (QR ou code).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    _whatsappStatusTimer?.cancel();
    setState(() {
      _isConnectingWhatsapp = true;
      _whatsappQrCode = null;
      _whatsappPairingCode = null;
    });

    try {
      await WhatsAppService.deleteInstance(enterpriseId);
      if (!mounted) return;
      setState(() => _whatsappStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion réinitialisée. Vous pouvez vous reconnecter.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur suppression: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnectingWhatsapp = false);
    }
  }

  Future<void> _generatePairingCode(String enterpriseId) async {
    final phoneError = _validateWhatsAppPhone(_whatsappPhoneNumberController.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneError), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    setState(() {
      _isConnectingWhatsapp = true;
      _whatsappPairingCode = null;
    });

    try {
      final phone = _whatsappPhoneNumberController.text;
      final code = await WhatsAppService.requestPairingCode(enterpriseId, phone);

      setState(() {
        _whatsappPairingCode = code;
        _pairingPhoneUsed = phone;
        _whatsappStatus = 'pairing_ready';
      });

      _startStatusMonitoring(enterpriseId, fetchQr: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isConnectingWhatsapp = false;
      });
    }
  }

  Future<void> _resendPairingNotification(String enterpriseId) async {
    final phone = _pairingPhoneUsed ?? _whatsappPhoneNumberController.text;
    final phoneError = _validateWhatsAppPhone(phone);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneError), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    setState(() => _isConnectingWhatsapp = true);
    try {
      final newCode = await WhatsAppService.resendPairingNotification(enterpriseId, phone);
      if (mounted) {
        if (newCode != null) {
          setState(() {
            _whatsappPairingCode = newCode;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nouveau code généré. Vérifiez la notification sur votre téléphone.'),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification renvoyée. Vérifiez WhatsApp.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de renvoyer la notification. Ouvrez WhatsApp manuellement.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnectingWhatsapp = false);
    }
  }

  void _startStatusMonitoring(String enterpriseId, {bool fetchQr = false}) {
    _whatsappStatusTimer?.cancel();
    _whatsappPollAttempts = 0;
    _monitorFetchQr = fetchQr;

    _whatsappStatusTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      _whatsappPollAttempts++;

      // Pairing ou QR déjà affiché : vérifier UNIQUEMENT connectionState (pas /connect)
      if (_whatsappPairingCode != null || (_whatsappQrCode != null && !_monitorFetchQr)) {
        final info = await WhatsAppService.getInstanceStatus(enterpriseId);
        if (!mounted) return;

        if (info['status'] == 'connected') {
          timer.cancel();
          setState(() {
            _whatsappStatus = 'connected';
            _whatsappPairingCode = null;
            _whatsappQrCode = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("WhatsApp connecté ! ✔️"), backgroundColor: Colors.green),
          );
        }
        return;
      }

      // Phase initiale QR : tenter de récupérer le QR (puis passer en mode status-only)
      if (_monitorFetchQr) {
        final info = await WhatsAppService.getConnectionInfo(enterpriseId);
        if (!mounted) return;
        setState(() => _applyConnectionInfo(info));
        if (_whatsappQrCode != null) _monitorFetchQr = false;

        if (info['status'] == 'connected') {
          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("WhatsApp connecté ! ✔️"), backgroundColor: Colors.green),
          );
        } else if (_whatsappPollAttempts >= 8 && _whatsappQrCode == null) {
          timer.cancel();
          if (mounted) setState(() => _whatsappStatus = 'qr_unavailable');
        }
        return;
      }

      // Fallback : statut seul
      final info = await WhatsAppService.getInstanceStatus(enterpriseId);
      if (!mounted) return;
      if (info['status'] == 'connected') {
        timer.cancel();
        setState(() {
          _whatsappStatus = 'connected';
          _whatsappPairingCode = null;
          _whatsappQrCode = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("WhatsApp connecté ! ✔️"), backgroundColor: Colors.green),
        );
      }
    });
  }

  Future<void> _copyPairingCode() async {
    if (_whatsappPairingCode == null) return;
    await Clipboard.setData(ClipboardData(text: _whatsappPairingCode!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code copié ! Collez-le dans WhatsApp.'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _openWhatsAppApp() async {
    final candidates = [
      Uri.parse('whatsapp://send'),
      Uri.parse('https://wa.me/'),
    ];
    for (final uri in candidates) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ouvrez WhatsApp manuellement : Appareils connectés > Lier avec le numéro.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Initialiser la connexion WhatsApp avec Evolution API (QR Code)
  Future<void> _connectWhatsApp(String enterpriseId) async {
    setState(() {
      _isConnectingWhatsapp = true;
      _whatsappPairingCode = null;
      _whatsappQrCode = null;
      _whatsappStatus = 'connecting';
    });

    try {
      final result = await WhatsAppService.connectInstance(enterpriseId, forceRecreate: true);
      if (!mounted) return;
      setState(() => _applyConnectionInfo(result));
      _startStatusMonitoring(enterpriseId, fetchQr: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() {
        _isConnectingWhatsapp = false;
      });
    }
  }

  // Rafraîchir le statut WhatsApp
  Future<void> _refreshWhatsAppStatus(String enterpriseId) async {
    final info = await WhatsAppService.getConnectionInfo(enterpriseId);
    setState(() => _applyConnectionInfo(info));
  }

  // Déconnexion WhatsApp
  Future<void> _disconnectWhatsApp(String enterpriseId) async {
    _whatsappStatusTimer?.cancel();
    setState(() {
      _whatsappStatus = 'disconnected';
      _whatsappQrCode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final ent = db.currentEnterprise;

    if (ent != null && !_isLoaded) {
      _tempSettings = List<ProspectFieldSetting>.from(
        ent.formSettings.map((x) => x.copyWith()),
      );
      _apiKeyController.text = AppConfig.brevoApiKey;
      _senderEmailController.text = AppConfig.brevoSenderEmail;
      _countryCodeController.text = ent.defaultCountryCode;
      _africaTalkingApiKeyController.text = AppConfig.africaTalkingApiKey;
      _africaTalkingUsernameController.text = AppConfig.africaTalkingUsername;
      _isLoaded = true;
    }

    if (ent == null) {
      return const Center(child: Text("Erreur de chargement de l'entreprise."));
    }

    if (_activeSettingIndex == 5 && !_whatsappTabLoaded) {
      _whatsappTabLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadWhatsAppState(ent.id));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModernChip(
                  label: "Formulaire",
                  index: 0,
                  isSelected: _activeSettingIndex == 0,
                ),
                const SizedBox(width: 8),
                _buildModernChip(
                  label: "Configuration App",
                  index: 2,
                  isSelected: _activeSettingIndex == 2,
                ),
                const SizedBox(width: 8),
                _buildModernChip(
                  label: "Verdicts Appels",
                  index: 3,
                  isSelected: _activeSettingIndex == 3,
                ),
                const SizedBox(width: 8),
                _buildModernChip(
                  label: "Modèles Messages",
                  index: 4,
                  isSelected: _activeSettingIndex == 4,
                ),
                const SizedBox(width: 8),
                _buildModernChip(
                  label: "SMS Gateway",
                  index: 6,
                  isSelected: _activeSettingIndex == 6,
                ),
                const SizedBox(width: 8),
                _buildModernChip(
                  label: "WhatsApp",
                  index: 5,
                  isSelected: _activeSettingIndex == 5,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_activeSettingIndex == 0) ...[
            const Text(
              "Configuration du Formulaire de Prospection",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 8),
            const Text(
              "Déterminez les informations que vos agents doivent collecter sur le terrain.",
              style: TextStyle(color: AppTheme.textLight, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tempSettings.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final field = _tempSettings[index];
                  final isCoreField = field.id == 'nom' || field.id == 'telephone';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(field.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (!isCoreField)
                          Switch(
                            value: field.enabled,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (value) => setState(() {
                              _tempSettings[index] = field.copyWith(enabled: value, required: value ? field.required : false);
                            }),
                          )
                        else
                          const Text("Requis", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await db.updateFormSettings(_tempSettings);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Champs du formulaire enregistrés !"), backgroundColor: AppTheme.successColor));
              },
              icon: const Icon(Icons.save),
              label: const Text("Enregistrer les réglages"),
            ),
          ] else if (_activeSettingIndex == 2) ...[
            const Text(
              "Configuration de l'Application",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Indicatif pays par défaut", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Utilisé pour formater les numéros vers WhatsApp et SMS.", style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _countryCodeController,
                      decoration: const InputDecoration(hintText: "Ex: 229 pour le Bénin", prefixText: "+"),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await db.updateDefaultCountryCode(_countryCodeController.text);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Indicatif pays mis à jour !"), backgroundColor: AppTheme.successColor));
              },
              child: const Text("Sauvegarder l'indicatif"),
            ),
            const SizedBox(height: 24),
            const Text("Suivi Automatique", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor)),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                title: const Text("Auto-assignation des prospects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                  "Si activé, les prospects ajoutés par un agent lui seront automatiquement assignés pour le suivi.",
                  style: TextStyle(fontSize: 11),
                ),
                activeColor: AppTheme.primaryColor,
                value: ent.autoAssignToAgent,
                onChanged: (val) async {
                  await db.updateAutoAssignToAgent(val);
                },
              ),
            ),
          ] else if (_activeSettingIndex == 3) ...[
            const Text(
              "Personnalisation des Verdicts d'Appels",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 8),
            const Text(
              "Définissez les résultats possibles qu'un agent peut choisir après avoir contacté un prospect.",
              style: TextStyle(color: AppTheme.textLight, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 16),
            
            // Default Verdicts (Read only or toggle?)
            const Text("Verdicts par défaut de la plateforme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Enterprise.platformDefaultVerdicts.map((v) => Chip(
                label: Text(v, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.grey.shade100,
              )).toList(),
            ),
            const SizedBox(height: 24),

            // Custom Verdicts
            const Text("Vos Verdicts personnalisés", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _verdictController,
                    decoration: const InputDecoration(
                      hintText: "Ajouter un verdict (ex: Rappeler plus tard)",
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 32),
                  onPressed: () async {
                    if (_verdictController.text.trim().isNotEmpty) {
                      final newList = List<String>.from(ent.customVerdicts)
                        ..add(_verdictController.text.trim());
                      await db.updateCustomVerdicts(newList);
                      _verdictController.clear();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (ent.customVerdicts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text("Aucun verdict personnalisé.", style: TextStyle(color: AppTheme.textLight, fontSize: 12))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ent.customVerdicts.length,
                itemBuilder: (context, index) {
                  final v = ent.customVerdicts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(v, style: const TextStyle(fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                        onPressed: () async {
                          final newList = List<String>.from(ent.customVerdicts)..removeAt(index);
                          await db.updateCustomVerdicts(newList);
                        },
                      ),
                    ),
                  );
                },
              ),
          ] else if (_activeSettingIndex == 4) ...[
            const Text(
              "Modèles de messages pour les agents",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 8),
            const Text(
              "Prédéfinissez les messages que vos agents pourront utiliser pour contacter les prospects.",
              style: TextStyle(color: AppTheme.textLight, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _templateTitleController,
                      decoration: const InputDecoration(labelText: "Titre du modèle (ex: Relance J+1)"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _templateContentController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: "Contenu du message"),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_templateTitleController.text.isNotEmpty && _templateContentController.text.isNotEmpty) {
                          Provider.of<DatabaseService>(context, listen: false)
                              .addMessageTemplate(_templateTitleController.text, _templateContentController.text);
                          _templateTitleController.clear();
                          _templateContentController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Modèle ajouté !"), backgroundColor: AppTheme.successColor),
                          );
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Ajouter le modèle"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (ent.messageTemplates.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text("Aucun modèle de message.", style: TextStyle(color: AppTheme.textLight)),
              ))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ent.messageTemplates.length,
                itemBuilder: (context, index) {
                  final t = ent.messageTemplates[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(t.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                        onPressed: () => db.deleteMessageTemplate(t.id),
                      ),
                    ),
                  );
                },
              ),
          ] else if (_activeSettingIndex == 5) ...[
            const Text(
              "Connexion WhatsApp",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 8),
            const Text(
              "Connectez votre numéro WhatsApp pour envoyer des messages groupés.",
              style: TextStyle(color: AppTheme.textLight, fontSize: 12),
            ),
            const SizedBox(height: 20),
            
            // Mode Selection (QR vs Pairing)
            if (_whatsappStatus != 'connected')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_usePairingCode ? AppTheme.primaryColor.withOpacity(0.1) : null,
                        side: BorderSide(color: !_usePairingCode ? AppTheme.primaryColor : Colors.grey.shade300),
                      ),
                      onPressed: () => setState(() => _usePairingCode = false),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text("QR Code"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _usePairingCode ? AppTheme.primaryColor.withOpacity(0.1) : null,
                        side: BorderSide(color: _usePairingCode ? AppTheme.primaryColor : Colors.grey.shade300),
                      ),
                      onPressed: () => setState(() => _usePairingCode = true),
                      icon: const Icon(Icons.phone_android),
                      label: const Text("Code couplage"),
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 20),
            
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.chat, color: _whatsappStatus == 'connected' ? Colors.green.shade600 : Colors.grey.shade400, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Statut", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                _getWhatsAppStatusText(),
                                style: TextStyle(
                                  color: _whatsappStatus == 'connected' ? Colors.green : 
                                         (_whatsappStatus == 'qr_ready' || _whatsappStatus == 'pairing_ready') ? Colors.orange : Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    if (_whatsappStatus != 'connected') ...[
                      const Divider(height: 32),
                      if (!_usePairingCode) ...[
                        const Text("Méthode : Scanner le QR Code", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text("(Nécessite un deuxième appareil pour scanner)", style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                        const SizedBox(height: 16),
                        if (_whatsappQrCode != null) ...[
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Image.memory(
                                _decodeQrImage(_whatsappQrCode!),
                                width: 220,
                                height: 220,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "WhatsApp > Appareils connectés > Connecter un appareil",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                          ),
                        ] else if (_whatsappStatus == 'instance_exists') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: const Text(
                              "Une connexion précédente a été détectée.\n"
                              "Cliquez sur « Afficher le QR Code » pour continuer,\n"
                              "ou « Réinitialiser » pour repartir de zéro.",
                              style: TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isConnectingWhatsapp ? null : () => _connectWhatsApp(ent.id),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text("Afficher le QR Code"),
                          ),
                        ] else if (_whatsappStatus == 'qr_unavailable') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Text(
                              "Le QR code n'a pas pu être généré.\n"
                              "Réessayez ou utilisez le code de couplage.",
                              style: TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isConnectingWhatsapp ? null : () => _connectWhatsApp(ent.id),
                            icon: const Icon(Icons.refresh),
                            label: const Text("Réessayer"),
                          ),
                        ] else if (_isConnectingWhatsapp || _whatsappStatus == 'connecting') ...[
                          const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text("Génération du QR code...", style: TextStyle(fontSize: 13)),
                                SizedBox(height: 4),
                                Text(
                                  "Veuillez patienter quelques instants.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          ElevatedButton.icon(
                            onPressed: _isConnectingWhatsapp ? null : () => _connectWhatsApp(ent.id),
                            icon: _isConnectingWhatsapp ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.qr_code_scanner),
                            label: Text(_isConnectingWhatsapp ? "Génération..." : "Afficher le QR Code"),
                          ),
                      ] else ...[
                        const Text("Méthode : Code de couplage", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                          "Entrez votre numéro avec l'indicatif 229, sans + ni espaces.",
                          style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                        ),
                        const SizedBox(height: 16),
                        
                        if (_whatsappPairingCode == null) ...[
                          TextField(
                            controller: _whatsappPhoneNumberController,
                            decoration: const InputDecoration(
                              labelText: "Votre numéro WhatsApp",
                              hintText: "229 01 XXXXXXXX",
                              prefixIcon: Icon(Icons.phone),
                              helperText: "Obligatoire : commence par 229",
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _isConnectingWhatsapp ? null : () => _generatePairingCode(ent.id),
                            icon: _isConnectingWhatsapp ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.vpn_key),
                            label: Text(_isConnectingWhatsapp ? "Génération..." : "Générer le code"),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _whatsappPairingCode!,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                      color: AppTheme.primaryColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copier le code',
                                  icon: const Icon(Icons.copy, color: AppTheme.primaryColor),
                                  onPressed: _copyPairingCode,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Instructions :\n"
                            "1. Copiez le code ci-dessus\n"
                            "2. Ouvrez WhatsApp > Appareils connectés\n"
                            "3. Connecter un appareil > Lier avec le numéro\n"
                            "4. Saisissez le code\n\n"
                            "Si WhatsApp ne vous notifie pas, appuyez sur « Renvoyer la notification ».",
                            style: TextStyle(fontSize: 11, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                            onPressed: _copyPairingCode,
                            icon: const Icon(Icons.copy),
                            label: const Text("Copier le code"),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _isConnectingWhatsapp ? null : () => _resendPairingNotification(ent.id),
                            icon: const Icon(Icons.notifications_active_outlined),
                            label: const Text("Renvoyer la notification"),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _openWhatsAppApp,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text("Ouvrir WhatsApp"),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _whatsappPairingCode = null),
                            child: const Text("Changer de numéro"),
                          ),
                        ],
                      ],
                    ],
                    
                    // Connected State
                    if (_whatsappStatus == 'connected') ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                        icon: const Icon(Icons.logout),
                        onPressed: () => _disconnectWhatsApp(ent.id),
                        label: const Text("Déconnecter WhatsApp"),
                      ),
                    ],

                    if (_whatsappStatus != null && _whatsappStatus != 'connected') ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                        onPressed: _isConnectingWhatsapp ? null : () => _resetWhatsAppInstance(ent.id),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Réinitialiser la connexion'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Queue Status
            if (_queueStatus != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Statut de la file d'attente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _buildQueueStatusItem("En attente", _queueStatus!['pending'] ?? 0, Colors.orange),
                          _buildQueueStatusItem("Envoyés", _queueStatus!['sent'] ?? 0, Colors.green),
                          _buildQueueStatusItem("Échoués", _queueStatus!['failed'] ?? 0, Colors.red),
                          _buildQueueStatusItem("Numéros invalides", _queueStatus!['invalid_number'] ?? 0, Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else if (_activeSettingIndex == 6) ...[
            const Text(
              "Configuration SMS Gateway (Local)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 8),
            const Text(
              "Connectez votre téléphone Android pour envoyer des SMS gratuitement depuis G-CRM.",
              style: TextStyle(color: AppTheme.textLight, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 24),
            
            // Configuration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Gateway URL
                    const Text("URL du Gateway (Téléphone)", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("URL fournie par l'application Android SMS Gateway.", style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(),
                      decoration: const InputDecoration(
                        hintText: "http://192.168.x.x:8080",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // API Token
                    const Text("Token API (Téléphone)", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Token généré par l'application Android SMS Gateway.", style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(),
                      decoration: const InputDecoration(
                        hintText: "Votre token API",
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      icon: const Icon(Icons.save),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Pour commencer, lancez d'abord le microservice sms-service !"), backgroundColor: Colors.orange),
                        );
                      },
                      label: const Text("Sauvegarder la configuration"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getWhatsAppStatusText() {
    switch (_whatsappStatus) {
      case 'connected':
        return 'Connecté ✔️';
      case 'qr_ready':
        return 'QR Code prêt à scanner';
      case 'pairing_ready':
        return 'Code de couplage généré';
      case 'instance_exists':
        return 'Instance créée — en attente de connexion';
      case 'connecting':
        return 'Génération du QR code...';
      case 'qr_unavailable':
        return 'QR code indisponible';
      case 'error':
        return 'Erreur de connexion au service';
      case 'disconnected':
      default:
        return 'Non connecté';
    }
  }

  Widget _buildQueueStatusItem(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildModernChip({required String label, required int index, required bool isSelected}) {
    return InkWell(
      onTap: () => setState(() => _activeSettingIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ================= 4. TASK ASSIGNMENT TAB =================
class _TaskAssignmentTab extends StatefulWidget {
  const _TaskAssignmentTab();

  @override
  State<_TaskAssignmentTab> createState() => _TaskAssignmentTabState();
}

class _TaskAssignmentTabState extends State<_TaskAssignmentTab> {
  final Set<String> _selectedProspectIds = {};
  String? _selectedAgentId;
  final _countController = TextEditingController(text: '10');
  
  // Pagination for assignment
  int _currentPage = 0;
  final int _pageSize = 20;

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    
    // Get prospects with 'pending' status that are not already assigned to an agent via a pending task
    final allProspects = db.getProspectsForCurrentEnterprise();
    final pendingTasks = db.allTasks.where((t) => t.enterpriseId == db.currentEnterprise?.id && t.status == 'pending');
    final assignedProspectIds = pendingTasks.expand((t) => t.prospectIds).toSet();
    
    final List<Prospect> pendingProspects = allProspects
        .where((x) => x.status == 'pending' && !assignedProspectIds.contains(x.id))
        .toList();
    
    // Sort by date descending
    pendingProspects.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalPages = (pendingProspects.length / _pageSize).ceil();
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize) > pendingProspects.length ? pendingProspects.length : (startIndex + _pageSize);
    
    final pagedPendingProspects = pendingProspects.isEmpty ? <Prospect>[] : pendingProspects.sublist(startIndex, endIndex);

    final agents = db.getAgentsForCurrentEnterprise();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Attribuer des Relances",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.secondaryColor),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Sélectionnez et assignez les prospects libres aux agents.",
                      style: TextStyle(color: AppTheme.textLight, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Réinitialiser toutes les attributions",
                icon: const Icon(Icons.refresh, color: Colors.orange),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Réinitialiser les attributions ?"),
                      content: const Text("Toutes les tâches en cours seront supprimées. Les prospects assignés redeviendront libres."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text("Annuler"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                          child: const Text("Confirmer"),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await db.resetAllAssignments();
                    setState(() {
                      _selectedProspectIds.clear();
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Attributions réinitialisées !"),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Agent Picker & Assignment button row
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Choisir un agent",
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: _selectedAgentId,
                      items: agents.map((agent) {
                        return DropdownMenuItem<String>(
                          value: agent.id,
                          child: Text(agent.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedAgentId = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: (_selectedAgentId == null || _selectedProspectIds.isEmpty)
                        ? null
                        : () async {
                            await db.assignProspectsToAgent(
                              _selectedAgentId!,
                              _selectedProspectIds.toList(),
                            );
                            final agentName = agents.firstWhere((x) => x.id == _selectedAgentId).name;
                            final count = _selectedProspectIds.length;
                            
                            setState(() {
                              _selectedProspectIds.clear();
                              _selectedAgentId = null;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("$count prospect(s) assignés à $agentName !"),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Text("Attribuer"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Selection helper row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Prospects libres (${pendingProspects.length})",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                ),
              ),
              if (pendingProspects.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 45,
                      height: 30,
                      child: TextField(
                        controller: _countController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () {
                        final count = int.tryParse(_countController.text) ?? 10;
                        setState(() {
                          _selectedProspectIds.clear();
                          final toAdd = pendingProspects.take(count).map((x) => x.id);
                          _selectedProspectIds.addAll(toAdd);
                        });
                      },
                      child: const Text("Prendre", style: TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedProspectIds.length == pendingProspects.length) {
                            _selectedProspectIds.clear();
                          } else {
                            _selectedProspectIds.clear();
                            _selectedProspectIds.addAll(pendingProspects.map((x) => x.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedProspectIds.length == pendingProspects.length ? "Désél. tout" : "Tout",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          Expanded(
            child: pendingProspects.isEmpty
                ? const Center(
                    child: Text(
                      "Aucun prospect libre à attribuer.",
                      style: TextStyle(color: AppTheme.textLight),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: pagedPendingProspects.length,
                          itemBuilder: (context, index) {
                            final prospect = pagedPendingProspects[index];
                            final isSelected = _selectedProspectIds.contains(prospect.id);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: CheckboxListTile(
                                title: Text(
                                  prospect.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  "Tél: ${prospect.phone}${prospect.email.isNotEmpty ? ' | Email: ${prospect.email}' : ''}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                activeColor: AppTheme.primaryColor,
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedProspectIds.add(prospect.id);
                                    } else {
                                      _selectedProspectIds.remove(prospect.id);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                              ),
                              Text("Page ${_currentPage + 1} sur $totalPages"),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
