const nodemailer = require("nodemailer");

// Configuration de Nodemailer avec Gmail
// L'utilisateur doit ajouter GMAIL_USER et GMAIL_PASS dans Render Environment
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_PASS,
  },
});

if (!process.env.GMAIL_USER || !process.env.GMAIL_PASS) {
  console.error("ERROR: GMAIL_USER and GMAIL_PASS environment variables are required");
}

/**
 * Envoie une facture par e-mail
 * @param {string} email Email du client
 * @param {string} enterpriseName Nom de l'entreprise
 * @param {string} planId Nom du plan
 * @param {number} amount Montant payé
 * @param {string} transactionId Référence de la transaction
 * @param {Date} date Date de la transaction
 */
async function sendInvoiceEmail(email, enterpriseName, planId, amount, transactionId, date) {
  if (!process.env.GMAIL_USER || !process.env.GMAIL_PASS) {
    console.error("Cannot send email: Gmail credentials not configured");
    return false;
  }

  try {
    const formattedDate = date.toLocaleDateString("fr-FR", {
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    // Le HTML du mail: Ultra propre, pas d'emojis, couleurs unies G-CRM
    const mailHtml = `
    <!DOCTYPE html>
    <html lang="fr">
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f6f9; margin: 0; padding: 20px; color: #333; }
        .container { max-width: 600px; background-color: #ffffff; margin: 0 auto; padding: 40px; border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.05); border-top: 4px solid #1a237e; }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { color: #1a237e; font-size: 28px; margin: 0; letter-spacing: 1px; }
        .header p { color: #666; font-size: 14px; margin-top: 5px; }
        .invoice-details { background-color: #f8f9fa; padding: 20px; border-radius: 6px; margin-bottom: 30px; }
        .invoice-details table { width: 100%; }
        .invoice-details th { text-align: left; padding: 8px 0; color: #555; font-weight: 600; width: 40%; }
        .invoice-details td { text-align: right; padding: 8px 0; color: #222; font-weight: bold; }
        .amount-row { border-top: 2px solid #e0e0e0; margin-top: 10px; padding-top: 10px; }
        .amount-row th, .amount-row td { font-size: 18px; color: #1a237e; }
        .footer { text-align: center; margin-top: 40px; font-size: 12px; color: #888; border-top: 1px solid #eee; padding-top: 20px; }
        .claim-notice { margin-top: 20px; padding: 15px; border-left: 4px solid #ff9800; background-color: #fff3e0; font-size: 13px; color: #e65100; border-radius: 0 4px 4px 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>G-CRM</h1>
          <p>Facture de paiement d'abonnement</p>
        </div>
        
        <p>Bonjour <strong>${enterpriseName}</strong>,</p>
        <p>Nous vous confirmons la réception de votre paiement pour votre abonnement au service G-CRM. Votre compte a été mis à jour avec succès.</p>
        
        <div class="invoice-details">
          <table>
            <tr>
              <th>Référence Transaction</th>
              <td>#${transactionId}</td>
            </tr>
            <tr>
              <th>Date</th>
              <td>${formattedDate}</td>
            </tr>
            <tr>
              <th>Abonnement</th>
              <td>Plan ${planId}</td>
            </tr>
            <tr class="amount-row">
              <th>Montant payé</th>
              <td>${amount} FCFA</td>
            </tr>
          </table>
        </div>

        <p>Vous pouvez retrouver l'historique de vos paiements dans l'application G-CRM.</p>

        <div class="claim-notice">
          <strong>Information Réclamation :</strong> Conservez la référence <strong>${transactionId}</strong>. En cas de problème ou de débit non attribué, vous pouvez utiliser cette référence dans l'espace Réclamation de l'application (valable 72 heures).
        </div>

        <div class="footer">
          Ceci est un e-mail généré automatiquement, merci de ne pas y répondre.<br>
          &copy; ${new Date().getFullYear()} G-CRM. Tous droits réservés.
        </div>
      </div>
    </body>
    </html>
    `;

    await transporter.sendMail({
      from: '"G-CRM Facturation" <' + process.env.GMAIL_USER + '>',
      to: email,
      subject: `Facture G-CRM - Abonnement Plan ${planId}`,
      html: mailHtml,
    });
    console.log(`Facture envoyée à ${email} pour la transaction ${transactionId}`);
    return true;
  } catch (error) {
    console.error("Erreur lors de l'envoi de la facture:", error.message);
    return false;
  }
}

module.exports = { sendInvoiceEmail };
