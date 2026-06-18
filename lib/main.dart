// ══════════════════════════════════════════════════════════════
// lib/main.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/vendeur/vendeur_navigation.dart';
import 'screens/admin/admin_screen.dart';
import 'firebase_options.dart';
import 'services/product_service.dart';
import 'widgets/kenexpress_logo.dart'; // ← AJOUT

// ── Couleurs globales client (rouge + bleu) ──
class AppColors {
  static const clientPrimary   = Color(0xFFE53935);
  static const clientSecondary = Color(0xFF1E88E5);
  static const clientDark      = Color(0xFFC62828);
  static const vendeurPrimary  = Colors.orange;
  static const adminPrimary    = Color(0xFF1A237E);
}

// ── Email admin ──
const String kAdminEmail = 'ouedraogokrachid@gmail.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ProductService().migrerProduits();
  runApp(const KenExpressApp());
}

class KenExpressApp extends StatelessWidget {
  const KenExpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KenExpress',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.clientPrimary,
          primary: AppColors.clientPrimary,
          secondary: AppColors.clientSecondary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.clientPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.clientPrimary,
            foregroundColor: Colors.white,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.clientPrimary,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {

          // ── Chargement auth ──
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KenExpressLogo(scale: 1.1), // ← LOGO
                    SizedBox(height: 36),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.clientPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snap.hasData) return const AuthScreen();

          final email = snap.data?.email ?? '';

          // ── Admin détecté par email ──
          if (email == kAdminEmail) {
            return const AdminScreen();
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snap.data!.uid)
                .get(),
            builder: (context, userSnap) {

              // ── Chargement profil Firestore ──
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KenExpressLogo(scale: 1.1), // ← LOGO
                        SizedBox(height: 36),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.clientPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = userSnap.data?.data() as Map<String, dynamic>? ?? {};
              final role = data['role'] ?? 'client';
              final bloque = data['bloque'] ?? false;

              // ── Compte bloqué ──
              if (bloque) {
                return Scaffold(
                  backgroundColor: const Color(0xFFF5F5F5),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── Logo en haut ──
                          const KenExpressLogo(scale: 0.8), // ← LOGO
                          const SizedBox(height: 28),

                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.block,
                                color: Colors.red, size: 64),
                          ),
                          const SizedBox(height: 24),
                          const Text('Compte suspendu',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                          const SizedBox(height: 12),
                          const Text(
                            'Votre compte a été suspendu pour non-respect '
                                'des règles d\'utilisation de KenExpress.\n\n'
                                'Contactez le support pour plus d\'informations.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          const Text('support@kenexpress.com',
                              style: TextStyle(
                                  color: AppColors.clientSecondary,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 32),
                          OutlinedButton.icon(
                            onPressed: () async =>
                            await FirebaseAuth.instance.signOut(),
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text('Se déconnecter',
                                style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (role == 'vendeur') return const VendeurNavigation();
              return const MainNavigation();
            },
          );
        },
      ),
    );
  }
}
