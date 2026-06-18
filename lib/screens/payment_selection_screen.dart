import 'package:flutter/material.dart';
import 'orange_money_screen.dart';
import 'moov_money_screen.dart';
import 'telecel_money_screen.dart';
import 'wave_payment_screen.dart';

/// Écran de sélection du moyen de paiement
/// Appeler avec : Navigator.push(context, MaterialPageRoute(
///   builder: (_) => PaymentSelectionScreen(montant: 5000, commandeId: 'CMD_001', description: 'Commande #001')))
class PaymentSelectionScreen extends StatelessWidget {
  final double montant;
  final String commandeId;
  final String description;

  const PaymentSelectionScreen({
    super.key,
    required this.montant,
    required this.commandeId,
    required this.description,
  });

  static const _methodes = [
    _MethodeInfo(
      label: 'Orange Money',
      sousTitre: 'Composez *144#',
      couleur: Color(0xFFFF6600),
      couleurLight: Color(0xFFFFF3E0),
      icon: Icons.account_balance_wallet,
      tag: 'orange',
    ),
    _MethodeInfo(
      label: 'Moov Money',
      sousTitre: 'Composez *155#',
      couleur: Color(0xFF0066CC),
      couleurLight: Color(0xFFE3F0FF),
      icon: Icons.account_balance_wallet_outlined,
      tag: 'moov',
    ),
    _MethodeInfo(
      label: 'Telecel Money',
      sousTitre: 'Composez *130#',
      couleur: Color(0xFFCC0000),
      couleurLight: Color(0xFFFFF0F0),
      icon: Icons.mobile_friendly,
      tag: 'telecel',
    ),
    _MethodeInfo(
      label: 'Wave',
      sousTitre: 'Via l\'application Wave',
      couleur: Color(0xFF009688),
      couleurLight: Color(0xFFE0F2F1),
      icon: Icons.waves_rounded,
      tag: 'wave',
    ),
  ];

  void _naviguer(BuildContext context, String tag) {
    Widget screen;
    switch (tag) {
      case 'orange':
        screen = OrangeMoneyPaymentScreen(montant: montant, commandeId: commandeId, description: description);
        break;
      case 'moov':
        screen = MoovMoneyPaymentScreen(montant: montant, commandeId: commandeId, description: description);
        break;
      case 'telecel':
        screen = TelecelMoneyPaymentScreen(montant: montant, commandeId: commandeId, description: description);
        break;
      case 'wave':
        screen = WavePaymentScreen(montant: montant, commandeId: commandeId, description: description);
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Choisir un moyen de paiement'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Récapitulatif commande
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Récapitulatif', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    '${montant.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Commande : $commandeId',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            const Text(
              'Sélectionnez votre opérateur',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Paiement sécurisé — validé par notre équipe sous peu.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Grille des opérateurs
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.1,
              ),
              itemCount: _methodes.length,
              itemBuilder: (context, i) {
                final m = _methodes[i];
                return _MethodeCard(
                  info: m,
                  onTap: () => _naviguer(context, m.tag),
                );
              },
            ),

            const SizedBox(height: 28),

            // Note sécurité
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.green, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Paiement sécurisé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text(
                          'Vos informations de paiement ne sont jamais partagées. Chaque transaction est vérifiée manuellement.',
                          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Modèle interne ──
class _MethodeInfo {
  final String label;
  final String sousTitre;
  final Color couleur;
  final Color couleurLight;
  final IconData icon;
  final String tag;

  const _MethodeInfo({
    required this.label,
    required this.sousTitre,
    required this.couleur,
    required this.couleurLight,
    required this.icon,
    required this.tag,
  });
}

// ── Carte opérateur ──
class _MethodeCard extends StatelessWidget {
  final _MethodeInfo info;
  final VoidCallback onTap;

  const _MethodeCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: info.couleurLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(info.icon, color: info.couleur, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                info.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: info.couleur,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                info.sousTitre,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
