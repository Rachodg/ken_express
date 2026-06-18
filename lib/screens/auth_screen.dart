// ══════════════════════════════════════════════════════════════
// lib/screens/auth_screen.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kenexpress_logo.dart'; // ← IMPORT du vrai logo (remplace l'ancienne classe locale)

// ── AJOUT : normalise un numéro de téléphone pour qu'il serve de clé stable ──
// "+226 70 00 00 00", "00226 70000000" et "70000000" donnent tous "70000000".
String _normalizePhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00226')) {
    digits = digits.substring(5);
  } else if (digits.startsWith('226') && digits.length > 8) {
    digits = digits.substring(3);
  }
  return digits;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

// ─────────────────────────────────────────────
// ÉTAT PRINCIPAL
// ─────────────────────────────────────────────
class _AuthScreenState extends State<AuthScreen> {
  String _page = 'login'; // 'login' | 'role' | 'register_client' | 'register_vendeur'
  String _role = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPage(),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case 'role':
        return RoleSelectionScreen(
          onSelectClient: () => setState(() { _role = 'client'; _page = 'register_client'; }),
          onSelectVendeur: () => setState(() { _role = 'vendeur'; _page = 'register_vendeur'; }),
          onBack: () => setState(() => _page = 'login'),
        );
      case 'register_client':
      case 'register_vendeur':
        return RegisterForm(
          role: _role,
          onSwitchToLogin: () => setState(() => _page = 'login'),
        );
      default:
        return LoginForm(
          onSwitchToRegister: () => setState(() => _page = 'role'),
        );
    }
  }
}

// ─────────────────────────────────────────────
// ARRIÈRE-PLAN DÉGRADÉ (réutilisable)
// ─────────────────────────────────────────────
class _GradientBackground extends StatelessWidget {
  final Widget child;
  final bool isVendeur;
  const _GradientBackground({required this.child, this.isVendeur = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.38, 1.0],
          colors: isVendeur
              ? [
            const Color(0xFFFF8C00),
            const Color(0xFFFFA726),
            const Color(0xFFF5F5F5),
          ]
              : [
            const Color(0xFFC62828), // rouge foncé (AppColors.clientDark)
            const Color(0xFFE53935), // rouge principal (AppColors.clientPrimary)
            const Color(0xFFF5F5F5),
          ],
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// PAGE CONNEXION
// ─────────────────────────────────────────────
class LoginForm extends StatefulWidget {
  final VoidCallback onSwitchToRegister;
  const LoginForm({super.key, required this.onSwitchToRegister});
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  // ── RENOMMÉ : accepte désormais un email OU un numéro de téléphone ──
  final _identifierCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── AJOUT : retrouve l'email associé à un numéro de téléphone ──
  // Retourne null si aucun compte n'est trouvé pour ce numéro.
  Future<String?> _emailFromPhone(String phone) async {
    final phoneKey = _normalizePhone(phone);
    if (phoneKey.isEmpty) return null;
    final doc = await FirebaseFirestore.instance
        .collection('phone_index')
        .doc(phoneKey)
        .get();
    if (!doc.exists) return null;
    final email = (doc.data()?['email'] ?? '').toString();
    return email.isEmpty ? null : email;
  }

  Future<void> _login() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty || _passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      String email = identifier;

      // ── AJOUT : si ce n'est pas un email, on cherche l'email lié au numéro ──
      if (!identifier.contains('@')) {
        final foundEmail = await _emailFromPhone(identifier);
        if (foundEmail == null) {
          setState(() {
            _error = 'Aucun compte trouvé avec ce numéro de téléphone';
            _loading = false;
          });
          return;
        }
        email = foundEmail;
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('AUTH ERROR CODE: ${e.code} | MESSAGE: ${e.message}');
      setState(() => _error = '${_authError(e.code)} (code: ${e.code})');
    } catch (e) {
      debugPrint('UNEXPECTED LOGIN ERROR: $e');
      setState(() => _error = 'Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Entrez votre email ou téléphone pour réinitialiser le mot de passe');
      return;
    }
    try {
      String email = identifier;

      // ── AJOUT : on résout aussi le téléphone ici ──
      if (!identifier.contains('@')) {
        final foundEmail = await _emailFromPhone(identifier);
        if (foundEmail == null) {
          setState(() => _error = 'Aucun compte trouvé avec ce numéro de téléphone');
          return;
        }
        email = foundEmail;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.email, color: Color(0xFFE53935)),
              SizedBox(width: 8),
              Text('Email envoyé'),
            ]),
            content: Text('Un lien de réinitialisation a été envoyé à\n$email'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _authError(e.code));
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found': return 'Aucun compte trouvé avec cet email';
      case 'wrong-password': return 'Mot de passe incorrect';
      case 'invalid-email': return 'Email invalide';
      case 'invalid-credential': return 'Email/téléphone ou mot de passe incorrect';
      case 'too-many-requests': return 'Trop de tentatives, réessayez plus tard';
      case 'user-disabled': return 'Ce compte a été désactivé';
      case 'network-request-failed': return 'Probleme de connexion internet';
      case 'operation-not-allowed': return "La connexion par email/mot de passe n'est pas activee";
      default: return 'Erreur de connexion, vérifiez vos informations';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GradientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 52),

              // ── Vrai logo KenExpress (rouge + bleu avec panier) ──
              const KenExpressLogo(scale: 1.1), // ← REMPLACE l'ancienne classe locale
              const SizedBox(height: 48),

              // ── Card blanche ──
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 8,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Connexion',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Bon retour sur KenExpress !',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 24),

                      // ── MODIFIÉ : accepte email OU téléphone ──
                      TextField(
                        controller: _identifierCtrl,
                        keyboardType: TextInputType.text,
                        decoration: _inputDeco('Email ou téléphone', Icons.person_outline),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        onSubmitted: (_) => _login(),
                        decoration: _inputDeco('Mot de passe', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text('Mot de passe oublié ?',
                              style: TextStyle(color: Color(0xFFE53935), fontSize: 13)),
                        ),
                      ),

                      if (_error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                                style: const TextStyle(color: Colors.red, fontSize: 12))),
                          ]),
                        ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading
                              ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                              : const Text('Se connecter',
                              style: TextStyle(color: Colors.white, fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Pas de compte ?",
                              style: TextStyle(color: Colors.grey)),
                          TextButton(
                            onPressed: widget.onSwitchToRegister,
                            child: const Text("S'inscrire",
                                style: TextStyle(color: Color(0xFF1E88E5),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
  );
}

// ─────────────────────────────────────────────
// PAGE CHOIX DU RÔLE
// ─────────────────────────────────────────────
class RoleSelectionScreen extends StatelessWidget {
  final VoidCallback onSelectClient;
  final VoidCallback onSelectVendeur;
  final VoidCallback onBack;

  const RoleSelectionScreen({
    super.key,
    required this.onSelectClient,
    required this.onSelectVendeur,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _GradientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 52),

              // ── Vrai logo KenExpress ──
              const KenExpressLogo(scale: 1.0), // ← REMPLACE l'ancienne classe locale
              const SizedBox(height: 48),

              const Text("Je m'inscris en tant que",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Choisissez votre profil pour continuer',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 32),

              // Carte Client
              GestureDetector(
                onTap: onSelectClient,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE53935), width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withValues(alpha: 0.15),
                          blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_bag_outlined,
                            color: Color(0xFFE53935), size: 36),
                      ),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Client / Acheteur',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Achetez des produits et faites-vous livrer',
                                style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Color(0xFFE53935), size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Carte Vendeur
              GestureDetector(
                onTap: onSelectVendeur,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.orange.withValues(alpha: 0.15),
                          blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.store_outlined,
                            color: Colors.orange, size: 36),
                      ),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vendeur / Commerçant',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Publiez vos produits et gérez vos ventes',
                                style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.orange, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                label: const Text('Retour à la connexion',
                    style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAGE INSCRIPTION
// ─────────────────────────────────────────────
class RegisterForm extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  final String role;
  const RegisterForm({super.key, required this.onSwitchToLogin, required this.role});
  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  bool get _isVendeur => widget.role == 'vendeur';

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nomCtrl.text.trim().isEmpty || _prenomCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty ||
        _passCtrl.text.trim().isEmpty || _confirmPassCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs');
      return;
    }
    if (_passCtrl.text != _confirmPassCtrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      // ── AJOUT : on vérifie que ce numéro n'est pas déjà utilisé par un autre compte ──
      final phoneKey = _normalizePhone(_phoneCtrl.text.trim());
      final existingPhone = await FirebaseFirestore.instance
          .collection('phone_index')
          .doc(phoneKey)
          .get();
      if (existingPhone.exists) {
        setState(() {
          _error = 'Ce numéro de téléphone est déjà utilisé par un autre compte';
          _loading = false;
        });
        return;
      }

      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      await result.user?.sendEmailVerification();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
        'nom': _nomCtrl.text.trim(),
        'prenom': _prenomCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'telephone': _phoneCtrl.text.trim(),
        'role': widget.role,
        'createdAt': Timestamp.now(),
      });

      // ── AJOUT : on enregistre le lien téléphone → email pour la connexion par téléphone ──
      await FirebaseFirestore.instance
          .collection('phone_index')
          .doc(phoneKey)
          .set({
        'email': _emailCtrl.text.trim(),
        'uid': result.user!.uid,
      });

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.mark_email_read, color: Color(0xFFE53935), size: 28),
              SizedBox(width: 8),
              Expanded(child: Text('Vérifiez votre email')),
            ]),
            content: Text(
              'Un email de confirmation a été envoyé à :\n\n${_emailCtrl.text.trim()}\n\nVeuillez confirmer votre email avant de vous connecter.',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSwitchToLogin();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935)),
                child: const Text('Aller à la connexion',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _authError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Cet email est déjà utilisé';
      case 'invalid-email': return 'Email invalide';
      case 'weak-password': return 'Mot de passe trop faible (min. 6 caractères)';
      default: return "Erreur lors de l'inscription";
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GradientBackground(
      isVendeur: _isVendeur,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Vrai logo KenExpress (toujours rouge+bleu, même pour vendeur) ──
              const KenExpressLogo(scale: 0.85), // ← REMPLACE l'ancienne classe locale
              const SizedBox(height: 16),

              // Badge rôle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white54),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isVendeur ? Icons.store : Icons.shopping_bag,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isVendeur ? 'Vendeur / Commerçant' : 'Client / Acheteur',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 8,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Créer un compte',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Rejoignez KenExpress dès maintenant',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nomCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDeco('Nom', Icons.person_outline),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _prenomCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDeco('Prénom', Icons.person_outline),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDeco('Email (Gmail)', Icons.email_outlined),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDeco('Numéro de téléphone', Icons.phone_outlined),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: _inputDeco('Mot de passe', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _confirmPassCtrl,
                        obscureText: _obscureConfirm,
                        decoration:
                        _inputDeco('Confirmer le mot de passe', Icons.lock_outline)
                            .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey),
                            onPressed: () =>
                                setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                                style: const TextStyle(color: Colors.red, fontSize: 12))),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isVendeur
                                ? Colors.orange
                                : const Color(0xFFE53935),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading
                              ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                              : const Text("S'inscrire",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Déjà un compte ?",
                              style: TextStyle(color: Colors.grey)),
                          TextButton(
                            onPressed: widget.onSwitchToLogin,
                            child: Text("Se connecter",
                                style: TextStyle(
                                  color: _isVendeur
                                      ? Colors.orange
                                      : const Color(0xFF1E88E5),
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon,
        color: _isVendeur ? Colors.orange : const Color(0xFFE53935)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
          color: _isVendeur ? Colors.orange : const Color(0xFFE53935), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
  );
}