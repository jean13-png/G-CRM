# G-CRM Payment Service

Microservice Express.js qui gère les paiements FedaPay et met à jour automatiquement les quotas dans Firestore. **Aucun Firebase Blaze requis.**

## Endpoints

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/health` | Ping keep-alive pour Render |
| POST | `/create-transaction` | Crée un lien de paiement FedaPay |
| POST | `/webhook` | Reçoit les confirmations FedaPay |

## Déploiement sur Render.com (gratuit)

### 1. Firebase Service Account

1. Aller sur [Firebase Console](https://console.firebase.google.com/project/gcrm-c2cdd/settings/serviceaccounts/adminsdk)
2. Cliquer **"Générer une nouvelle clé privée"**
3. Télécharger le fichier JSON
4. Convertir en une seule ligne :
   ```bash
   cat firebase-service-account.json | tr -d '\n'
   ```
5. Copier la valeur → ce sera `FIREBASE_SERVICE_ACCOUNT_JSON`

### 2. Créer le service sur Render

1. Aller sur [render.com](https://render.com) → **New > Web Service**
2. Connecter le repo GitHub du projet
3. Configurer :
   - **Root Directory** : `payment-service`
   - **Build Command** : `npm install`
   - **Start Command** : `npm start`
   - **Plan** : Free

4. Dans **Environment Variables**, ajouter :

| Variable | Valeur |
|----------|--------|
| `FEDAPAY_SECRET_KEY` | `sk_live_YOUR_FEDAPAY_SECRET_KEY` |
| `FEDAPAY_PUBLIC_KEY` | `pk_live_YOUR_FEDAPAY_PUBLIC_KEY` |
| `PAYMENT_SERVICE_URL` | `https://g-crm-payment-service.onrender.com` |
| `INTERNAL_API_KEY` | `gcrm_pay_internal_2026` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | *(JSON en une seule ligne)* |

5. **Déployer** → noter l'URL (ex: `https://g-crm-payment-service.onrender.com`)

### 3. Mettre à jour l'app Flutter

Dans le fichier `.env` racine du projet, ajouter :
```
PAYMENT_SERVICE_URL=https://g-crm-payment-service.onrender.com
PAYMENT_INTERNAL_API_KEY=gcrm_pay_internal_2026
```

### 4. Configurer le Webhook FedaPay

1. Aller sur [app.fedapay.com](https://app.fedapay.com) → **Webhooks**
2. Ajouter l'URL : `https://g-crm-payment-service.onrender.com/webhook`
3. Sélectionner l'événement : `transaction.approved`

## Test local

```bash
cd payment-service
npm install
npm start
# Service disponible sur http://localhost:3002
```

Test de santé :
```bash
curl http://localhost:3002/health
```

Test création transaction :
```bash
curl -X POST http://localhost:3002/create-transaction \
  -H "Content-Type: application/json" \
  -H "x-api-key: gcrm_pay_internal_2026" \
  -d '{"enterpriseId":"TEST_ID","planId":"STARTER","amount":14900,"planName":"Starter"}'
```
