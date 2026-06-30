import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/database_service.dart';
import '../../models/prospect.dart';
import '../../theme.dart';
import '../auth/role_selection_screen.dart';
import 'prospect_form_screen.dart';
import 'task_call_screen.dart';
import '../chat/chat_screen.dart';
import '../notifications/notification_screen.dart';
import 'prospect_detail_screen.dart';

class AgentDashboard extends StatefulWidget {
  const AgentDashboard({super.key});

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final agentName = db.currentAgent?.name ?? 'Agent';
    
    // Calculate statistics
    final allProspects = db.allProspects;
    final agentProspects = allProspects.where((x) => x.agentId == db.currentAgent?.id).toList();
    
    // Filtered prospects for search
    final filteredProspects = agentProspects.where((p) {
      final query = _searchQuery.toLowerCase();
      final nom = (p.data['nom'] ?? '').toLowerCase();
      final prenom = (p.data['prenom'] ?? '').toLowerCase();
      final tel = (p.data['telephone'] ?? '').toLowerCase();
      return nom.contains(query) || prenom.contains(query) || tel.contains(query);
    }).toList();

    final tasks = db.getTasksForCurrentAgent();
    final assignedProspects = db.getAssignedProspectsForCurrentAgent();
    final unreachableProspects = db.getUnreachableProspectsForCurrentAgent();

    final totalCollected = agentProspects.length;
    final pendingCalls = assignedProspects.where((x) => x.status == 'pending').length;
    final okCalls = assignedProspects.where((x) => x.status == 'Succès').length;
    final nonCalls = assignedProspects.where((x) => x.status == 'Refus').length;

    final unreadMessages = db.getUnreadMessagesCount();
    final unreadNotifs = db.getUnreadNotificationsCount();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Espace Agent"),
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
              if (unreadNotifs > 0)
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
                      unreadNotifs.toString(),
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
                tooltip: 'Chat avec l\'entreprise',
                icon: const Icon(Icons.chat_outlined, color: AppTheme.primaryColor),
                onPressed: () {
                  if (db.currentAgent != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          agentId: db.currentAgent!.id,
                          agentName: db.currentEnterprise?.name ?? "Entreprise",
                        ),
                      ),
                    );
                  }
                },
              ),
              if (unreadMessages > 0)
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
                      unreadMessages.toString(),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcoming card
            Card(
              color: AppTheme.secondaryColor,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bonjour, $agentName !",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Entreprise : ${db.currentEnterprise?.name ?? 'Inconnue'}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SEARCH BAR
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Rechercher un prospect (nom, tel...)",
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // 1. SEARCH RESULTS (Only show if searching)
            if (_searchQuery.isNotEmpty) ...[
              const Text(
                "Résultats de recherche",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
              ),
              const SizedBox(height: 12),
              if (filteredProspects.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text("Aucun prospect trouvé.")),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredProspects.length,
                  itemBuilder: (context, index) {
                    final p = filteredProspects[index];
                    return _buildProspectTile(p);
                  },
                ),
              const SizedBox(height: 20),
            ],

            // 1. DYNAMIC REMINDER BANNER FOR UNREACHABLE PROSPECTS
            if (unreachableProspects.isNotEmpty)
              Card(
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.warningColor, width: 1.5),
                ),
                child: InkWell(
                  onTap: () {
                    // Start calling process specifically with unreachable prospects
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskCallScreen(
                          prospectsToCall: unreachableProspects,
                          title: "Relance Injoignables",
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_callback,
                          color: AppTheme.warningColor,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Relances à faire (${unreachableProspects.length})",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.warningColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Certains numéros étaient inaccessibles. Cliquez pour retenter l'appel.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textDark,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward,
                          color: AppTheme.warningColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // 2. MAIN ACTIONS SECTION
            const Text(
              "Actions de terrain",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 12),
            
            // Prospection Card
            _buildActionCard(
              context,
              title: "Mode Prospection Terrain",
              subtitle: "Collectez de nouveaux prospects hors-ligne. Formulaire optimisé avec Mode Auto.",
              icon: Icons.person_add_alt_1,
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProspectFormScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // Calling Tasks Card
            _buildActionCard(
              context,
              title: "Suivi & Appels Téléphoniques",
              subtitle: pendingCalls > 0 
                  ? "Vous avez $pendingCalls appel(s) en attente d'attribution." 
                  : "Pas d'appel en attente actuellement.",
              icon: Icons.phone_in_talk,
              color: AppTheme.secondaryColor,
              onTap: pendingCalls > 0 
                  ? () {
                      final prospectsToCall = assignedProspects.where((x) => x.status == 'pending').toList();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskCallScreen(
                            prospectsToCall: prospectsToCall,
                            title: "Suivi Téléphonique",
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 12),

            // Task History Card
            _buildActionCard(
              context,
              title: "Historique de mes tâches",
              subtitle: "Consultez et relancez vos prospects gérés.",
              icon: Icons.history_edu,
              color: Colors.blueGrey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const _AgentTaskHistoryScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // 3. STATS SECTION
            const Text(
              "Mon Activité",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    "Prospects créés",
                    totalCollected.toString(),
                    Icons.add_to_photos_outlined,
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    "Appels en attente",
                    pendingCalls.toString(),
                    Icons.pending_actions,
                    AppTheme.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    "Appels conclus (OK)",
                    okCalls.toString(),
                    Icons.check_circle_outline,
                    AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    "Refus (Non)",
                    nonCalls.toString(),
                    Icons.cancel_outlined,
                    AppTheme.errorColor,
                  ),
                ),
              ],
            ),
            
            // 4. GENERATE REPORT / CLOSE DAY
            if (totalCollected > 0)
              const SizedBox(height: 24),
            if (totalCollected > 0)
              Card(
                color: Colors.green.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.green.shade200, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_turned_in, color: AppTheme.successColor, size: 24),
                        SizedBox(width: 8),
                        Text(
                          "Clôture & Rapport de prospection",
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.successColor, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Générez et partagez le rapport complet de vos prospects enregistrés au format CSV exploitable.",
                      style: TextStyle(fontSize: 12, color: AppTheme.textDark, height: 1.3),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: totalCollected == 0 ? null : () async {
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                          ),
                        );

                        // Try to send report directly via Brevo
                        final sentDirectly = await db.sendReportToEnterprise(agentProspects);

                        if (context.mounted) {
                          Navigator.pop(context); // Close loading indicator
                        }

                        if (sentDirectly) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Rapport envoyé directement à l'entreprise (${db.currentEnterprise?.email ?? ''}) !"),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } else {
                          // Fallback: system share
                          final csvString = db.generateProspectsCSV(agentProspects);
                          final tempFile = await db.saveCSVToFile(csvString);
                          
                          if (context.mounted) {
                            final enterpriseEmail = db.currentEnterprise?.email ?? '';
                            await Share.shareXFiles(
                              [XFile(tempFile.path)],
                              text: "Rapport de fin de prospection - G-CRM.\nAgent : ${db.currentAgent?.name}.\nDestinataire : $enterpriseEmail",
                              subject: "Clôture de prospection - ${db.currentAgent?.name}",
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text("Clôturer & Exporter le Rapport"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProspectTile(Prospect p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProspectDetailScreen(prospectId: p.id),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Text(
            (p.data['nom']?[0] ?? '?').toUpperCase(),
            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          "${p.data['prenom'] ?? ''} ${p.data['nom'] ?? 'Prospect'}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          p.data['telephone'] ?? 'Pas de numéro',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: _buildStatusBadge(p.status),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'Succès':
        color = AppTheme.successColor;
        label = "SUCCÈS";
        break;
      case 'Refus':
        color = AppTheme.errorColor;
        label = "REFUS";
        break;
      case 'unreachable':
        color = AppTheme.warningColor;
        label = "RELANCE";
        break;
      default:
        color = AppTheme.textLight;
        label = "EN ATTENTE";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppTheme.textLight.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= AGENT TASK HISTORY SCREEN =================
class _AgentTaskHistoryScreen extends StatefulWidget {
  const _AgentTaskHistoryScreen();

  @override
  State<_AgentTaskHistoryScreen> createState() => _AgentTaskHistoryScreenState();
}

class _AgentTaskHistoryScreenState extends State<_AgentTaskHistoryScreen> {
  String _selectedStatus = 'all'; // all, ok, non, unreachable, pending

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final tasks = db.getAllTasksForCurrentAgent();
    
    // Get all unique prospects across all tasks
    final allAssignedIds = tasks.expand((t) => t.prospectIds).toSet();
    final allAssignedProspects = db.allProspects.where((p) => allAssignedIds.contains(p.id)).toList();

    // Filter by status
    final filteredProspects = _selectedStatus == 'all' 
        ? allAssignedProspects 
        : allAssignedProspects.where((p) => p.status == _selectedStatus).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon Historique"),
      ),
      body: Column(
        children: [
          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tout'),
                _buildFilterChip('ok', 'OK'),
                _buildFilterChip('non', 'NON'),
                _buildFilterChip('unreachable', 'Injoignables'),
                _buildFilterChip('pending', 'En attente'),
              ],
            ),
          ),

          Expanded(
            child: filteredProspects.isEmpty
                ? const Center(child: Text("Aucun prospect dans cette catégorie."))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredProspects.length,
                    itemBuilder: (context, index) {
                      final p = filteredProspects[index];
                      return _buildHistoryCard(context, p);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        onSelected: (val) {
          if (val) setState(() => _selectedStatus = status);
        },
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Prospect p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(p.status).withOpacity(0.1),
          child: Icon(_getStatusIcon(p.status), color: _getStatusColor(p.status), size: 20),
        ),
        title: Text(
          "${p.data['prenom'] ?? ''} ${p.data['nom'] ?? 'Prospect'}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Statut: ${_translateStatus(p.status)}",
          style: TextStyle(fontSize: 12, color: _getStatusColor(p.status)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Tél: ${p.data['telephone'] ?? 'N/A'}", style: const TextStyle(fontSize: 13)),
                if (p.data['entreprise'] != null)
                  Text("Entreprise: ${p.data['entreprise']}", style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskCallScreen(
                          prospectsToCall: [p],
                          title: "Relance Prospect",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone_in_talk, size: 18),
                  label: const Text("Relancer cet appel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Succès': return AppTheme.successColor;
      case 'Refus': return AppTheme.errorColor;
      case 'unreachable': return AppTheme.warningColor;
      default: return AppTheme.textLight;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Succès': return Icons.check_circle;
      case 'Refus': return Icons.cancel;
      case 'unreachable': return Icons.phone_missed;
      default: return Icons.pending;
    }
  }
}
