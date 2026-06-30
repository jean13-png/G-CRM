require("dotenv").config();
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

const runtimeConfig = functions.config ? functions.config() : {};
const EVOLUTION_API_URL = process.env.EVOLUTION_API_URL ||
  runtimeConfig?.evolution?.api_url ||
  "https://evolution-api-latest-62vs.onrender.com";
const EVOLUTION_API_KEY = process.env.EVOLUTION_API_KEY ||
  runtimeConfig?.evolution?.api_key ||
  "";

function assertEvolutionConfig() {
  if (!EVOLUTION_API_KEY || !EVOLUTION_API_KEY.trim()) {
    throw new Error("EVOLUTION_API_KEY manquant (env ou functions config)");
  }
}

// ============================================================
//  FedaPay Configuration
// ============================================================
const FEDAPAY_SECRET_KEY = process.env.FEDAPAY_SECRET_KEY ||
  runtimeConfig?.fedapay?.secret_key ||
  "";
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

/**
 * Crée une transaction FedaPay et retourne l'URL de paiement.
 * Appelée depuis l'app Flutter.
 */
exports.createFedaPayTransaction = functions
  .runWith({ timeoutSeconds: 30 })
  .https.onRequest(async (req, res) => {
    // CORS
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Méthode non autorisée" });
      return;
    }

    const { enterpriseId, planId, amount, planName } = req.body;

    if (!enterpriseId || !planId || !amount) {
      res.status(400).json({ error: "Paramètres manquants (enterpriseId, planId, amount)" });
      return;
    }

    if (!FEDAPAY_SECRET_KEY) {
      functions.logger.error("FEDAPAY_SECRET_KEY non configurée");
      res.status(500).json({ error: "Configuration serveur incomplète" });
      return;
    }

    try {
      // Récupérer les infos de l'entreprise
      const entDoc = await db.collection("enterprises").doc(enterpriseId).get();
      if (!entDoc.exists) {
        res.status(404).json({ error: "Entreprise introuvable" });
        return;
      }
      const enterprise = entDoc.data();

      // Créer la transaction FedaPay
      const fedapayRes = await axios.post(
        `${FEDAPAY_API_URL}/transactions`,
        {
          description: `Abonnement G-CRM - Plan ${planName}`,
          amount: amount,
          currency: { iso: "XOF" },
          callback_url: `https://us-central1-gcrm-c2cdd.cloudfunctions.net/fedapayWebhook`,
          metadata: {
            enterpriseId: enterpriseId,
            planId: planId,
          },
          customer: {
            firstname: enterprise.name || "Client",
            lastname: "",
            email: enterprise.email || "",
          },
        },
        {
          headers: {
            Authorization: `Bearer ${FEDAPAY_SECRET_KEY}`,
            "Content-Type": "application/json",
          },
        }
      );

      const transaction = fedapayRes.data?.v1?.transaction;
      if (!transaction) {
        throw new Error("Réponse FedaPay invalide");
      }

      // Générer le token de paiement
      const tokenRes = await axios.get(
        `${FEDAPAY_API_URL}/transactions/${transaction.id}/token`,
        {
          headers: {
            Authorization: `Bearer ${FEDAPAY_SECRET_KEY}`,
          },
        }
      );

      const token = tokenRes.data?.v1?.token?.token;
      if (!token) {
        throw new Error("Token de paiement introuvable");
      }

      const checkoutUrl = `https://checkout.fedapay.com/${token}`;

      // Sauvegarder la transaction en attente dans Firestore
      await db.collection("payments").doc(transaction.id.toString()).set({
        enterpriseId,
        planId,
        amount,
        status: "pending",
        fedapayTransactionId: transaction.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.log(`✅ Transaction FedaPay créée: ${transaction.id} pour ${enterpriseId}`);
      res.status(200).json({ checkoutUrl, transactionId: transaction.id });

    } catch (error) {
      const errMsg = error.response?.data || error.message;
      functions.logger.error("❌ Erreur création transaction FedaPay:", errMsg);
      res.status(500).json({ error: "Erreur lors de la création du paiement", detail: errMsg });
    }
  });

/**
 * Webhook FedaPay — appelé par FedaPay après confirmation du paiement.
 * Active le plan de l'entreprise dans Firestore.
 */
exports.fedapayWebhook = functions
  .runWith({ timeoutSeconds: 60 })
  .https.onRequest(async (req, res) => {
    try {
      const event = req.body;
      functions.logger.log("🔔 Webhook FedaPay reçu:", JSON.stringify(event));

      const transaction = event?.v1?.transaction ||
        event?.data?.object?.transaction ||
        event?.transaction;

      if (!transaction) {
        functions.logger.warn("Webhook sans transaction valide");
        res.status(200).send("OK");
        return;
      }

      const status = transaction.status;
      const metadata = transaction.metadata || {};
      const { enterpriseId, planId } = metadata;

      if (status === "approved" && enterpriseId && planId) {
        const quotas = PLAN_QUOTAS[planId];
        if (!quotas) {
          functions.logger.warn(`Plan inconnu: ${planId}`);
          res.status(200).send("OK");
          return;
        }

        // Mettre à jour le plan et les quotas dans Firestore
        await db.collection("enterprises").doc(enterpriseId).update({
          planId: planId,
          ...quotas,
          lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Mettre à jour le statut du paiement
        await db.collection("payments")
          .doc(transaction.id.toString())
          .update({
            status: "approved",
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        // Notification admin
        const notifId = `notif_payment_${Date.now()}`;
        await db.collection("notifications").doc(notifId).set({
          id: notifId,
          title: "✅ Abonnement activé",
          body: `Votre plan ${planId} est maintenant actif. Bonne prospection !`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          type: "payment",
          relatedId: transaction.id.toString(),
          targetUserId: enterpriseId,
          isRead: false,
        });

        functions.logger.log(`✅ Plan ${planId} activé pour l'entreprise ${enterpriseId}`);
      } else {
        functions.logger.log(`ℹ️ Webhook ignoré — status: ${status}, enterpriseId: ${enterpriseId}`);
      }

      res.status(200).send("OK");
    } catch (error) {
      functions.logger.error("❌ Erreur webhook FedaPay:", error.message);
      res.status(500).send("Erreur interne");
    }
  });



// Fonction pour traiter la queue WhatsApp (1 instance max = envois séquentiels)
exports.processWhatsAppQueue = functions
  .runWith({ maxInstances: 1, timeoutSeconds: 120 })
  .firestore
  .document("whatsapp_queue/{messageId}")
  .onCreate(async (snap) => {
    const messageData = snap.data();
    const messageId = snap.id;

    try {
      assertEvolutionConfig();
      // Attendre si un autre message est déjà en cours (sérialisation)
      const maxWait = 30;
      for (let i = 0; i < maxWait; i++) {
        const inProgress = await db.collection("whatsapp_queue")
          .where("status", "==", "en_cours")
          .limit(1)
          .get();
        if (inProgress.empty || inProgress.docs[0].id === messageId) break;
        await new Promise((r) => setTimeout(r, 2000));
      }

      await snap.ref.update({ status: "en_cours" });

      // Délai anti-ban aléatoire (20-45 secondes)
      const delay = Math.floor(Math.random() * 26000) + 20000;
      await new Promise((resolve) => setTimeout(resolve, delay));

      // Envoyer via Evolution API v2
      const response = await axios.post(
        `${EVOLUTION_API_URL}/message/sendText/${messageData.instanceName}`,
        {
          number: messageData.phoneNumber,
          text: messageData.message,
          delay: 1200,
          presence: "composing"
        },
        {
          headers: {
            "Content-Type": "application/json",
            apikey: EVOLUTION_API_KEY.trim(),
          },
        }
      );

      // Marquer comme envoyé
      await snap.ref.update({ 
        status: "envoye",
        evolutionResponse: response.data
      });
      functions.logger.log(`✅ Message envoyé à ${messageData.phoneNumber} (${messageData.prospectName})`);
    } catch (error) {
      // Marquer comme échoué
      const errorMsg = error.response?.data || error.message;
      await snap.ref.update({
        status: "echoue",
        error: errorMsg,
      });
      functions.logger.error(`❌ Erreur envoi à ${messageData.phoneNumber}:`, errorMsg);
    }
  });

// Fonction planifiée pour ping Render toutes les 5 minutes (empêcher le sommeil)
exports.pingEvolutionApi = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    try {
      assertEvolutionConfig();
      // Un ping plus utile qui vérifie l'auth sur un endpoint léger
      await axios.get(`${EVOLUTION_API_URL}/instance/fetchInstances`, {
        headers: {
          apikey: EVOLUTION_API_KEY.trim(),
        },
        timeout: 5000,
      });
      functions.logger.log("✅ Ping Evolution API réussi !");
    } catch (error) {
      functions.logger.warn("⚠️ Échec du ping Evolution API:", error.message);
    }
  });
