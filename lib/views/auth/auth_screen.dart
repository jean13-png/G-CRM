import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../enterprise/enterprise_dashboard.dart';
import '../agent/agent_dashboard.dart';

class AuthScreen extends StatefulWidget {
  final String role; // 'enterprise' or 'agent'

  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Text Editing Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 2 tabs for Enterprise (Login / Register), 1 tab for Agent (Login only)
    _tabController = TabController(length: widget.role == 'enterprise' ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    final success = await db.signIn(
      _emailController.text,
      _passwordController.text,
      widget.role,
    );

    setState(() => _isLoading = false);

    if (context.mounted) {
      if (success) {
        // Redirect to appropriate dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => widget.role == 'enterprise'
                ? const EnterpriseDashboard()
                : const AgentDashboard(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Identifiants incorrects. Veuillez réessayer."),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);

    final success = await db.signUpEnterprise(
      _regNameController.text,
      _regEmailController.text,
      _regPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (context.mounted) {
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const EnterpriseDashboard(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cet email est déjà associé à une entreprise."),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnterprise = widget.role == 'enterprise';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnterprise ? 'Espace Entreprise' : 'Espace Agent'),
        bottom: isEnterprise
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryColor,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.textLight,
                tabs: const [
                  Tab(text: 'Se connecter'),
                  Tab(text: "S'inscrire"),
                ],
              )
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginForm(),
                  if (isEnterprise) _buildRegisterForm(),
                ],
              ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.lock_open,
              size: 64,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              widget.role == 'enterprise'
                  ? 'Gérez votre force de vente'
                  : 'Commencez votre prospection',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.role == 'enterprise'
                  ? 'Connectez-vous pour configurer et suivre vos équipes.'
                  : 'Connectez-vous avec les identifiants créés par votre entreprise.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textLight,
              ),
            ),
            const SizedBox(height: 32),
            
            // Email Input
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Adresse Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir votre email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Veuillez entrer un email valide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Password Input
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir votre mot de passe';
                }
                if (value.length < 6) {
                  return 'Le mot de passe doit faire au moins 6 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            
            // Submit Button
            ElevatedButton(
              onPressed: _handleLogin,
              child: const Text('Se Connecter'),
            ),
            const SizedBox(height: 16),
            
            // Back Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Retour au choix de profil',
                style: TextStyle(color: AppTheme.textLight),
              ),
            ),
            const SizedBox(height: 24),
            
            // Offline demo tip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Mode local actif : utilisez 'direction@supelite.com' (Entreprise) ou 'koffi@supelite.com' (Agent) avec le mot de passe 'password' pour tester directement hors-ligne.",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryDark,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Enregistrez votre Entreprise',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Créez un compte pour commencer à structurer et suivre vos prospections sur le terrain.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textLight,
              ),
            ),
            const SizedBox(height: 24),
            
            // Company Name
            TextFormField(
              controller: _regNameController,
              decoration: const InputDecoration(
                labelText: "Nom de l'entreprise",
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Veuillez entrer le nom de l'entreprise";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Email Address
            TextFormField(
              controller: _regEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Professionnel',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir votre email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Veuillez entrer un email valide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Password
            TextFormField(
              controller: _regPasswordController,
              obscureText: _obscurePassword,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir votre mot de passe';
                }
                if (value.length < 6) {
                  return 'Le mot de passe doit faire au moins 6 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Confirm Password
            TextFormField(
              controller: _regConfirmPasswordController,
              obscureText: _obscurePassword,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: Icon(Icons.lock_clock_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez confirmer votre mot de passe';
                }
                if (value != _regPasswordController.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            
            // Register Button
            ElevatedButton(
              onPressed: _handleRegister,
              child: const Text("Créer l'Espace Entreprise"),
            ),
          ],
        ),
      ),
    );
  }
}
