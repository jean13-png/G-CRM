# G-CRM : WhatsApp Automation Microservice

## Prérequis
- Node.js (v18+) installé sur votre ordinateur
- Firebase Admin SDK configuré (fichier serviceAccountKey.json dans ce dossier)
- Pour le développement, vous pouvez activer les émulateurs Firebase si nécessaire

## Installation et Configuration (pour le développement local)

1. Naviguer vers le dossier `whatsapp-service`:
   ```bash
   cd whatsapp-service
   ```

2. Installer les dépendances:
   ```bash
   npm install
   ```

3. Configurer Firebase Admin SDK (IMPORTANT):
   - Téléchargez votre fichier `serviceAccountKey.json` depuis la console Firebase (Paramètres du projet → Comptes de service → Générer une nouvelle clé privée)
   - Placez-le dans ce dossier (`whatsapp-service/`)
   - Ou, pour la production, définissez la variable d'environnement `GOOGLE_APPLICATION_CREDENTIALS` avec le chemin vers ce fichier

4. Copiez le fichier d'exemple de configuration:
   ```bash
   cp .env.example .env
   ```
   (Le fichier `.env` est prêt à l'emploi pour le développement local !)

## Démarrer le service

```bash
npm start
```
Le service est maintenant disponible sur http://localhost:3000 !

## Intégration avec Flutter (pour le développement sur émulateur Android)
Pour que Flutter accède au microservice sur l'émulateur Android:
1. Dans le fichier `lib/app_config.dart`, remplacez `localhost` par `10.0.2.2`:
   ```dart
   static const String whatsappServiceUrl = 'http://10.0.2.2:3000';
   ```
   (10.0.2.2 est l'IP spéciale de l'émulateur pour accéder à votre machine hôte)

## Utilisation

### Connecter votre compte WhatsApp
1. Dans l'application Flutter, ouvrez le tableau de bord de l'entreprise
2. Allez dans "Paramètres" → "WhatsApp"
3. Cliquez sur "Connecter WhatsApp"
4. Scannez le QR Code avec votre application WhatsApp (WhatsApp → ⋮ → Appareils connectés)
5. Une fois connecté, vous verrez "Connecté ✔️"

### Envoyer des messages groupés
1. Allez dans "Communication" → "WhatsApp Groupé" (Note: pour l'instant, utilisez le bouton existant; la UI complète arrive bientôt!)
2. Sélectionnez vos prospects
3. Rédigez votre message
4. Cliquez sur "Envoyer"
5. Le service traitera les messages automatiquement (avec un délai anti-ban de 10-30 secondes entre chaque message)

## Fonctionnalités
- ✅ Gestion multi-comptes WhatsApp (par entreprise)
- ✅ QR Code pour la connexion
- ✅ File d'attente Firestore native
- ✅ Vérification automatique des numéros WhatsApp
- ✅ Délai anti-ban aléatoire (10-30s entre messages)
- ✅ Suivi du statut des messages en temps réel
