import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/app_notification.dart';
import '../../theme.dart';
import '../chat/chat_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DatabaseService>(context, listen: false).markAllNotificationsAsRead();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final notifications = db.getMyNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => db.markAllNotificationsAsRead(),
              child: const Text("Tout lire", style: TextStyle(color: AppTheme.primaryColor)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    "Aucune notification pour le moment.",
                    style: TextStyle(color: AppTheme.textLight),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _buildNotificationTile(context, n);
              },
            ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, AppNotification n) {
    final timeStr = DateFormat('dd/MM HH:mm').format(n.timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: n.isRead ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: n.isRead ? Colors.grey.shade200 : AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getIconColor(n.type).withOpacity(0.1),
          child: Icon(_getIcon(n.type), color: _getIconColor(n.type), size: 20),
        ),
        title: Text(
          n.title,
          style: TextStyle(
            fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(n.body, style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
            const SizedBox(height: 4),
            Text(timeStr, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
          ],
        ),
        onTap: () => _handleNotificationTap(context, n),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'message': return Icons.chat;
      case 'task': return Icons.assignment;
      default: return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'message': return AppTheme.primaryColor;
      case 'task': return Colors.orange;
      default: return AppTheme.secondaryColor;
    }
  }

  void _handleNotificationTap(BuildContext context, AppNotification n) {
    if (n.type == 'message' && n.relatedId != null) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            agentId: n.relatedId!,
            agentName: db.currentUserRole == 'enterprise' ? n.title.replaceFirst("Message de ", "") : "Entreprise",
          ),
        ),
      );
    }
    // For tasks, we could navigate to task screen, etc.
  }
}
