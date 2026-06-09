import 'package:flutter/material.dart';
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
      const _TemplatesTab(),
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
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout, color: AppTheme.errorColor),
            onPressed: () {
              db.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                (route) => false,
              );
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
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: 'Modèles',
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

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final List<Prospect> prospects = db.getProspectsForCurrentEnterprise();
    final agents = db.getAgentsForCurrentEnterprise();

    final total = prospects.length;
    final ok = prospects.where((x) => x.status == 'ok').length;
    final non = prospects.where((x) => x.status == 'non').length;
    final unreachable = prospects.where((x) => x.status == 'unreachable').length;

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
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.person),
                    ),
                    title: Text(agent.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(agent.email),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textLight),
                  ),
                );
              },
            ),
        ],
      ),
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

// ================= 4. MODÈLES DE MESSAGES TAB =================
class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab();

  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nouveau modèle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Titre (ex: Relance J+1)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "Contenu du message"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty && _contentController.text.isNotEmpty) {
                Provider.of<DatabaseService>(context, listen: false)
                    .addMessageTemplate(_titleController.text, _contentController.text);
                _titleController.clear();
                _contentController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final templates = db.currentEnterprise?.messageTemplates ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Modèles de messages pour les agents",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            ),
          ),
          Expanded(
            child: templates.isEmpty
                ? const Center(child: Text("Aucun modèle de message."))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final t = templates[index];
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
          ),
        ],
      ),
    );
  }
}

// ================= 5. PARAMÈTRES / CONFIGURATION TAB =================
class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  int _activeSettingIndex = 0; // 0: Form, 1: Email, 2: App Config
  List<ProspectFieldSetting> _tempSettings = [];
  bool _isLoaded = false;

  final _apiKeyController = TextEditingController();
  final _senderEmailController = TextEditingController();
  final _countryCodeController = TextEditingController();
  final _brevoFormKey = GlobalKey<FormState>();
  bool _testingEmail = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _senderEmailController.dispose();
    _countryCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final ent = db.currentEnterprise;

    if (ent != null && !_isLoaded) {
      _tempSettings = List<ProspectFieldSetting>.from(
        ent.formSettings.map((x) => x.copyWith()),
      );
      _apiKeyController.text = ent.brevoApiKey;
      _senderEmailController.text = ent.brevoSenderEmail;
      _countryCodeController.text = ent.defaultCountryCode;
      _isLoaded = true;
    }

    if (ent == null) {
      return const Center(child: Text("Erreur de chargement de l'entreprise."));
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
                ChoiceChip(
                  label: const Text("Formulaire", style: TextStyle(fontSize: 12)),
                  selected: _activeSettingIndex == 0,
                  onSelected: (val) => val ? setState(() => _activeSettingIndex = 0) : null,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("Configuration Email", style: TextStyle(fontSize: 12)),
                  selected: _activeSettingIndex == 1,
                  onSelected: (val) => val ? setState(() => _activeSettingIndex = 1) : null,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("Configuration App", style: TextStyle(fontSize: 12)),
                  selected: _activeSettingIndex == 2,
                  onSelected: (val) => val ? setState(() => _activeSettingIndex = 2) : null,
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
          ] else if (_activeSettingIndex == 1) ...[
            const Text(
              "Service d'Envoi d'Email (Brevo API)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _brevoFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(labelText: "Clé API Brevo v3"),
                        validator: (v) => v == null || v.trim().isEmpty ? "Clé API requise" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _senderEmailController,
                        decoration: const InputDecoration(labelText: "Email expéditeur"),
                        validator: (v) => v == null || v.trim().isEmpty ? "Email requis" : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (!_brevoFormKey.currentState!.validate()) return;
                          await db.updateEnterpriseBrevoSettings(_apiKeyController.text, _senderEmailController.text);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuration Brevo enregistrée !"), backgroundColor: AppTheme.successColor));
                        },
                        icon: const Icon(Icons.save),
                        label: const Text("Enregistrer"),
                      ),
                    ],
                  ),
                ),
              ),
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
          ],
        ],
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
