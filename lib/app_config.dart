class AppConfig {
  // Brevo Configuration (Global)
  static const String brevoApiKey = 'REMPLACER_PAR_VOTRE_CLE_BREVO';
  static const String brevoSenderEmail = 'jeanjonathan.v.pro@gmail.com';
  static const String brevoSenderName = 'G-CRM';

  // Africa's Talking Configuration (Global)
  static const String africaTalkingApiKey = 'REMPLACER_PAR_VOTRE_CLE_AFRICA_TALKING';
  static const String africaTalkingUsername = 'sandbox';
  static const String africaTalkingPhoneNumber = '';

  // Evolution API Configuration (Global - Notre serveur privé)
  static const String evolutionApiUrl = 'https://evolution-api-latest-62vs.onrender.com';
  static const String evolutionApiKey = 'REMPLACER_PAR_VOTRE_CLE_EVOLUTION';

  // WhatsApp Microservice Configuration (Obsolete - conservé pour compatibilité temporaire)
  static const String whatsappServiceUrl = 'http://localhost:3000';

  // SMS Microservice Configuration (Obsolete - conservé pour compatibilité temporaire)
  static const String smsServiceUrl = 'http://localhost:3001';
}
