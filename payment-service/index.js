require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const admin = require("firebase-admin");
const FedaPay = require("fedapay");

// ============================================================
//  Firebase Admin — Connexion Firestore
// ============================================================
function initFirebase() {
  try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      console.log("Firebase Admin initialisé via SERVICE_ACCOUNT_JSON");
    } else {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
      console.log("Firebase Admin initialisé via applicationDefault");
    }
  } catch (err) {
    console.error("Erreur initialisation Firebase:", err.message);
    process.exit(1);
  }
}

initFirebase();
const db = admin.firestore();

// ============================================================
//  FedaPay SDK Config
// ============================================================
const FEDAPAY_SECRET_KEY = process.env.FEDAPAY_SECRET_KEY || "";
FedaPay.setApiKey(FEDAPAY_SECRET_KEY);
FedaPay.setEnvironment("live");

const PLAN_QUOTAS = {
  STARTER: {
    appelsManuelsRestants: 600,
    smsManuelsRestants: 600,
    whatsappManuelsRestants: 400,
    prospectsRestants: 800,
    agentsRestants: 5,
  },
  PRO: {
    appelsManuelsRestants: 3500,
    smsManuelsRestants: 3500,
    whatsappManuelsRestants: 1800,
    prospectsRestants: 5000,
    agentsRestants: 20,
  },
  BUSINESS: {
    appelsManuelsRestants: 10000,
    smsManuelsRestants: 10000,
    whatsappManuelsRestants: 5000,
    prospectsRestants: 20000,
    agentsRestants: 100,
  },
};

// ============================================================
//  Express App
// ============================================================
const app = express();
const PORT = process.env.PORT || 3002;

app.use(helmet());
app.use(express.json({ limit: "1mb" }));
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "x-api-key"],
  })
);

const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  message: { error: "Trop de requêtes, réessayez dans 1 minute." },
});
app.use(limiter);

const INTERNAL_API_KEY = process.env.INTERNAL_API_KEY || "";
function requireApiKey(req, res, next) {
  if (!INTERNAL_API_KEY) return next();
  const key = req.headers["x-api-key"];
  if (key !== INTERNAL_API_KEY) {
    return res.status(401).json({ error: "Clé API invalide" });
  }
  next();
}

// ============================================================
//  GET /health  — Ping pour Render keep-alive
// ============================================================
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "g-crm-payment-service",
    timestamp: new Date().toISOString(),
  });
});

// ============================================================
//  POST /create-transaction
//  Appelé depuis l'app Flutter pour créer un lien de paiement
// ============================================================
app.post("/create-transaction", requireApiKey, async (req, res) => {
  const { enterpriseId, planId, amount, planName } = req.body;

  if (!enterpriseId || !planId || !amount) {
    return res.status(400).json({ error: "Paramètres requis: enterpriseId, planId, amount" });
  }

  if (!FEDAPAY_SECRET_KEY) {
    console.error("FEDAPAY_SECRET_KEY non configurée !");
    return res.status(500).json({ error: "Configuration serveur incomplète" });
  }

  try {
    // 1. Récupérer les infos de l'entreprise depuis Firestore
    const entDoc = await db.collection("enterprises").doc(enterpriseId).get();
    if (!entDoc.exists) {
      return res.status(404).json({ error: "Entreprise introuvable" });
    }
    const enterprise = entDoc.data();

    const serviceUrl = process.env.PAYMENT_SERVICE_URL || "https://g-crm-payment-service.onrender.com";

    // 2. Créer la transaction via SDK FedaPay officiel
    const transaction = await FedaPay.Transaction.create({
      description: `Abonnement G-CRM - Plan ${planName || planId}`,
      amount: parseInt(amount),
      currency: { iso: "XOF" },
      callback_url: `${serviceUrl}/webhook`,
      custom_metadata: { enterpriseId, planId },
      customer: {
        firstname: enterprise.name || "Client",
        lastname: "G-CRM",
        email: enterprise.email || "contact@g-crm.app",
      },
    });

    console.log("Transaction creee, id:", transaction.id);

    // 3. Générer le token de paiement
    const token = await transaction.generateToken();
    console.log("Token:", JSON.stringify(token));

    const checkoutUrl = token.url || (token.token ? `https://checkout.fedapay.com/${token.token}` : null);

    if (!checkoutUrl) {
      throw new Error(`URL de paiement introuvable: ${JSON.stringify(token)}`);
    }

    // 4. Enregistrer dans Firestore
    await db.collection("payments").doc(transaction.id.toString()).set({
      enterpriseId,
      planId,
      amount: parseInt(amount),
      status: "pending",
      fedapayTransactionId: transaction.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Transaction #${transaction.id} - Plan ${planId} - Entreprise ${enterpriseId}`);

    return res.status(200).json({
      checkoutUrl,
      transactionId: transaction.id,
    });
  } catch (err) {
    const detail = err.message || String(err);
    console.error("Erreur creation transaction:", detail);
    return res.status(500).json({
      error: "Erreur lors de la création du paiement FedaPay",
      detail,
    });
  }
});

// ============================================================
//  POST /webhook
//  Réception des confirmations de paiement FedaPay
// ============================================================
app.post("/webhook", async (req, res) => {
  try {
    const event = req.body;
    console.log("Webhook FedaPay recu:", event.name, "- transaction id:", event?.entity?.id);

    // L'entité est la transaction dans le webhook FedaPay
    const entity = event?.entity;
    if (!entity) {
      console.warn("Webhook sans entity valide");
      return res.status(200).send("OK");
    }

    const status = entity.status;
    // custom_metadata est un objet ou une string JSON selon la version FedaPay
    let customMeta = entity.custom_metadata || {};
    if (typeof customMeta === "string") {
      try { customMeta = JSON.parse(customMeta); } catch (_) {}
    }
    const { enterpriseId, planId } = customMeta;

    console.log(`Transaction #${entity.id} - status: ${status} - planId: ${planId} - enterpriseId: ${enterpriseId}`);

    if (status === "approved" && enterpriseId && planId) {
      const quotas = PLAN_QUOTAS[planId];
      if (!quotas) {
        console.warn(`Plan inconnu dans le webhook: ${planId}`);
        return res.status(200).send("OK");
      }

      const batch = db.batch();

      // Mettre à jour l'entreprise
      const entRef = db.collection("enterprises").doc(enterpriseId);
      batch.update(entRef, {
        planId,
        ...quotas,
        lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Mettre à jour le statut du paiement
      const payRef = db.collection("payments").doc(entity.id.toString());
      batch.update(payRef, {
        status: "approved",
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notification in-app
      const notifId = `notif_payment_${Date.now()}`;
      const notifRef = db.collection("notifications").doc(notifId);
      batch.set(notifRef, {
        id: notifId,
        title: "Abonnement activé",
        body: `Votre plan ${planId} est maintenant actif. Bonne prospection !`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "payment",
        relatedId: entity.id.toString(),
        targetUserId: enterpriseId,
        isRead: false,
      });

      await batch.commit();
      console.log(`Plan ${planId} active pour l'entreprise ${enterpriseId}`);

    } else if (status === "declined" && enterpriseId) {
      await db.collection("payments").doc(entity.id.toString()).update({
        status: "declined",
        declinedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.warn(`Paiement refuse - Entreprise ${enterpriseId} - Transaction #${entity.id}`);
    } else {
      console.log(`Webhook ignore - status: ${status}, event: ${event.name}`);
    }

    return res.status(200).send("OK");
  } catch (err) {
    console.error("Erreur webhook FedaPay:", err.message);
    return res.status(500).send("Erreur interne");
  }
});

// ============================================================
//  Démarrage
// ============================================================
app.listen(PORT, () => {
  console.log(`G-CRM Payment Service demarre sur le port ${PORT}`);
  console.log(`FedaPay: ${FEDAPAY_SECRET_KEY ? "configure" : "MANQUANT"}`);
  console.log(`Firebase: initialise`);
});
