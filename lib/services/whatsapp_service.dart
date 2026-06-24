import 'dart:async';
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

  static String _getBaseUrl() {
    String baseUrl = AppConfig.evolutionApiUrl.trim();
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    return baseUrl;
  }

  static Map<String, String> _headers({bool json = false}) {
    final headers = {'apikey': AppConfig.evolutionApiKey.trim()};
    if (json) headers['Content-Type'] = 'application/json';
    return headers;
  }

  static String? _extractQrCode(Map<String, dynamic> data) {
    final raw = data['base64'] ??
        data['qrcode']?['base64'] ??
        data['qr']?['base64'];
    if (raw == null || raw.toString().isEmpty) return null;
    return raw.toString();
  }

  // Récupère le QR Code via /instance/connect (endpoint dédié Evolution v2)
  static Future<String?> fetchQrCode(String enterpriseId) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      final response = await http.get(
        Uri.parse('${_getBaseUrl()}/instance/connect/$instanceName'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('fetchQrCode ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _extractQrCode(data);
    } catch (e) {
      debugPrint('fetchQrCode error: $e');
      return null;
    }
  }

  // Statut + QR combinés (utilisé par l'UI)
  static Future<Map<String, dynamic>> getConnectionInfo(String enterpriseId) async {
    final status = await getInstanceStatus(enterpriseId);
    if (status['status'] == 'connected') return status;

    final qrCode = await fetchQrCode(enterpriseId);
    return {
      'status': status['status'],
      'qrCode': qrCode ?? status['qrCode'],
    };
  }

  static const Duration _deleteTimeout = Duration(seconds: 90);
  static const Duration _createTimeout = Duration(seconds: 90);
  static const Duration _fetchTimeout = Duration(seconds: 30);

  // Supprime l'instance Evolution API (reset complet)
  static Future<void> deleteInstance(String enterpriseId) async {
    final instanceName = _getInstanceName(enterpriseId);
    Object? lastError;

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        debugPrint('deleteInstance $instanceName (tentative $attempt/2)...');
        final response = await http.delete(
          Uri.parse('${_getBaseUrl()}/instance/delete/$instanceName'),
          headers: _headers(),
        ).timeout(_deleteTimeout);

        if (response.statusCode == 200 || response.statusCode == 404) return;
        throw Exception('Suppression impossible (${response.statusCode}): ${response.body}');
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('deleteInstance timeout (tentative $attempt): $e');
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 5));
        }
      } catch (e) {
        lastError = e;
        rethrow;
      }
    }

    throw Exception(
      'Délai dépassé. Veuillez réessayer dans une minute.',
    );
  }

  static Future<bool> instanceExists(String enterpriseId) async {
    final instanceName = _getInstanceName(enterpriseId);
    final response = await http.get(
      Uri.parse('${_getBaseUrl()}/instance/fetchInstances?instanceName=$instanceName'),
      headers: _headers(),
    ).timeout(_fetchTimeout);

    if (response.statusCode != 200) return false;
    final List instances = jsonDecode(response.body);
    return instances.any((inst) =>
        inst['instanceName'] == instanceName || inst['name'] == instanceName);
  }

  static Future<Map<String, dynamic>> _createInstance(
    String enterpriseId, {
    bool qrcode = true,
    String? phoneNumber,
  }) async {
    final instanceName = _getInstanceName(enterpriseId);
    final payload = <String, dynamic>{
      'instanceName': instanceName,
      'qrcode': qrcode,
      'integration': 'WHATSAPP-BAILEYS',
    };
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      payload['number'] = phoneNumber;
    }
    final response = await http.post(
      Uri.parse('${_getBaseUrl()}/instance/create'),
      headers: _headers(json: true),
      body: jsonEncode(payload),
    ).timeout(_createTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur création instance: ${response.statusCode} — ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Demande un code de couplage (crée l'instance + appelle /connect?number=)
  static Future<String> requestPairingCode(String enterpriseId, String phoneNumber) async {
    final instanceName = _getInstanceName(enterpriseId);
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    try {
      // 1. Reset propre de l'instance pour éviter les conflits de session
      try {
        await deleteInstance(enterpriseId);
      } catch (_) {}

      // 2. Création de l'instance SANS le numéro de téléphone
      // Le numéro ne sera pas passé ici pour ne pas générer un code trop tôt
      final createData = await _createInstance(
        enterpriseId,
        qrcode: false,
        phoneNumber: null, // IMPORTANT: pas de numéro ici
      );

      // 3. Attendre un peu que Baileys initialise la session
      debugPrint('Instance créée, attente 3s pour initialisation...');
      await Future.delayed(const Duration(seconds: 3));

      // 4. UN SEUL ET UNIQUE APPEL à /connect?number=
      // C'est cet appel qui va générer LE CODE UNIQUE et LA NOTIFICATION UNIQUE
      return await _fetchPairingCodeFromConnect(instanceName, cleanPhone);

    } catch (e) {
      debugPrint('❌ requestPairingCode error: $e');
      rethrow;
    }
  }

  // Relance une seule demande de couplage (pour recevoir la notif WhatsApp)
  static Future<String?> resendPairingNotification(String enterpriseId, String phoneNumber) async {
    final instanceName = _getInstanceName(enterpriseId);
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // IMPORTANT: Cet appel génère un NOUVEAU code sur le serveur.
    final response = await http.get(
      Uri.parse('${_getBaseUrl()}/instance/connect/$instanceName')
          .replace(queryParameters: {'number': cleanPhone}),
      headers: _headers(),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['pairingCode']?.toString() ?? 
             data['code']?.toString() ?? 
             data['qrcode']?['pairingCode']?.toString();
    }
    
    return null;
  }

  static Future<String> _fetchPairingCodeFromConnect(
    String instanceName,
    String cleanPhone,
  ) async {
    final uri = Uri.parse('${_getBaseUrl()}/instance/connect/$instanceName')
        .replace(queryParameters: {'number': cleanPhone});

    debugPrint('Appel unique à /connect pour pairing code: $uri');
    
    final response = await http.get(uri, headers: _headers())
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Chercher le code dans tous les champs possibles d'Evolution API v2
      final pairingCode = data['pairingCode']?.toString() ?? 
                         data['code']?.toString() ?? 
                         data['qrcode']?['pairingCode']?.toString();
                         
      if (pairingCode != null && pairingCode.isNotEmpty) {
        debugPrint('Pairing code reçu: $pairingCode');
        return pairingCode;
      }
      
      debugPrint('Réponse 200 mais aucun code trouvé: ${response.body}');
    } else {
      debugPrint('Erreur /connect (${response.statusCode}): ${response.body}');
    }

    throw Exception('Le serveur n\'a pas généré de code. Veuillez réessayer.');
  }

  static Future<Map<String, dynamic>> connectInstance(
    String enterpriseId, {
    bool forceRecreate = false,
  }) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      debugPrint('>>> Instance: $instanceName (forceRecreate: $forceRecreate)');

      if (!forceRecreate && await instanceExists(enterpriseId)) {
        debugPrint('L\'instance $instanceName existe déjà.');
        final info = await getConnectionInfo(enterpriseId);
        if (info['status'] == 'connected' || info['qrCode'] != null) {
          return info;
        }
      }

      if (await instanceExists(enterpriseId)) {
        debugPrint('Suppression instance $instanceName avant recréation...');
        try {
          await deleteInstance(enterpriseId);
        } catch (e) {
          debugPrint('deleteInstance: $e');
        }
      }

      final data = await _createInstance(enterpriseId, qrcode: true);
      var qrCode = _extractQrCode(data);
      qrCode ??= await fetchQrCode(enterpriseId);

      return {
        'instanceName': instanceName,
        'qrCode': qrCode,
        'status': data['instance']?['status'] ?? 'connecting',
        'serverIssue': qrCode == null,
      };
    } catch (e) {
      debugPrint('Exception dans connectInstance: $e');
      throw Exception('Erreur connexion WhatsApp. Réessayez.');
    }
  }

  // Étape 1 ter: Vérifier le statut de l'instance
  static Future<Map<String, dynamic>> getInstanceStatus(String enterpriseId) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      
      final headers = _headers();
      
      final response = await http.get(
        Uri.parse('${_getBaseUrl()}/instance/connectionState/$instanceName'),
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
        'qrCode': null,
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

  // Formater le numéro de téléphone pour WhatsApp
  static String _formatPhoneNumber(String phone) {
    // 1. Garder uniquement les chiffres
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 2. Si ça commence par 00, on remplace par rien (on suppose que c'est un préfixe international)
    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }

    // Pour le Bénin (nouveau plan numérique), le 0 initial est souvent obligatoire
    // On garde le numéro tel qu'il est (après nettoyage des caractères spéciaux)
    
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
  static Future<Map<String, dynamic>> sendSingleMessage({
    required String enterpriseId,
    required String phone,
    required String message,
  }) async {
    try {
      final instanceName = _getInstanceName(enterpriseId);
      final headers = _headers(json: true);
      
      final formattedPhone = _formatPhoneNumber(phone);
      debugPrint('Tentative d\'envoi WhatsApp vers $formattedPhone');

      final response = await http.post(
        Uri.parse('${_getBaseUrl()}/message/sendText/$instanceName'),
        headers: headers,
        body: jsonEncode({
          'number': formattedPhone,
          'text': message,
          'delay': 1200,
          'presence': 'composing',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('Erreur envoi WhatsApp (${response.statusCode}): ${response.body}');
        
        // Cas spécifique du numéro qui n'existe pas
        if (response.statusCode == 400 && response.body.contains('"exists":false')) {
          return {
            'success': false,
            'error': 'Le numéro n\'est pas enregistré sur WhatsApp.',
            'details': data
          };
        }

        return {
          'success': false, 
          'error': 'Erreur serveur (${response.statusCode})',
          'details': data
        };
      }
      
      return {'success': true};
    } catch (e) {
      debugPrint('Erreur envoi message WhatsApp: $e');
      return {
        'success': false, 
        'error': e is TimeoutException ? 'Délai d\'attente dépassé (Serveur lent)' : 'Erreur inconnue',
      };
    }
  }
}
