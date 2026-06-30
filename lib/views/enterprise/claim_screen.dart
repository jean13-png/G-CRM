import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../services/database_service.dart';
import '../../app_config.dart';
import '../../theme.dart';

class ClaimScreen extends StatefulWidget {
  const ClaimScreen({super.key});

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _refController = TextEditingController();
  bool _isLoading = false;
  String? _resultMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _resultMessage = null;
    });

    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final enterprise = db.currentEnterprise;
      
      if (enterprise == null) {
        throw Exception("Entreprise non trouvée.");
      }

      final url = Uri.parse('${AppConfig.paymentServiceUrl}/claim-payment');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': AppConfig.paymentInternalApiKey,
        },
        body: json.encode({
          'enterpriseId': enterprise.id,
          'transactionId': _refController.text.trim(),
        }),
      );

      final body = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _isSuccess = true;
          _resultMessage = body['message'] ?? 'Réclamation validée avec succès.';
        });
        _refController.clear();
      } else {
        setState(() {
          _isSuccess = false;
          _resultMessage = body['error'] ?? 'Une erreur est survenue (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _resultMessage = 'Erreur réseau ou serveur: \${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Réclamation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.support_agent, size: 64, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            const Text(
              'Un problème avec votre paiement ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Si vous avez été débité mais que votre plan n\'est pas actif, veuillez entrer la référence de la transaction (ID FedaPay) que vous avez reçue ou copiée.',
              style: TextStyle(fontSize: 14, color: AppTheme.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            if (_resultMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  border: Border.all(color: _isSuccess ? Colors.green : Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error,
                      color: _isSuccess ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _resultMessage!,
                        style: TextStyle(
                          color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Form(
              key: _formKey,
              child: TextFormField(
                controller: _refController,
                decoration: InputDecoration(
                  labelText: 'Référence Transaction (ID)',
                  hintText: 'Ex: 111665518',
                  prefixIcon: const Icon(Icons.receipt_long),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Veuillez entrer une référence.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitClaim,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Soumettre la réclamation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: Colors.orange.shade300, width: 4)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conditions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• La réclamation doit être faite dans les 72 heures suivant la transaction.\n'
                    '• Seules les transactions approuvées par l\'opérateur sont validées.\n'
                    '• En cas de succès, la facture vous sera envoyée par email.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
