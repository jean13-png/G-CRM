import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/prospect.dart';
import '../../models/agent.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';

class ProspectDetailScreen extends StatefulWidget {
  final String prospectId;

  const ProspectDetailScreen({super.key, required this.prospectId});

  @override
  State<ProspectDetailScreen> createState() => _ProspectDetailScreenState();
}

class _ProspectDetailScreenState extends State<ProspectDetailScreen> {
  final _observationController = TextEditingController();
  final _decisionController = TextEditingController();
  final _suiviResumeController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _observationController.dispose();
    _decisionController.dispose();
    _suiviResumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final prospect = db.allProspects.firstWhere((p) => p.id == widget.prospectId);
    final agent = db.allAgents.firstWhere((a) => a.id == prospect.agentId, orElse: () => Agent(id: '', enterpriseId: '', name: 'Inconnu', email: '', createdAt: DateTime.now()));
    
    _observationController.text = prospect.observation;
    _decisionController.text = prospect.decision;

    return Scaffold(
      appBar: AppBar(
        title: Text(prospect.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryColor),
            onPressed: () => PdfService.exportFicheCRM([prospect]),
            tooltip: 'Exporter la fiche CRM',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => PdfService.exportFicheCRM([prospect]),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.download, color: Colors.white),
        label: const Text("Exporter la fiche", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info
            Card(
              color: AppTheme.secondaryColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoTile(Icons.person, "Nom Complet", prospect.name, Colors.white),
                    _buildInfoTile(Icons.phone, "Téléphone", prospect.phone, Colors.white),
                    _buildInfoTile(Icons.calendar_today, "Créé le", DateFormat('dd/MM/yyyy HH:mm').format(prospect.createdAt), Colors.white),
                    if (db.currentUserRole == 'enterprise')
                      _buildInfoTile(Icons.badge, "Agent Responsable", agent.name, Colors.orangeAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "GRILLE DE SUIVI (8 ÉTAPES)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 12),
            
            // Suivi Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                final suivi = prospect.suivis[index];
                final isDone = suivi.date != null;
                
                return InkWell(
                  onTap: () => _showSuiviEditDialog(context, index, suivi),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDone ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                      border: Border.all(color: isDone ? AppTheme.primaryColor : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "SUIVI ${index + 1}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 10,
                            color: isDone ? AppTheme.primaryColor : AppTheme.textLight
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isDone) ...[
                          Text(
                            DateFormat('dd/MM/yy').format(suivi.date!),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            suivi.resume,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ] else
                          const Text(".../.../...", style: TextStyle(color: AppTheme.textLight, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Observation & Decision
            const Text("OBSERVATIONS & DÉCISION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _observationController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Observations générales",
                hintText: "Saisir les détails importants...",
              ),
              onChanged: (val) => _debouncedUpdate(db),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _decisionController,
              decoration: const InputDecoration(
                labelText: "Décision finale",
                hintText: "Ex: En attente, Signé, Abandonné...",
              ),
              onChanged: (val) => _debouncedUpdate(db),
            ),
            const SizedBox(height: 100), // Spacing for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
          Expanded(child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }

  void _showSuiviEditDialog(BuildContext context, int index, Suivi suivi) {
    _suiviResumeController.text = suivi.resume;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Mettre à jour SUIVI ${index + 1}"),
        content: TextField(
          controller: _suiviResumeController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Résumé de l'échange",
            hintText: "Ex: Client intéressé par le pack A",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              final db = Provider.of<DatabaseService>(context, listen: false);
              await db.updateProspectSuivi(
                prospectId: widget.prospectId,
                index: index,
                resume: _suiviResumeController.text,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  // Debounced update for observation/decision
  void _debouncedUpdate(DatabaseService db) {
    // In a real app, use a timer to avoid too many writes
    db.updateProspectSuivi(
      prospectId: widget.prospectId,
      index: -1, // No suivi index update
      resume: '',
      observation: _observationController.text,
      decision: _decisionController.text,
    );
  }
}
