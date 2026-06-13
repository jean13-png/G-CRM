import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_config.dart';
import '../models/prospect.dart';

class WhatsAppService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Génère un nom d'instance court et propre
  static String _getInstanceName(String enterpriseId) {
    // On limite à 10 caractères de l'ID pour éviter les noms trop longs
    String shortId = enterpriseId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (shortId.length > 10) shortId = shortId.substring(0, 10);
    return 'crm$shortId';
  }

  // Étape 1: Créer une instance Evolution API et récupérer le QR Code
  static Future<Map<String, dynamic>> connectInstance(String enterpriseId) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      final cleanKey = AppConfig.evolutionApiKey.trim();
      // On s'assure qu'il n'y a pas de slash à la fin de l'URL
      String baseUrl = AppConfig.evolutionApiUrl.trim();
      if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      
      final apiUrl = '$baseUrl/instance/create';
      
      final headers = {
        'Content-Type': 'application/json',
        'apikey': cleanKey,
      };

      debugPrint('>>> FINAL TRY - URL: $apiUrl');
      debugPrint('>>> Instance: $instanceName');

      // 1. D'abord, on vérifie si l'instance existe déjà
      final checkUrl = '$baseUrl/instance/fetchInstances?instanceName=$instanceName';
      final checkResponse = await http.get(
        Uri.parse(checkUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (checkResponse.statusCode == 200) {
        final List instances = jsonDecode(checkResponse.body);
        bool exists = instances.any((inst) => inst['instanceName'] == instanceName);
        
        if (exists) {
          debugPrint('L\'instance $instanceName existe déjà.');
          return await getInstanceStatus(enterpriseId);
        }
      }
      
      // 2. Si elle n'existe pas, on la crée
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode({
          'instanceName': instanceName,
          'qrcode': true,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('Détails Erreur ${response.statusCode}: ${response.body}');
        if (response.body.contains('already exists')) {
           return await getInstanceStatus(enterpriseId);
        }
        throw Exception('Erreur création instance: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      return {
        'instanceName': instanceName,
        'qrCode': data['qr']?['base64'] ?? data['qrcode']?['base64'],
        'status': data['instance']?['status'] ?? 'connecting',
      };
    } catch (e) {
      debugPrint('Exception dans connectInstance: $e');
      throw Exception('Erreur connexion Evolution API: $e');
    }
  }

  // Étape 1 bis : Générer un code d'appairage (Pairing Code) pour connexion sur le même téléphone
  static Future<String> getPairingCode(String enterpriseId, String phoneNumber) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      // Nettoyer le numéro (garder uniquement les chiffres)
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      
      final headers = {
        'apikey': AppConfig.evolutionApiKey.trim(),
        'Authorization': 'Bearer ${AppConfig.evolutionApiKey.trim()}',
      };
      
      final response = await http.get(
        Uri.parse('${AppConfig.evolutionApiUrl}/instance/connect/pairingCode/$instanceName?number=$cleanPhone'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Erreur génération code: ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['code'] ?? ''; // Le code à 8 caractères
    } catch (e) {
      throw Exception('Erreur Pairing Code: $e');
    }
  }

  // Étape 1 ter: Vérifier le statut de l'instance
  static Future<Map<String, dynamic>> getInstanceStatus(String enterpriseId) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      
      final headers = {
        'apikey': AppConfig.evolutionApiKey.trim(),
        'Authorization': 'Bearer ${AppConfig.evolutionApiKey.trim()}',
      };
      
      final response = await http.get(
        Uri.parse('${AppConfig.evolutionApiUrl}/instance/connectionState/$instanceName'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return {'status': 'error', 'qrCode': null};
      }

      final data = jsonDecode(response.body);
      // Evolution v2 renvoie souvent {instance: {state: 'open'}}
      String state = data['instance']?['state'] ?? data['status'] ?? 'disconnected';
      if (state == 'open') state = 'connected';
      
      return {
        'status': state,
        'qrCode': data['qrcode']?['base64'] ?? data['qr']?['base64'],
      };
    } catch (e) {
      return {'status': 'error', 'qrCode': null, 'error': e.toString()};
    }
  }

  // Étape 2: Ajouter des messages à la queue Firestore (WriteBatch)
  static Future<void> sendBulkToQueue({
    required String enterpriseId,
    required List<Prospect> prospects,
    required String message,
  }) async {
    final instanceName = _getInstanceName(enterpriseId);
    final batch = _firestore.batch();

    final prospectsWithPhone = prospects.where((p) => 
      p.data['telephone'] != null && p.data['telephone']!.isNotEmpty
    ).toList();

    for (final prospect in prospectsWithPhone) {
      final docRef = _firestore.collection('whatsapp_queue').doc();
      batch.set(docRef, {
        'enterpriseId': enterpriseId,
        'instanceName': instanceName,
        'prospectId': prospect.id,
        'prospectName': prospect.name,
        'phoneNumber': _formatPhoneNumber(prospect.data['telephone']!),
        'message': message,
        'status': 'en_attente',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Formater le numéro de téléphone pour WhatsApp (supprimer les espaces, ajouter + si besoin)
  static String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  // Écouter le statut de la queue pour une entreprise
  static Stream<QuerySnapshot> getQueueStream(String enterpriseId) {
    return _firestore
        .collection('whatsapp_queue')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Envoyer un seul message WhatsApp via Evolution API
  static Future<bool> sendSingleMessage({
    required String enterpriseId,
    required String phone,
    required String message,
  }) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      
      final headers = {
        'Content-Type': 'application/json',
        'apikey': AppConfig.evolutionApiKey.trim(),
        'Authorization': 'Bearer ${AppConfig.evolutionApiKey.trim()}',
      };
      
      final response = await http.post(
        Uri.parse('${AppConfig.evolutionApiUrl}/message/sendText/$instanceName'),
        headers: headers,
        body: jsonEncode({
          'number': _formatPhoneNumber(phone),
          'text': message,
          'delay': 1200,
          'presence': 'composing',
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Erreur envoi message WhatsApp: $e');
      return false;
    }
  }
}
