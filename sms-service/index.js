const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const dotenv = require('dotenv');
const { Queue, Worker } = require('bullmq');
const IORedis = require('ioredis');
const axios = require('axios');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

dotenv.config();

console.log('🚀 Initialisation du Microservice SMS...');

const PORT = Number(process.env.PORT || 3001);
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'g-crm-pwa';
const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = Number(process.env.REDIS_PORT || 6379);
const INTERNAL_API_KEY = process.env.INTERNAL_API_KEY || '';
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

function corsOptions() {
  if (ALLOWED_ORIGINS.length === 0) {
    return { origin: false };
  }
  return {
    origin(origin, callback) {
      if (!origin || ALLOWED_ORIGINS.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error('Origin non autorisee'));
    },
  };
}

function authMiddleware(req, res, next) {
  if (!INTERNAL_API_KEY) {
    return res.status(503).json({ success: false, message: 'Service non configure' });
  }
  const incoming = req.header('x-api-key');
  if (!incoming || incoming !== INTERNAL_API_KEY) {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }
  return next();
}

try {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    path.join(__dirname, 'firebase-service-account.json');
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: 'g-crm-pwa.appspot.com',
    });
    console.log('✅ Firebase Admin initialisé via service account');
  } else {
    admin.initializeApp({
      projectId: FIREBASE_PROJECT_ID,
    });
    console.log('✅ Firebase Admin initialisé via ADC/projectId');
  }
} catch (error) {
  console.warn('⚠️ Firebase non configuré:', error.message);
}

const connection = new IORedis({
  host: REDIS_HOST,
  port: REDIS_PORT,
  maxRetriesPerRequest: null,
});

const smsQueue = new Queue('sms-queue', { connection });
const app = express();

app.use(helmet());
app.use(cors(corsOptions()));
app.use(express.json({ limit: '256kb' }));
app.use(rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
}));

let androidGatewayUrl = null;
let androidGatewayToken = null;

app.post('/configure', authMiddleware, async (req, res) => {
  try {
    const { gatewayUrl, apiToken } = req.body;
    if (!gatewayUrl || !apiToken) {
      return res.status(400).json({ success: false, message: 'gatewayUrl et apiToken requis' });
    }
    androidGatewayUrl = gatewayUrl;
    androidGatewayToken = apiToken;

    console.log('🔧 Configuration mise à jour :', { gatewayUrl, hasToken: !!apiToken });
    res.json({ success: true, message: 'Passerelle SMS configurée avec succès' });
  } catch (e) {
    console.error('Erreur configuration:', e);
    res.status(500).json({ success: false, message: 'Erreur configuration' });
  }
});

app.post('/send', authMiddleware, async (req, res) => {
  try {
    const { phoneNumbers, message, enterpriseId } = req.body;
    
    if (!Array.isArray(phoneNumbers) || phoneNumbers.length === 0) {
      return res.status(400).json({ success: false, message: 'Aucun numéro fourni' });
    }
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ success: false, message: 'Message invalide' });
    }
    if (!enterpriseId || typeof enterpriseId !== 'string') {
      return res.status(400).json({ success: false, message: 'enterpriseId invalide' });
    }

    const jobs = phoneNumbers.map((phone, index) => ({
      phone: phone,
      message: message,
      enterpriseId: enterpriseId
    }));

    await smsQueue.addBulk(jobs.map((data, index) => ({
      name: `sms-${enterpriseId}-${Date.now()}-${index}`,
      data: data,
      opts: { delay: 0 }
    })));

    console.log(`📥 ${jobs.length} SMS ajoutés à la file d'attente`);
    res.json({ success: true, queued: jobs.length, message: 'SMS en file d\'attente' });
  } catch (error) {
    console.error('Erreur envoi SMS:', error);
    res.status(500).json({ success: false, message: 'Erreur interne' });
  }
});

app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    gatewayConfigured: !!(androidGatewayUrl && androidGatewayToken),
    service: 'SMS Gateway',
    hasApiKey: !!INTERNAL_API_KEY,
  });
});

const worker = new Worker('sms-queue', async (job) => {
  const { phone, message, enterpriseId } = job.data;
  console.log(`📤 Traitement SMS vers ${phone}...`);

  const randomDelay = Math.floor(Math.random() * 20000) + 10000;
  
  try {
    if (androidGatewayUrl && androidGatewayToken) {
      // Envoyer via le téléphone Android
      await axios.post(`${androidGatewayUrl}/send`, {
        phoneNumbers: [phone],
        message: message,
        simSlot: 0 // Carte SIM 1 par défaut
      }, {
        headers: {
          'Authorization': `Bearer ${androidGatewayToken}`,
          'Content-Type': 'application/json'
        }
      });
      
      console.log(`✅ SMS envoyé avec succès à ${phone}`);
    } else {
      // Mode démonstration si pas configuré
      console.log(`⚠️ Mode démo - SMS simulé pour ${phone}`);
    }

    await new Promise(resolve => setTimeout(resolve, randomDelay));
    return { success: true };

  } catch (error) {
    console.error(`❌ Échec SMS vers ${phone}:`, error.message);
    throw error;
  }
}, { connection });

worker.on('completed', (job) => {
  console.log(`✅ Job terminé : ${job.id}`);
});

worker.on('failed', (job, err) => {
  console.log(`❌ Job échoué : ${job.id}`, err.message);
});

app.listen(PORT, () => {
  console.log(`✅ Microservice SMS opérationnel sur http://localhost:${PORT}`);
  console.log('🔐 Auth API key active:', !!INTERNAL_API_KEY);
});
