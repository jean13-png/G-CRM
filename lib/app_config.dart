class AppConfig {
  // IMPORTANT:
  // Ne jamais stocker de secrets dans le code.
  // Injecter via --dart-define à la build/release.

  static const String brevoApiKey =
      String.fromEnvironment('BREVO_API_KEY', defaultValue: '');
  static const String brevoSenderEmail =
      String.fromEnvironment('BREVO_SENDER_EMAIL', defaultValue: '');
  static const String brevoSenderName =
      String.fromEnvironment('BREVO_SENDER_NAME', defaultValue: 'G-CRM');

  static const String africaTalkingApiKey =
      String.fromEnvironment('AFRICATALKING_API_KEY', defaultValue: '');
  static const String africaTalkingUsername =
      String.fromEnvironment('AFRICATALKING_USERNAME', defaultValue: '');
  static const String africaTalkingPhoneNumber =
      String.fromEnvironment('AFRICATALKING_PHONE_NUMBER', defaultValue: '');

  static const String evolutionApiUrl = String.fromEnvironment(
    'EVOLUTION_API_URL',
    defaultValue: 'https://evolution-api-latest-62vs.onrender.com',
  );
  static const String evolutionApiKey =
      String.fromEnvironment('EVOLUTION_API_KEY', defaultValue: '');

  // Compat legacy microservices
  static const String whatsappServiceUrl = String.fromEnvironment(
    'WHATSAPP_SERVICE_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const String smsServiceUrl = String.fromEnvironment(
    'SMS_SERVICE_URL',
    defaultValue: 'http://localhost:3001',
  );
  static const String internalApiKey =
      String.fromEnvironment('INTERNAL_API_KEY', defaultValue: '');

  // FedaPay Configuration
  static const String fedapayPublicKey =
      String.fromEnvironment('FEDAPAY_PUBLIC_KEY', defaultValue: '');

  // Payment service configuration
  static const String paymentServiceUrl = String.fromEnvironment(
    'PAYMENT_SERVICE_URL',
    defaultValue: 'http://localhost:3002',
  );
  static const String paymentInternalApiKey =
      String.fromEnvironment('PAYMENT_INTERNAL_API_KEY', defaultValue: '');
}
