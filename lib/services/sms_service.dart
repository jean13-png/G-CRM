import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_config.dart';

class SmsService {
  static const String baseUrl = AppConfig.smsServiceUrl;
  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'x-api-key': AppConfig.internalApiKey,
      };

  static Future<Map<String, dynamic>> configureGateway(String gatewayUrl, String apiToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/configure'),
        headers: _headers(),
        body: jsonEncode({'gatewayUrl': gatewayUrl, 'apiToken': apiToken}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendBulkSms(List<String> phoneNumbers, String message, String enterpriseId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send'),
        headers: _headers(),
        body: jsonEncode({
          'phoneNumbers': phoneNumbers,
          'message': message,
          'enterpriseId': enterpriseId
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
