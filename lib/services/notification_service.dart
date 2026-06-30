import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'g_crm_channel', // id
    'G-CRM Notifications', // name
    description: 'Notifications for G-CRM app', // description
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  Future<void> initialize() async {
    // Request notification permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
    );

    // Create channel for Android
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> showNotification(AppNotification notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'g_crm_channel',
      'G-CRM Notifications',
      channelDescription: 'Notifications for G-CRM app',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public, // Show on lock screen
      showWhen: true,
      autoCancel: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
    );
  }

  Future<void> showUpdateNotification(String version) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'g_crm_channel',
      'G-CRM Notifications',
      channelDescription: 'Notifications for G-CRM app',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      showWhen: true,
      autoCancel: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0, // ID for update notifications
      'Mise à jour disponible',
      'Une nouvelle version $version est disponible pour G-CRM',
      platformChannelSpecifics,
    );
  }
}
