require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const axios = require("axios");
const admin = require("firebase-admin");

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
      console.log(" Firebase Admin initialisé via SERVICE_ACCOUNT_JSON");
    } else {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
      console.log(" Firebase Admin initialisé via applicationDefault");
    }
  } catch (err) {
    console.error("Erreur initialisation Firebase:", err.message);
    process.exit(1);
  }
}

initFirebase();
const db = admin.firestore();

// ============================================================
//  FedaPay Config
// ============================================================
const FEDAPAY_SECRET_KEY = process.env.FEDAPAY_SECRET_KEY || "";
const FEDAPAY_API_URL = "https://api.fedapay.com/v1";

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

// Middleware sécurité
app.use(helmet());
app.use(express.json({ limit: "1mb" }));
app.use(
  cors({
    origin: "*", // L'app Flutter fait des requêtes via HTTP, pas navigateur
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "x-api-key"],
  })
);

// Rate limiting — 30 req/min par IP
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  message: { error: "Trop de requêtes, réessayez dans 1 minute." },
});
app.use(limiter);

// Vérification clé API interne (optionnelle selon l'appelant)
const INTERNAL_API_KEY = process.env.INTERNAL_API_KEY || "";
function requireApiKey(req, res, next) {
  if (!INTERNAL_API_KEY) return next(); // Pas de clé configurée = pas de vérif
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
    return res
      .status(400)
      .json({ error: "Paramètres requis: enterpriseId, planId, amount" });
  }

  if (!FEDAPAY_SECRET_KEY) {
    console.error("FEDAPAY_SECRET_KEY non configurée !");
    return res.status(500).json({ error: "Configuration serveur incomplète" });
  }

  try {
    // Récupérer l'email de l'entreprise depuis Firestore
    const entDoc = await db.collection("enterprises").doc(enterpriseId).get();
    if (!entDoc.exists) {
      return res.status(404).json({ error: "Entreprise introuvable" });
    }
    const enterprise = entDoc.data();

    const serviceUrl = process.env.PAYMENT_SERVICE_URL || `https://g-crm-payment-service.onrender.com`;

    // 1. Créer la transaction FedaPay
    const fedapayRes = await axios.post(
      `${FEDAPAY_API_URL}/transactions`,
      {
        description: `Abonnement G-CRM — Plan ${planName || planId}`,
        amount: parseInt(amount),
        currency: { iso: "XOF" },
        callback_url: `${serviceUrl}/webhook`,
        metadata: {
          enterpriseId,
          planId,
        },
        customer: {
          firstname: enterprise.name || "Client",
          lastname: "G-CRM",
          email: enterprise.email || "contact@g-crm.app",
        },
      },
      {
        headers: {
          Authorization: `Bearer ${FEDAPAY_SECRET_KEY}`,
          "Content-Type": "application/json",
        },
        timeout: 10000,
      }
    );

    const transaction = fedapayRes.data?.v1?.transaction;
    if (!transaction?.id) {
      throw new Error("Réponse FedaPay invalide (pas de transaction.id)");
    }

    // 2. Générer le token de paiement (checkout URL)
    const tokenRes = await axios.get(
      `${FEDAPAY_API_URL}/transactions/${transaction.id}/token`,
      {
        headers: {
          Authorization: `Bearer ${FEDAPAY_SECRET_KEY}`,
        },
        timeout: 10000,
      }
    );

    const token = tokenRes.data?.v1?.token?.token;
    if (!token) {
      throw new Error("Token de paiement introuvable dans la réponse FedaPay");
    }

    const checkoutUrl = `https://checkout.fedapay.com/${token}`;

    // 3. Enregistrer la transaction en attente dans Firestore
    await db
      .collection("payments")
      .doc(transaction.id.toString())
      .set({
        enterpriseId,
        planId,
        amount: parseInt(amount),
        status: "pending",
        fedapayTransactionId: transaction.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(
      ` Transaction FedaPay créée: #${transaction.id} — Plan ${planId} — Entreprise ${enterpriseId}`
    );

    return res.status(200).json({
      checkoutUrl,
      transactionId: transaction.id,
    });
  } catch (err) {
    const detail = err.response?.data || err.message;
    console.error("Erreur création transaction:", detail);
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
    console.log("🔔 Webhook FedaPay reçu:", JSON.stringify(event));

    // FedaPay peut envoyer plusieurs formats selon la version
    const transaction =
      event?.v1?.transaction ||
      event?.data?.object?.transaction ||
      event?.transaction ||
      event?.data;

    if (!transaction) {
      console.warn("⚠️ Webhook sans transaction valide reçu");
      return res.status(200).send("OK");
    }

    const status = transaction.status;
    const metadata = transaction.metadata || {};
    const { enterpriseId, planId } = metadata;

    console.log(
      `📦 Transaction #${transaction.id} — status: ${status} — planId: ${planId} — enterpriseId: ${enterpriseId}`
    );

    if (status === "approved" && enterpriseId && planId) {
      const quotas = PLAN_QUOTAS[planId];
      if (!quotas) {
        console.warn(`⚠️ Plan inconnu dans le webhook: ${planId}`);
        return res.status(200).send("OK");
      }

      // Mise à jour du plan et des quotas dans Firestore (atomique)
      const batch = db.batch();

      // 1. Mettre à jour l'entreprise
      const entRef = db.collection("enterprises").doc(enterpriseId);
      batch.update(entRef, {
        planId,
        ...quotas,
        lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 2. Mettre à jour le statut du paiement
      const payRef = db
        .collection("payments")
        .doc(transaction.id.toString());
      batch.update(payRef, {
        status: "approved",
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 3. Notification in-app pour l'entreprise
      const notifId = `notif_payment_${Date.now()}`;
      const notifRef = db.collection("notifications").doc(notifId);
      batch.set(notifRef, {
        id: notifId,
        title: " Abonnement activé",
        body: `Votre plan ${planId} est maintenant actif. Bonne prospection !`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "payment",
        relatedId: transaction.id.toString(),
        targetUserId: enterpriseId,
        isRead: false,
      });

      await batch.commit();

      console.log(
        ` Plan ${planId} activé pour l'entreprise ${enterpriseId}`
      );
    } else if (status === "declined" && enterpriseId) {
      // Mettre à jour le statut du paiement en cas d'échec
      await db
        .collection("payments")
        .doc(transaction.id.toString())
        .update({
          status: "declined",
          declinedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Notification d'échec
      const notifId = `notif_payment_fail_${Date.now()}`;
      await db.collection("notifications").doc(notifId).set({
        id: notifId,
        title: "Paiement refusé",
        body: "Votre paiement n'a pas pu être traité. Veuillez réessayer.",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "payment",
        relatedId: transaction.id.toString(),
        targetUserId: enterpriseId,
        isRead: false,
      });

      console.warn(
        `⚠️ Paiement refusé pour l'entreprise ${enterpriseId} — Transaction #${transaction.id}`
      );
    } else {
      console.log(
        `ℹ️ Webhook ignoré — status: ${status}, enterpriseId: ${enterpriseId}`
      );
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
  console.log(`🚀 G-CRM Payment Service démarré sur le port ${PORT}`);
  console.log(`   FedaPay: ${FEDAPAY_SECRET_KEY ? " configuré" : "MANQUANT"}`);
  console.log(`   Firebase:  initialisé`);
});
