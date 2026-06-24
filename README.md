# g_crm

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Configuration Production

Ne jamais mettre de secrets dans le code. Utiliser les variables d'environnement.

- Copier `.env.example` vers `.env` (local uniquement)
- Pour Flutter, injecter les variables avec `--dart-define`
- Pour les services Node, utiliser les fichiers `.env` dans `sms-service/` et `whatsapp-service/`
- Pour Cloud Functions, configurer les secrets via env ou `firebase functions:config:set`

Exemple build Flutter:

`flutter build apk --release --dart-define=EVOLUTION_API_KEY=... --dart-define=INTERNAL_API_KEY=...`
