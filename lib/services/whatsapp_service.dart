import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_config.dart';
import '../models/prospect.dart';

class WhatsAppService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Génère un nom d'instance unique pour chaque entreprise (basé sur son ID)
  static String _getInstanceName(String enterpriseId) {
    return 'enterprise_$enterpriseId';
  }

  // Étape 1: Créer une instance Evolution API et récupérer le QR Code
  static Future<Map<String, dynamic>> connectInstance(String enterpriseId) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      final response = await http.post(
        Uri.parse('${AppConfig.evolutionApiUrl}/instance/create'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConfig.evolutionApiKey,
        },
        body: jsonEncode({
          'instanceName': instanceName,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erreur création instance: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      return {
        'instanceName': instanceName,
        'qrCode': data['qr']?['base64'],
        'status': data['instance']?['status'] ?? 'connecting',
      };
    } catch (e) {
      throw Exception('Erreur connexion Evolution API: $e');
    }
  }

  // Étape 1 bis: Vérifier le statut de l'instance
  static Future<Map<String, dynamic>> getInstanceStatus(String enterpriseId) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      final response = await http.get(
        Uri.parse('${AppConfig.evolutionApiUrl}/instance/connect/$instanceName'),
        headers: {
          'apikey': AppConfig.evolutionApiKey,
        },
      );

      if (response.statusCode != 200) {
        return {'status': 'error', 'qrCode': null};
      }

      final data = jsonDecode(response.body);
      return {
        'status': data['instance']?['status'] ?? 'disconnected',
        'qrCode': data['qr']?['base64'],
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
      final response = await http.post(
        Uri.parse('${AppConfig.evolutionApiUrl}/message/sendText/$instanceName'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConfig.evolutionApiKey,
        },
        body: jsonEncode({
          'number': _formatPhoneNumber(phone),
          'text': message,
          'delay': 1200,
          'presence': 'composing',
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Erreur envoi message WhatsApp: $e');
      return false;
    }
  }
}
