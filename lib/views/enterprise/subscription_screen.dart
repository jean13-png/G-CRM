import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';
import '../../models/enterprise.dart';
import '../../app_config.dart';
import '../../theme.dart';
import 'claim_screen.dart';

// ============================================================
//  Modèle des plans tarifaires (synchronisé avec SAAS_PRICING_SPEC.md)
// ============================================================
class PricingPlan {
  final String id;
  final String name;
  final String price;
  final String priceLabel;
  final Color color;
  final IconData icon;
  final List<String> features;
  final int appelsManuels;
  final int smsManuels;
  final int whatsappManuels;
  final int prospects;
  final int agents;
  final int fedapayAmount; // Montant en FCFA

  const PricingPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.priceLabel,
    required this.color,
    required this.icon,
    required this.features,
    required this.appelsManuels,
    required this.smsManuels,
    required this.whatsappManuels,
    required this.prospects,
    required this.agents,
    required this.fedapayAmount,
  });
}

const List<PricingPlan> _kPlans = [
  PricingPlan(
    id: 'DISCOVERY',
    name: 'Discovery',
    price: 'Gratuit',
    priceLabel: 'Pour démarrer',
    color: AppTheme.secondaryColor,
    icon: Icons.explore_outlined,
    features: [
      '250 appels manuels/mois',
      '250 SMS manuels/mois',
      '100 WhatsApp manuels/mois',
      '50 prospects max',
      '2 agents max',
    ],
    appelsManuels: 250,
    smsManuels: 250,
    whatsappManuels: 100,
    prospects: 50,
    agents: 2,
    fedapayAmount: 0,
  ),
  PricingPlan(
    id: 'STARTER',
    name: 'Starter',
    price: '2 500 FCFA',
    priceLabel: '/mois',
    color: AppTheme.primaryColor,
    icon: Icons.rocket_launch_outlined,
    features: [
      '600 appels manuels/mois',
      '600 SMS manuels/mois',
      '400 WhatsApp manuels/mois',
      '800 prospects max',
      '5 agents max',
      'Support par email',
    ],
    appelsManuels: 600,
    smsManuels: 600,
    whatsappManuels: 400,
    prospects: 800,
    agents: 5,
    fedapayAmount: 2500,
  ),
  PricingPlan(
    id: 'PRO',
    name: 'Pro',
    price: '5 000 FCFA',
    priceLabel: '/mois',
    color: AppTheme.primaryColor,
    icon: Icons.workspace_premium_outlined,
    features: [
      '3 500 appels manuels/mois',
      '3 500 SMS manuels/mois',
      '1 800 WhatsApp manuels/mois',
      '5 000 prospects max',
      '20 agents max',
      'Support prioritaire',
      'Export CSV avancé',
    ],
    appelsManuels: 3500,
    smsManuels: 3500,
    whatsappManuels: 1800,
    prospects: 5000,
    agents: 20,
    fedapayAmount: 5000,
  ),
  PricingPlan(
    id: 'BUSINESS',
    name: 'Business',
    price: '10 000 FCFA',
    priceLabel: '/mois',
    color: AppTheme.secondaryColor,
    icon: Icons.business_center_outlined,
    features: [
      '10 000 appels manuels/mois',
      '10 000 SMS manuels/mois',
      '5 000 WhatsApp manuels/mois',
      '20 000 prospects max',
      '100 agents max',
      'Support dédié 24/7',
      'API personnalisée',
      'Tableau de bord avancé',
    ],
    appelsManuels: 10000,
    smsManuels: 10000,
    whatsappManuels: 5000,
    prospects: 20000,
    agents: 100,
    fedapayAmount: 10000,
  ),
];

// ============================================================
//  Écran principal des abonnements
// ============================================================
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;

  // URL du microservice de paiement (Render.com)
  static const String _paymentServiceUrl = String.fromEnvironment(
    'PAYMENT_SERVICE_URL',
    defaultValue: 'https://g-crm-payment-service.onrender.com',
  );
  static const String _paymentApiKey = String.fromEnvironment(
    'PAYMENT_INTERNAL_API_KEY',
    defaultValue: 'gcrm_pay_internal_2026',
  );

  Future<void> _initiatePayment(PricingPlan plan, String enterpriseId) async {
    if (plan.fedapayAmount == 0) return;

    setState(() => _isLoading = true);

    try {
      // Appel au microservice payment-service (Render.com — gratuit, pas Firebase Blaze)
      final response = await http
          .post(
            Uri.parse('$_paymentServiceUrl/create-transaction'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': _paymentApiKey,
            },
            body: json.encode({
              'enterpriseId': enterpriseId,
              'planId': plan.id,
              'amount': plan.fedapayAmount,
              'planName': plan.name,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final checkoutUrl = data['checkoutUrl'] as String?;

        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          final uri = Uri.parse(checkoutUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (mounted) _showPaymentPendingDialog(plan);
          } else {
            throw Exception('Impossible d\'ouvrir la page de paiement');
          }
        } else {
          throw Exception('Lien de paiement introuvable dans la réponse');
        }
      } else {
        final errBody = json.decode(response.body) as Map<String, dynamic>?;
        final errMsg = errBody?['error'] ?? 'Erreur serveur ${response.statusCode}';
        final errDetail = errBody?['detail'] ?? '';
        throw Exception('$errMsg\n$errDetail');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPaymentPendingDialog(PricingPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.schedule, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text('Paiement en attente'),
          ],
        ),
        content: Text(
          'Votre paiement pour le plan ${plan.name} est en cours de traitement.\n\n'
          'Une fois confirmé, votre compte sera automatiquement mis à niveau.\n\n'
          'Référence: ${DateTime.now().millisecondsSinceEpoch}',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _showPlanDetails(PricingPlan plan, String currentPlanId, String enterpriseId) {
    final isCurrentPlan = plan.id == currentPlanId;
    final isDowngrade = _kPlans.indexWhere((p) => p.id == plan.id) <
        _kPlans.indexWhere((p) => p.id == currentPlanId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: plan.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(plan.icon, color: plan.color, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plan ${plan.name}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: plan.color,
                            ),
                          ),
                          Text(
                            '${plan.price} ${plan.priceLabel}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Ce plan inclut :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ...plan.features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: plan.color, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    )),
                const SizedBox(height: 24),
                if (isCurrentPlan)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.successColor),
                        SizedBox(width: 8),
                        Text(
                          'Plan actif',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (plan.fedapayAmount == 0)
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Plan gratuit (dégradation)'),
                  )
                else if (isDowngrade)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pour réduire votre plan, contactez le support G-CRM.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contacter le support'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _initiatePayment(plan, enterpriseId);
                          },
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.credit_card),
                    label: Text('Passer au plan ${plan.name}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Paiement sécurisé via FedaPay',
                    style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final enterprise = db.currentEnterprise;
    if (enterprise == null) return const SizedBox.shrink();

    final currentPlanId = enterprise.planId;
    final currentPlan = _kPlans.firstWhere(
      (p) => p.id == currentPlanId,
      orElse: () => _kPlans.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Abonnements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent),
            tooltip: 'Réclamation',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClaimScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carte plan actuel
            _buildCurrentPlanCard(enterprise, currentPlan),
            const SizedBox(height: 24),

            // Titre section plans
            const Text(
              'Choisir un plan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tous les plans se renouvellent chaque mois. Paiement sécurisé via FedaPay.',
              style: TextStyle(fontSize: 12, color: AppTheme.textLight),
            ),
            const SizedBox(height: 16),

            // Grille des plans
            ..._kPlans.map((plan) => _buildPlanCard(
                  plan,
                  currentPlanId,
                  enterprise.id,
                )),

            const SizedBox(height: 24),

            // Section sécurité paiement
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.grey.shade500, size: 32),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paiement 100% sécurisé',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Vos transactions sont protégées par FedaPay, plateforme de paiement certifiée en Afrique de l\'Ouest.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textLight, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(Enterprise enterprise, PricingPlan plan) {
    // Calcul des quotas utilisés
    final Map<String, _QuotaInfo> quotas = {
      'Appels': _QuotaInfo(
        used: plan.appelsManuels - enterprise.appelsManuelsRestants,
        total: plan.appelsManuels,
      ),
      'SMS': _QuotaInfo(
        used: plan.smsManuels - enterprise.smsManuelsRestants,
        total: plan.smsManuels,
      ),
      'WhatsApp': _QuotaInfo(
        used: plan.whatsappManuels - enterprise.whatsappManuelsRestants,
        total: plan.whatsappManuels,
      ),
    };

    return Card(
      color: plan.color,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(plan.icon, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Plan ${plan.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Actif',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (enterprise.subscriptionEndDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Expire le ${enterprise.subscriptionEndDate!.day}/${enterprise.subscriptionEndDate!.month}/${enterprise.subscriptionEndDate!.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Utilisation ce mois',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...quotas.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Text(
                            '${e.value.used} / ${e.value.total}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: e.value.total > 0 ? (e.value.used / e.value.total).clamp(0.0, 1.0) : 0,
                          minHeight: 5,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            e.value.total > 0 && e.value.used / e.value.total > 0.9
                                ? Colors.red.shade200
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(PricingPlan plan, String currentPlanId, String enterpriseId) {
    final isCurrentPlan = plan.id == currentPlanId;
    final currentPlanIndex = _kPlans.indexWhere((p) => p.id == currentPlanId);
    final thisPlanIndex = _kPlans.indexWhere((p) => p.id == plan.id);
    final isUpgrade = thisPlanIndex > currentPlanIndex;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCurrentPlan ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrentPlan ? plan.color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showPlanDetails(plan, currentPlanId, enterpriseId),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: plan.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(plan.icon, color: plan.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: plan.color,
                          ),
                        ),
                        if (isCurrentPlan) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: plan.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Actuel',
                              style: TextStyle(
                                color: plan.color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${plan.appelsManuels} appels • ${plan.smsManuels} SMS • ${plan.whatsappManuels} WA',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.fedapayAmount == 0 ? 'Gratuit' : plan.price,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  if (isUpgrade && !isCurrentPlan)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Text(
                        'Mise à niveau',
                        style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotaInfo {
  final int used;
  final int total;
  const _QuotaInfo({required this.used, required this.total});
}
