import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/database_service.dart';
import '../../models/enterprise.dart';
import '../../models/prospect.dart';
import '../../theme.dart';

class ProspectFormScreen extends StatefulWidget {
  const ProspectFormScreen({super.key});

  @override
  State<ProspectFormScreen> createState() => _ProspectFormScreenState();
}

class _ProspectFormScreenState extends State<ProspectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  
  // Settings
  bool _autoMode = false;
  bool _isWhatsApp = false;
  final List<Prospect> _sessionProspects = []; // prospects collected in this screen session

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final fields = db.currentEnterprise?.formSettings ?? Enterprise.defaultSettings;
    
    for (var field in fields) {
      if (field.enabled) {
        _controllers[field.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _clearFields() {
    for (var controller in _controllers.values) {
      controller.clear();
    }
    setState(() {
      _isWhatsApp = false;
    });
  }

  Future<void> _saveProspect() async {
    if (!_formKey.currentState!.validate()) return;

    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // Extract data from controllers
    final Map<String, String> prospectData = {};
    _controllers.forEach((key, controller) {
      prospectData[key] = controller.text.trim();
    });

    // Save to DatabaseService
    await db.addProspect(prospectData, isWhatsApp: _isWhatsApp);

    // Keep track of it in local session
    final latestProspect = db.allProspects.last;
    setState(() {
      _sessionProspects.add(latestProspect);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${prospectData['prenom'] ?? ''} ${prospectData['nom'] ?? 'Prospect'} enregistré avec succès !"),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 1),
      ),
    );

    if (_autoMode) {
      // Clear form and stay on screen
      _clearFields();
    } else {
      // Go back
      Navigator.pop(context);
    }
  }

  Future<void> _closeSession() async {
    if (_sessionProspects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enregistrez au moins un prospect avant de clôturer la session."),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final db = Provider.of<DatabaseService>(context, listen: false);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );

    // Try to send report directly via Brevo to the enterprise email
    final sentDirectly = await db.sendReportToEnterprise(_sessionProspects);

    if (context.mounted) {
      Navigator.pop(context); // Close loading indicator
    }

    if (sentDirectly) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Rapport envoyé directement à l'entreprise (${db.currentEnterprise?.email ?? ''}) !"),
            backgroundColor: AppTheme.successColor,
          ),
        );
        setState(() {
          _sessionProspects.clear();
        });
        Navigator.pop(context);
      }
    } else {
      // Fallback: system share
      final csvString = db.generateProspectsCSV(_sessionProspects);
      final tempFile = await db.saveCSVToFile(csvString);

      if (context.mounted) {
        final enterpriseEmail = db.currentEnterprise?.email ?? '';
        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text: 'Rapport de prospection - Force de vente G-CRM.\nEnvoyé par ${db.currentAgent?.name}.\nEmail de destination : $enterpriseEmail',
          subject: 'Fichier de prospection G-CRM',
        );
        
        setState(() {
          _sessionProspects.clear();
        });

        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final fields = db.currentEnterprise?.formSettings.where((x) => x.enabled).toList() ?? 
        Enterprise.defaultSettings.where((x) => x.enabled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prospection Terrain"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top settings & statistics bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.secondaryColor.withOpacity(0.04),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Mode Automatique",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondaryColor),
                      ),
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _autoMode,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (val) {
                            setState(() => _autoMode = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${_sessionProspects.length} collectés",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main input fields form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: fields.map((field) {
                          final controller = _controllers[field.id];
                          if (controller == null) return const SizedBox.shrink();

                          final isPhone = field.id == 'telephone' || field.id == 'numeroWhatsApp';
                          final isEmail = field.id == 'email';
                          final isNom = field.id == 'nom';
                          final isPrenom = field.id == 'prenom';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: TextFormField(
                              controller: controller,
                              keyboardType: isPhone 
                                  ? TextInputType.phone 
                                  : (isEmail ? TextInputType.emailAddress : TextInputType.text),
                              textCapitalization: isNom 
                                  ? TextCapitalization.characters 
                                  : (isPrenom ? TextCapitalization.words : TextCapitalization.none),
                              inputFormatters: [
                                if (isNom) UpperCaseTextFormatter(),
                                if (isPrenom) TitleCaseTextFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: field.label + (field.required ? ' *' : ' (Optionnel)'),
                                prefixIcon: Icon(_getFieldIcon(field.id)),
                              ),
                              validator: (value) {
                                if (field.required && (value == null || value.trim().isEmpty)) {
                                  return "Le champ '${field.label}' est obligatoire";
                                }
                                if (isEmail && value != null && value.trim().isNotEmpty) {
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                    return "Format email incorrect";
                                  }
                                }
                                return null;
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // WhatsApp Checkbox: only show if the separate WhatsApp field is not enabled
                    if (db.currentEnterprise?.formSettings.firstWhere((f) => f.id == 'numeroWhatsApp', orElse: () => ProspectFieldSetting(id: 'numeroWhatsApp', label: '', required: false, enabled: false)).enabled == false)
                      CheckboxListTile(
                        title: const Text(
                          "C'est un numéro WhatsApp",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          "Cochez si vous savez que ce prospect utilise WhatsApp",
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _isWhatsApp,
                        activeColor: Colors.green,
                        secondary: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setState(() => _isWhatsApp = val ?? false);
                        },
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveProspect,
                      icon: const Icon(Icons.check),
                      label: Text(_autoMode ? "Enregistrer & Suivant" : "Enregistrer le prospect"),
                    ),
                    const SizedBox(height: 12),
                    if (_sessionProspects.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _closeSession,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successColor,
                          side: const BorderSide(color: AppTheme.successColor),
                        ),
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text("Clôturer la session & Envoyer"),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFieldIcon(String fieldId) {
    switch (fieldId) {
      case 'nom':
      case 'prenom':
        return Icons.person_outline;
      case 'telephone':
        return Icons.phone_outlined;
      case 'numeroWhatsApp':
        return Icons.chat_bubble_outline;
      case 'email':
        return Icons.mail_outline;
      case 'entreprise':
        return Icons.business_outlined;
      case 'note':
        return Icons.description_outlined;
      default:
        return Icons.edit_note_outlined;
    }
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class TitleCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final String text = newValue.text;
    final List<String> words = text.split(' ');
    final List<String> capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();

    final String result = capitalizedWords.join(' ');

    return TextEditingValue(
      text: result,
      selection: newValue.selection,
    );
  }
}
