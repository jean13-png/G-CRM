# G-CRM : Microservice SMS Local Gratuit

## 🎯 Fonctionnement
Ce service utilise **votre propre téléphone Android** pour envoyer des SMS, totalement gratuitement. Il est basé sur la même logique que le WhatsApp : un système de file d'attente anti-ban pour éviter les blocages.

## 🚀 Installation & Démarrage

### 1. Installer l'app Android SMS Gateway sur votre téléphone
Téléchargez et installez l'application **[Android SMS Gateway](https://github.com/capcom6/android-sms-gateway/releases)** sur votre téléphone Android.

### 2. Configurer l'app Android
Ouvrez l'app sur votre téléphone, cliquez sur "Settings" et notez :
- Votre **token API** (généré automatiquement par l'app)
- L'adresse IP de votre téléphone sur le réseau local (ex: `192.168.1.10`)

### 3. Lancer ce microservice sur votre ordinateur
```bash
cd /home/john/Bureau/G-CRM/sms-service
npm install
npm start
```
Le service écoute sur `http://localhost:3001` par défaut.

### 4. Mettre à jour la configuration de G-CRM
Dans `lib/app_config.dart`, assurez-vous d'avoir :
```dart
static const String smsServiceUrl = 'http://10.0.2.2:3001'; // Pour émulateur
// OU static const String smsServiceUrl = 'http://VOTRE_IP_ORDINATEUR:3001'; // Pour téléphone réel sur le même réseau WiFi
```

## 📋 Points Clés
- **Fichiers d'attente** : Stockés dans Firestore, comme pour WhatsApp.
- **Anti-Ban** : Délai aléatoire de **10-30 secondes** entre chaque SMS.
- **Suivi** : Statut des messages envoyés en temps réel dans l'app G-CRM.
