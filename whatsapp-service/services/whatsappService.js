const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } = require('@whiskeysockets/baileys');
const QRCode = require('qrcode');
const pino = require('pino');
const path = require('path');
const fs = require('fs');

// Stockage des sessions en mémoire (pour l'instant, à remplacer par Redis/Firestore en production)
const sessions = new Map();
const qrCodes = new Map();
const connectionStatus = new Map();

const SESSIONS_DIR = path.join(__dirname, '../sessions');
if (!fs.existsSync(SESSIONS_DIR)) fs.mkdirSync(SESSIONS_DIR, { recursive: true });

/**
 * Initialise le gestionnaire de sessions WhatsApp
 */
async function initWhatsAppClient() {
  console.log('WhatsApp session manager initialized');
}

/**
 * Crée une nouvelle session WhatsApp pour une entreprise
 */
async function createSession(enterpriseId) {
  if (sessions.has(enterpriseId)) {
    return { status: 'existing', message: 'Session already exists' };
  }

  const { state, saveCreds } = await useMultiFileAuthState(path.join(SESSIONS_DIR, enterpriseId));
  const { version, isLatest } = await fetchLatestBaileysVersion();
  console.log(`Using WhatsApp version ${version} (latest: ${isLatest})`);

  const sock = makeWASocket({
    version,
    auth: state,
    printQRInTerminal: false,
    logger: pino({ level: 'silent' }),
    markOnlineOnConnect: true,
  });

  sessions.set(enterpriseId, { sock, saveCreds });
  connectionStatus.set(enterpriseId, 'connecting');

  // Écoute des événements
  sock.ev.on('creds.update', async () => {
    await saveCreds();
    console.log(`Credentials updated for enterprise ${enterpriseId}`);
  });

  sock.ev.on('connection.update', (update) => {
    const { connection, qr } = update;

    if (qr) {
      // Générer et stocker le QR code en base64
      QRCode.toDataURL(qr, (err, url) => {
        if (!err) {
          qrCodes.set(enterpriseId, url);
          connectionStatus.set(enterpriseId, 'qr_ready');
          console.log(`QR code ready for enterprise ${enterpriseId}`);
        }
      });
    }

    if (connection === 'close') {
      const reason = new DisconnectReason(update.lastDisconnect?.error?.output?.statusCode);
      console.log(`Connection closed for ${enterpriseId}: reason ${reason}`);
      
      if (reason !== DisconnectReason.loggedOut) {
        // Reconnexion automatique
        setTimeout(() => createSession(enterpriseId), 3000);
      } else {
        // Supprimer la session si déconnecté manuellement
        deleteSession(enterpriseId);
      }
    } else if (connection === 'open') {
      qrCodes.delete(enterpriseId);
      connectionStatus.set(enterpriseId, 'connected');
      console.log(`Session OPENED for enterprise ${enterpriseId} ✅`);
    }
  });

  return { status: 'created', message: 'Session initialized successfully' };
}

/**
 * Récupère le statut de connexion d'une entreprise
 */
function getSessionStatus(enterpriseId) {
  return {
    status: connectionStatus.get(enterpriseId) || 'disconnected',
    qrCode: qrCodes.get(enterpriseId) || null,
  };
}

/**
 * Supprime une session
 */
async function deleteSession(enterpriseId) {
  const session = sessions.get(enterpriseId);
  if (session?.sock) {
    session.sock.end(new Error('Session deleted by user'));
  }
  sessions.delete(enterpriseId);
  qrCodes.delete(enterpriseId);
  connectionStatus.delete(enterpriseId);
  
  // Supprimer les fichiers de session locaux
  const sessionDir = path.join(SESSIONS_DIR, enterpriseId);
  if (fs.existsSync(sessionDir)) {
    fs.rmSync(sessionDir, { recursive: true, force: true });
  }
  console.log(`Session deleted for enterprise ${enterpriseId}`);
}

/**
 * Vérifie si un numéro a un compte WhatsApp
 */
async function checkIfWhatsAppNumber(enterpriseId, phoneNumber) {
  const session = sessions.get(enterpriseId);
  if (!session || connectionStatus.get(enterpriseId) !== 'connected') {
    throw new Error('WhatsApp session not connected');
  }

  try {
    const [result] = await session.sock.onWhatsApp(phoneNumber);
    return result?.exists || false;
  } catch (error) {
    console.error(`Error checking WhatsApp number ${phoneNumber}:`, error.message);
    return false;
  }
}

/**
 * Envoie un message WhatsApp
 */
async function sendWhatsAppMessage(enterpriseId, phoneNumber, message) {
  const session = sessions.get(enterpriseId);
  if (!session || connectionStatus.get(enterpriseId) !== 'connected') {
    throw new Error('WhatsApp session not connected');
  }

  try {
    const formattedNumber = phoneNumber.replace(/\D/g, '');
    const jid = `${formattedNumber}@s.whatsapp.net`;
    
    // Envoyer le message texte
    await session.sock.sendMessage(jid, { text: message });
    
    return { success: true, jid };
  } catch (error) {
    console.error(`Error sending WhatsApp message to ${phoneNumber}:`, error.message);
    throw error;
  }
}

module.exports = {
  initWhatsAppClient,
  createSession,
  getSessionStatus,
  deleteSession,
  checkIfWhatsAppNumber,
  sendWhatsAppMessage,
};
