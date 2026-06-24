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
