const express = require('express');
const whatsappService = require('../services/whatsappService');
const queueService = require('../services/queueService');
const router = express.Router();

// Route pour créer une nouvelle session WhatsApp (QR code)
router.post('/session/:enterpriseId', async (req, res) => {
  try {
    const enterpriseId = req.params.enterpriseId;
    const result = await whatsappService.createSession(enterpriseId);
    res.status(200).json(result);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create session', details: error.message });
  }
});

// Route pour vérifier le statut d'une session
router.get('/session/:enterpriseId', async (req, res) => {
  try {
    const enterpriseId = req.params.enterpriseId;
    const status = whatsappService.getSessionStatus(enterpriseId);
    res.status(200).json(status);
  } catch (error) {
    res.status(500).json({ error: 'Failed to get session status', details: error.message });
  }
});

// Route pour vérifier si un numéro est sur WhatsApp
router.post('/check-number/:enterpriseId', async (req, res) => {
  try {
    const enterpriseId = req.params.enterpriseId;
    const { phoneNumber } = req.body;
    const exists = await whatsappService.checkIfWhatsAppNumber(enterpriseId, phoneNumber);
    res.status(200).json({ phoneNumber, exists });
  } catch (error) {
    res.status(500).json({ error: 'Failed to check number', details: error.message });
  }
});

// Route pour ajouter un lot de messages à la file d'attente
router.post('/send-bulk/:enterpriseId', async (req, res) => {
  try {
    const enterpriseId = req.params.enterpriseId;
    const { prospects, message } = req.body;
    
    if (!prospects || prospects.length === 0) {
      return res.status(400).json({ error: 'No prospects provided' });
    }
    if (!message) {
      return res.status(400).json({ error: 'No message provided' });
    }

    const result = await queueService.addBulkMessagesToQueue(enterpriseId, prospects, message);
    res.status(200).json(result);
  } catch (error) {
    res.status(500).json({ error: 'Failed to queue messages', details: error.message });
  }
});

// Route pour récupérer le statut de la file d'attente
router.get('/queue/:enterpriseId', async (req, res) => {
  try {
    const enterpriseId = req.params.enterpriseId;
    const queueStatus = await queueService.getQueueStatus(enterpriseId);
    res.status(200).json(queueStatus);
  } catch (error) {
    res.status(500).json({ error: 'Failed to get queue status', details: error.message });
  }
});

module.exports = router;
