const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const whatsappService = require('./services/whatsappService');
const queueService = require('./services/queueService');
const whatsappRoutes = require('./routes/whatsapp');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use('/api/whatsapp', whatsappRoutes);

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'G-CRM WhatsApp Microservice is running!' });
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
