import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/database_service.dart';
import 'models/chat_message.dart';
import 'models/app_notification.dart';
import 'views/chat/chat_screen.dart';
import 'views/notifications/notification_screen.dart';
import 'theme.dart';
import 'views/auth/role_selection_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Create and initialize the database service
  final databaseService = DatabaseService();
  await databaseService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: databaseService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _notifSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  void _setupNotifications() {
    final db = DatabaseService();
    _notifSubscription = db.onNewNotification.listen((notification) {
      // Get the current user context
      final currentUserId = db.currentUserRole == 'enterprise' 
          ? db.currentEnterprise?.id 
          : db.currentAgent?.id;

      // Only notify if the notification is for me
      if (notification.targetUserId == currentUserId) {
        _showInAppNotification(notification);
      }
    });
  }

  void _showInAppNotification(AppNotification notification) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppTheme.secondaryColor,
          content: Row(
            children: [
              Icon(
                notification.type == 'message' ? Icons.chat : Icons.notifications_active,
                color: AppTheme.primaryColor, 
                size: 20
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      notification.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: "VOIR",
            textColor: AppTheme.primaryColor,
            onPressed: () {
              if (notification.type == 'message' && notification.relatedId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      agentId: notification.relatedId!,
                      agentName: DatabaseService().currentUserRole == 'enterprise' 
                          ? notification.title.replaceFirst("Message de ", "") 
                          : (DatabaseService().currentEnterprise?.name ?? "Entreprise"),
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationScreen()),
                );
              }
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'G-CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      darkTheme: AppTheme.darkThemeData,
      themeMode: ThemeMode.system,
      home: const MainGate(),
    );
  }
}

class MainGate extends StatelessWidget {
  const MainGate({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    // If the database service is still initializing, show a simple splash loading screen
    if (!db.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insights, size: 64, color: AppTheme.primaryColor),
              SizedBox(height: 24),
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text(
                "Chargement de G-CRM...",
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default entrypoint is the Role Selection Screen
    return const RoleSelectionScreen();
  }
}
