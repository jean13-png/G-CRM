# Guide Ultime : Intégration de FedaPay dans une Application Mobile (Architecture Client-Serveur)

Ce guide est un retour d'expérience complet et de bout en bout basé sur l'intégration de FedaPay dans l'application mobile Flutter G-CRM avec un backend Node.js. Il détaille les étapes, les meilleures pratiques, et surtout **les pièges et erreurs à éviter** lors de la mise en production.

---

## 🏗️ 1. Architecture du Système

Ne **JAMAIS** intégrer la clé secrète FedaPay (`sk_live_...`) directement dans le code source de l'application mobile (Flutter/React Native). L'architecture correcte se fait en trois parties :

1. **L'Application Mobile (Flutter)** : Interface utilisateur, envoie une requête de paiement au serveur.
2. **Le Serveur Backend (Node.js/Express)** : Sécurise la clé secrète, dialogue avec l'API FedaPay, génère le lien de paiement et met à jour la base de données.
3. **FedaPay API** : Traite le paiement et envoie une confirmation asynchrone (Webhook) au serveur.

---

## ⚙️ 2. Côté Serveur (Node.js) : Création de la Transaction

### ❌ L'erreur classique : Utiliser des requêtes HTTP (Axios) manuellement
Au début, nous avons tenté d'utiliser des requêtes manuelles vers l'API FedaPay. Cela a généré de nombreuses erreurs de format JSON, car la structure de réponse de l'API REST de FedaPay peut varier (présence de wrappers `v1` ou non).

### ✅ La solution : Utiliser le SDK Officiel FedaPay
Installez le SDK : `npm install fedapay`

**⚠️ Piège d'importation Node.js :**
Si vous faites `const FedaPay = require("fedapay")`, la fonction `FedaPay.setApiKey()` renverra l'erreur `TypeError: FedaPay.setApiKey is not a function`.

**La bonne syntaxe :**
```javascript
const { FedaPay, Transaction } = require("fedapay");

// Initialisation
FedaPay.setApiKey(process.env.FEDAPAY_SECRET_KEY);
FedaPay.setEnvironment("live"); // "sandbox" pour les tests
```

### Générer le lien de paiement (Checkout URL)
```javascript
const transaction = await Transaction.create({
  description: "Abonnement Service X",
  amount: 2500,
  currency: { iso: "XOF" },
  callback_url: "https://votre-serveur.com/payment-status", // Page de retour après paiement
  custom_metadata: { userId: "12345", planId: "STARTER" }, // IMPORTANT pour le Webhook
  customer: {
    firstname: "John",
    lastname: "Doe",
    email: "john@example.com"
  }
});

// Génération du token
const token = await transaction.generateToken();
const checkoutUrl = token.url || (token.token ? \`https://checkout.fedapay.com/\${token.token}\` : null);

// Renvoyer l'URL à l'application mobile
res.json({ checkoutUrl, transactionId: transaction.id });
```

---

## 📱 3. Côté Mobile (Flutter) : Ouverture du Checkout

Une fois l'URL récupérée depuis votre serveur, l'application mobile doit ouvrir un navigateur externe pour que l'utilisateur procède au paiement.

```dart
import 'package:url_launcher/url_launcher.dart';

// ... appel à votre backend pour obtenir checkoutUrl ...

final uri = Uri.parse(checkoutUrl);
if (await canLaunchUrl(uri)) {
  // launchUrl externe garantit que Mobile Money (USSD) fonctionne correctement
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
```

---

## 🔄 4. Gérer le Retour Utilisateur (Callback URL)

Lorsque l'utilisateur termine ou annule son paiement, FedaPay le redirige vers le `callback_url` défini lors de la création de la transaction, en ajoutant les paramètres `?id=XXX&status=approved` (ou `canceled`, `declined`).

### ❌ Ce qu'il ne faut pas faire :
Ne définissez pas l'URL de votre Webhook (ex: `/webhook`) comme `callback_url`. Un Webhook attend une méthode `POST` avec un JSON. Si l'utilisateur est redirigé via son navigateur (`GET`), il verra une page d'erreur.

### ✅ La bonne pratique :
Créer une route `GET /payment-status` sur le serveur Node.js qui retourne une **belle page HTML**. Cette page informera l'utilisateur du succès ou de l'échec et contiendra un bouton (avec un Deep Link comme `monapp://`) pour le ramener dans l'application mobile.

---

## 🔔 5. Le Webhook : Validation Automatique Asynchrone

L'utilisateur peut fermer le navigateur avant la redirection finale. **La seule source de vérité pour valider un paiement est le Webhook FedaPay.**

Allez sur le dashboard FedaPay, configurez un Webhook vers `https://votre-serveur.com/webhook` et cochez l'événement `transaction.approved` (et `transaction.created` si besoin).

**⚠️ Piège de la structure JSON du Webhook :**
FedaPay encapsule la transaction dans l'objet `entity`.

```javascript
app.post("/webhook", async (req, res) => {
  const event = req.body;
  const entity = event?.entity; // C'est ici que se trouve la transaction !

  if (!entity || entity.status !== "approved") {
    return res.status(200).send("OK");
  }

  // custom_metadata peut être envoyé sous forme de String selon la version de FedaPay
  let customMeta = entity.custom_metadata || {};
  if (typeof customMeta === "string") {
    try { customMeta = JSON.parse(customMeta); } catch (e) {}
  }

  const { userId, planId } = customMeta; // Récupération des données passées à la création

  // ICI : Mettez à jour votre base de données Firestore / SQL
  // IMPORTANT : Renvoyez TOUJOURS un code 200 OK rapidement à FedaPay
  return res.status(200).send("OK"); 
});
```

---

## 🛡️ 6. Système de Secours : L'Espace Réclamation

Même avec un Webhook parfait, un problème réseau, un serveur redémarré ou une panne FedaPay peut faire qu'un utilisateur soit débité sur son Mobile Money, mais que le Webhook n'arrive jamais à votre serveur. 

**C'est indispensable pour une application sérieuse de prévoir un Espace Réclamation.**

1. L'utilisateur copie sa référence de transaction (l'ID FedaPay, ex: `111665518`).
2. L'application mobile envoie cet ID à votre serveur via une route `POST /claim-payment`.
3. Le serveur interroge l'API FedaPay en direct pour vérifier la véracité de la réclamation.

```javascript
const fedaTx = await Transaction.retrieve(transactionId);

if (fedaTx.status === "approved") {
  // L'utilisateur a bien payé ! Mais le webhook avait échoué.
  // 1. Vérifier que la transaction appartient bien à l'utilisateur via fedaTx.custom_metadata
  // 2. Vérifier que cette transaction n'a pas déjà été réclamée (pour éviter les doublons).
  // 3. (Optionnel) Limiter les réclamations aux paiements de moins de 72H.
  // 4. Mettre à jour la base de données.
}
```

---

## 📧 7. L'Envoi de Facture (Bonus Professionnel)

Pour rassurer le client et garder une trace légale, envoyez une facture HTML avec `nodemailer` lors de la validation du paiement (dans le Webhook et dans l'Espace Réclamation).

**Si vous utilisez Gmail (SMTP) :**
- Google bloque les connexions par mot de passe standard.
- Vous devez activer la **Validation en 2 étapes** sur le compte Google de l'entreprise.
- Générez un **Mot de passe d'application** (une clé de 16 caractères).
- Dans Node.js :
```javascript
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: { user: "contact@entreprise.com", pass: "MOT_DE_PASSE_16_LETTRES" }
});
```

---

## 🚨 Récapitulatif des erreurs rencontrées durant notre développement :

- **Erreur Firebase "5 Not Found" :** Assurez-vous que votre backend utilise exactement le même projet Firebase (`gcrm-2744f`) que votre application mobile, et que le `FIREBASE_SERVICE_ACCOUNT_JSON` est correctement formatté dans les variables d'environnement.
- **Erreur de parsing JSON sur l'API FedaPay :** Utilisez le SDK Officiel. FedaPay retourne la transaction sous `data.v1.transaction` dans sa réponse brute REST, ce qui peut casser la logique si vous parsez manuellement la réponse.
- **Erreur de syntaxe Backticks (Node.js) :** Faites attention à l'échappement des littéraux de gabarit (` \` `) dans votre code JavaScript lors des copier-coller.
