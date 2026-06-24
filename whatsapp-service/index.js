const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const dotenv = require('dotenv');
const whatsappService = require('./services/whatsappService');
const queueService = require('./services/queueService');
const whatsappRoutes = require('./routes/whatsapp');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
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

app.use(helmet());
app.use(cors(corsOptions()));
app.use(express.json({ limit: '256kb' }));
app.use(rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
}));
app.use('/api/whatsapp', whatsappRoutes);

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    message: 'G-CRM WhatsApp Microservice is running!',
    hasApiKey: !!INTERNAL_API_KEY,
  });
});

async function startServer() {
  try {
    console.log('Initialisation du microservice WhatsApp...');
    
    // Étape 1 : Initialiser Firebase Admin
    await queueService.initFirebase();
    
    // Étape 2 : Initialiser le gestionnaire de sessions WhatsApp
    await whatsappService.initWhatsAppClient();
    
    // Étape 3 : Démarrer le worker de file d'attente
    queueService.processQueue(whatsappService);

    app.listen(PORT, () => {
      console.log(`🚀 WhatsApp Microservice listening on http://localhost:${PORT}`);
      console.log('✅ Prêt à recevoir des requêtes !');
    });
  } catch (error) {
    console.error('❌ Échec du démarrage du serveur :', error);
    process.exit(1);
  }
}

startServer();
