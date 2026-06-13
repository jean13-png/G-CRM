const express = require('express');
const cors = require('cors');
const { Queue, Worker } = require('bullmq');
const IORedis = require('ioredis');
const axios = require('axios');
const admin = require('firebase-admin');
const serviceAccount = require('./firebase-service-account.json');

console.log('🚀 Initialisation du Microservice SMS Local...');

try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'g-crm-pwa.appspot.com'
  });
  console.log('✅ Firebase Admin initialisé');
} catch (error) {
  console.warn('⚠️ Firebase non configuré, utilisation en mode basique');
}

const connection = new IORedis({
  host: 'localhost',
  port: 6379,
  maxRetriesPerRequest: null
});

const smsQueue = new Queue('sms-queue', { connection });
const app = express();
const PORT = 3001;

app.use(cors());
app.use(express.json());

let androidGatewayUrl = null;
let androidGatewayToken = null;

app.post('/configure', async (req, res) => {
  try {
    const { gatewayUrl, apiToken } = req.body;
    androidGatewayUrl = gatewayUrl;
    androidGatewayToken = apiToken;

    console.log('🔧 Configuration mise à jour :', { gatewayUrl, hasToken: !!apiToken });
    res.json({ success: true, message: 'Passerelle SMS configurée avec succès' });
  } catch (e) {
    console.error('Erreur configuration:', e);
    res.status(500).json({ success: false, message: 'Erreur configuration' });
  }
});

app.post('/send', async (req, res) => {
  try {
    const { phoneNumbers, message, enterpriseId } = req.body;
    
    if (!phoneNumbers || phoneNumbers.length === 0) {
      return res.status(400).json({ success: false, message: 'Aucun numéro fourni' });
    }

    const jobs = phoneNumbers.map((phone, index) => ({
      phone: phone,
      message: message,
      enterpriseId: enterpriseId
    }));

    await smsQueue.addBulk(jobs.map(data => ({
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
    service: 'SMS Local Gateway'
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
  console.log('💡 Utilisez l\'API /configure pour connecter votre téléphone Android');
});
