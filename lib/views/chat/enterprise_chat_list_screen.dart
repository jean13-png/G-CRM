import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import 'chat_screen.dart';

class EnterpriseChatListScreen extends StatelessWidget {
  const EnterpriseChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final agents = db.getAgentsForCurrentEnterprise();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messagerie Agents"),
      ),
      body: agents.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "Aucun agent enregistré pour le moment. Ajoutez des agents à votre équipe pour pouvoir discuter avec eux.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                final unreadCount = db.getUnreadMessagesCount(forAgentId: agent.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: const Icon(Icons.person, color: AppTheme.primaryColor),
                    ),
                    title: Text(
                      agent.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(agent.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: AppTheme.textLight),
                      ],
                    ),
                    onTap: () {
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
                  ),
                );
              },
            ),
    );
  }
}
