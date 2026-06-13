const admin = require('firebase-admin');

// Initialiser Firebase Admin
function initFirebase() {
  try {
    // Vérifier si déjà initialisé
    if (admin.apps.length === 0) {
      // Pour la prod, utilisez une variable d'environnement GOOGLE_APPLICATION_CREDENTIALS
      // Pour le dev, vous pouvez utiliser un fichier serviceAccountKey.json
      // Pour l'instant, on va utiliser la configuration par défaut (si on a google-cloud-sdk)
      admin.initializeApp();
    }
    console.log('Firebase Admin initialisé avec succès !');
  } catch (error) {
    console.error('Erreur lors de l\'initialisation de Firebase :', error.message);
    throw error;
  }
}

// Génère un délai aléatoire (10-30s) pour éviter le ban
function getRandomAntiBanDelay() {
  const min = 10000; // 10 secondes
  const max = 30000; // 30 secondes
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// Ajoute des messages à la file d'attente Firestore
async function addBulkMessagesToQueue(enterpriseId, prospects, message) {
  const db = admin.firestore();
  const batch = db.batch();

  const now = admin.firestore.FieldValue.serverTimestamp();
  let sendAt = new Date(); // Premier message immédiatement

  prospects.forEach((prospect) => {
    const docRef = db.collection('whatsapp_queue').doc();
    batch.set(docRef, {
      enterpriseId,
      prospectId: prospect.id,
      phoneNumber: prospect.phone,
      message,
      status: 'pending', // pending, sending, sent, failed, invalid_number
      createdAt: now,
      scheduledAt: sendAt,
    });

    // Ajouter le délai pour le prochain message
    sendAt = new Date(sendAt.getTime() + getRandomAntiBanDelay());
  });

  await batch.commit();
  return { status: 'queued', total: prospects.length };
}

// Récupère le statut de la file d'attente pour une entreprise
async function getQueueStatus(enterpriseId) {
  const db = admin.firestore();
  const snapshot = await db.collection('whatsapp_queue')
    .where('enterpriseId', '==', enterpriseId)
    .get();

  let pending = 0, sending = 0, sent = 0, failed = 0, invalid = 0;
  snapshot.forEach(doc => {
    switch (doc.data().status) {
      case 'pending': pending++; break;
      case 'sending': sending++; break;
      case 'sent': sent++; break;
      case 'failed': failed++; break;
      case 'invalid_number': invalid++; break;
    }
  });

  return { pending, sending, sent, failed, invalid_number: invalid };
}

// Traite la file d'attente en continu
let isProcessing = false;
async function processQueue(whatsappService) {
  if (isProcessing) return;
  isProcessing = true;

  const db = admin.firestore();

  while (true) {
    try {
      // Récupère le prochain message à envoyer
      const now = admin.firestore.Timestamp.now();
      const querySnapshot = await db.collection('whatsapp_queue')
        .where('status', '==', 'pending')
        .where('scheduledAt', '<=', now)
        .orderBy('scheduledAt')
        .limit(1)
        .get();

      if (querySnapshot.empty) {
        // Aucun message à envoyer, attendre un peu
        await new Promise(resolve => setTimeout(resolve, 2000));
        continue;
      }

      const doc = querySnapshot.docs[0];
      const data = doc.data();

      // Marquer comme en cours d'envoi
      await doc.ref.update({ status: 'sending' });

      try {
        // Vérifier si le numéro a WhatsApp
        const hasWhatsApp = await whatsappService.checkIfWhatsAppNumber(data.enterpriseId, data.phoneNumber);
        if (!hasWhatsApp) {
          await doc.ref.update({
            status: 'invalid_number',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }

        // Envoyer le message
        await whatsappService.sendWhatsAppMessage(data.enterpriseId, data.phoneNumber, data.message);

        // Marquer comme envoyé
        await doc.ref.update({
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      } catch (error) {
        // Marquer comme échoué
        await doc.ref.update({
          status: 'failed',
          error: error.message,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

    } catch (error) {
      console.error('Erreur dans le worker de file d\'attente :', error);
      await new Promise(resolve => setTimeout(resolve, 5000)); // Attendre avant de réessayer
    }
  }
}

module.exports = {
  initFirebase,
  addBulkMessagesToQueue,
  getQueueStatus,
  processQueue,
};
