import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';
import '../../models/prospect.dart';
import '../../models/enterprise.dart';
import '../../theme.dart';

class TaskCallScreen extends StatefulWidget {
  final List<Prospect> prospectsToCall;
  final String title;

  const TaskCallScreen({
    super.key,
    required this.prospectsToCall,
    required this.title,
  });

  @override
  State<TaskCallScreen> createState() => _TaskCallScreenState();
}

class _TaskCallScreenState extends State<TaskCallScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _callLaunched = false;
  bool _dialogOpen = false;

  // Controllers for verdict
  final _noteController = TextEditingController();

  // Selected template for messaging
  MessageTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set first template as default if available
    final db = Provider.of<DatabaseService>(context, listen: false);
    if (db.currentEnterprise?.messageTemplates.isNotEmpty ?? false) {
      _selectedTemplate = db.currentEnterprise!.messageTemplates.first;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noteController.dispose();
    super.dispose();
  }

  // Detect when the agent returns to the application after an external action (Call, WhatsApp, SMS)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _callLaunched && !_dialogOpen) {
      _callLaunched = false;
      // Small delay to allow the frame to render before showing bottom sheet
      Future.delayed(const Duration(milliseconds: 500), () {
        _showVerdictBottomSheet();
      });
    }
  }

  // Launch direct phone call
  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri.parse("tel:$phoneNumber");
    setState(() {
      _callLaunched = true;
    });
    try {
      final success = await launchUrl(url);
      if (!success) throw 'Could not launch $url';
    } catch (e) {
      setState(() {
        _callLaunched = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible de lancer l'appel direct."),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Launch WhatsApp Chat
  Future<void> _sendWhatsApp(String phoneNumber) async {
    final message = _selectedTemplate != null 
        ? _selectedTemplate!.content 
        : "Bonjour, je vous contacte suite à notre prospection de terrain.";
    
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    
    setState(() => _callLaunched = true);
    try {
      final success = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!success) throw 'Could not launch $url';
    } catch (e) {
      setState(() => _callLaunched = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'ouvrir WhatsApp. Vérifiez que l'application est installée."),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Launch SMS
  Future<void> _sendSMS(String phoneNumber) async {
    final message = _selectedTemplate != null 
        ? _selectedTemplate!.content 
        : "Bonjour, je vous contacte pour faire suite à notre échange.";
        
    final Uri url = Uri.parse("sms:$phoneNumber?body=${Uri.encodeComponent(message)}");
    setState(() => _callLaunched = true);
    try {
      final success = await launchUrl(url);
      if (!success) throw 'Could not launch $url';
    } catch (e) {
      setState(() => _callLaunched = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'ouvrir l'application SMS."),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Send automated follow-up email with quota verification
  Future<void> _sendEmail(String prospectId, String email) async {
    final db = Provider.of<DatabaseService>(context, listen: false);

    // Show a loading feedback dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );

    final success = await db.sendEmailToProspect(
      prospectId: prospectId,
      subject: "Suivi G-CRM",
      content: "Bonjour,\n\nNous faisons suite à notre échange de prospection.\n\nCordialement.",
    );

    if (context.mounted) {
      Navigator.pop(context); // Close loading indicator
    }

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Email envoyé avec succès à $email !"),
            backgroundColor: AppTheme.successColor,
          ),
        );
        setState(() {
          _callLaunched = true;
        });
        _showVerdictBottomSheet(); // Prompt for call verdict immediately
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Envoi bloqué : Limite de 50 emails par jour atteinte par votre entreprise."),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Show verdict panel
  void _showVerdictBottomSheet() {
    if (_currentIndex >= widget.prospectsToCall.length) return;
    
    final prospect = widget.prospectsToCall[_currentIndex];
    setState(() {
      _dialogOpen = true;
    });

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Verdict pour ${prospect.name}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              const Text(
                "Quel est le résultat de votre échange ?",
                style: TextStyle(color: AppTheme.textLight, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Option buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _submitVerdict('ok'),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text("OK / Intéressé", style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _submitVerdict('non'),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text("NON / Refusé", style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _submitVerdict('unreachable'),
                icon: const Icon(Icons.phone_missed, size: 18),
                label: const Text("Indisponible / Inaccessible", style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 16),
              
              // Comment / Note
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: "Commentaire / Note (Optionnel)",
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
              ),
              const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      setState(() {
        _dialogOpen = false;
      });
    });
  }

  void _submitVerdict(String verdict) async {
    final prospect = widget.prospectsToCall[_currentIndex];
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // Save verdict to database
    await db.updateProspectStatus(
      prospect.id,
      verdict,
      note: _noteController.text.trim(),
    );

    // Reset UI state
    _noteController.clear();
    Navigator.pop(context); // Close bottom sheet

    // Wait a brief moment, then auto-advance to next prospect or finish
    Future.delayed(const Duration(milliseconds: 300), () {
      if (context.mounted) {
        setState(() {
          _currentIndex++;
        });

        if (_currentIndex >= widget.prospectsToCall.length) {
          // Task completed!
          _showCompletionDialog();
        }
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Félicitations !"),
          content: const Text("Tous les appels de cette liste ont été traités."),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to Dashboard
              },
              child: const Text("Retour au Dashboard"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.prospectsToCall.length;
    final isFinished = _currentIndex >= total;

    if (isFinished) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final prospect = widget.prospectsToCall[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top indicator of progression
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Progression des appels",
                      style: TextStyle(color: AppTheme.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${_currentIndex + 1} / $total",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / total,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                const SizedBox(height: 32),
                
                // Prospect Card details
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          child: const Icon(Icons.person, size: 40, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          prospect.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.secondaryColor),
                          textAlign: TextAlign.center,
                        ),
                        if (prospect.data['entreprise'] != null && prospect.data['entreprise']!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            prospect.data['entreprise']!,
                            style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // Contact info
                        _buildContactDetail(Icons.phone, prospect.phone),
                        if (prospect.email.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildContactDetail(Icons.email, prospect.email),
                        ],
                        if (prospect.data['note'] != null && prospect.data['note']!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.description, size: 16, color: AppTheme.textLight),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    prospect.data['note']!,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textDark, height: 1.3),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Template Selector
                if (Provider.of<DatabaseService>(context).currentEnterprise?.messageTemplates.isNotEmpty ?? false) ...[
                  const Text(
                    "Modèle de message",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<MessageTemplate>(
                      isExpanded: true,
                      value: _selectedTemplate,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: Provider.of<DatabaseService>(context).currentEnterprise!.messageTemplates.map((t) {
                        return DropdownMenuItem<MessageTemplate>(
                          value: t,
                          child: Text(t.title, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedTemplate = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Quick launch buttons
                const Text(
                  "Contacter via",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallActionCircle(
                      icon: Icons.phone,
                      color: AppTheme.primaryColor,
                      label: "Appel",
                      onTap: () => _makeCall(prospect.phone),
                    ),
                    _buildCallActionCircle(
                      icon: Icons.chat_bubble_outline,
                      color: Colors.green,
                      label: "WhatsApp",
                      onTap: () => _sendWhatsApp(prospect.phone),
                    ),
                    _buildCallActionCircle(
                      icon: Icons.sms_outlined,
                      color: Colors.blue,
                      label: "SMS",
                      onTap: () => _sendSMS(prospect.phone),
                    ),
                    if (prospect.email.isNotEmpty)
                      _buildCallActionCircle(
                        icon: Icons.email_outlined,
                        color: AppTheme.secondaryColor,
                        label: "Email",
                        onTap: () => _sendEmail(prospect.id, prospect.email),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Skip option
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex++;
                    });
                    if (_currentIndex >= widget.prospectsToCall.length) {
                      _showCompletionDialog();
                    }
                  },
                  child: const Text(
                    "Passer ce contact pour le moment",
                    style: TextStyle(color: AppTheme.textLight),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactDetail(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppTheme.textLight),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: AppTheme.textDark, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildCallActionCircle({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withOpacity(0.1),
          child: IconButton(
            icon: Icon(icon, color: color, size: 24),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textLight),
        ),
      ],
    );
  }
}
