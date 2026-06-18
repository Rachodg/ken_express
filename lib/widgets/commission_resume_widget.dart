// ══════════════════════════════════════════════════════════════
// lib/widgets/commission_resume_widget.dart
// Affiche le résumé financier d'une commande (vendeur + admin)
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../models/order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
/// Widget à utiliser dans :
///  - L'écran détail commande du VENDEUR
///  - Le dashboard ADMIN
class CommissionResumeWidget extends StatelessWidget {
  final AppOrder order;
  final bool isAdmin; // true = affiche toutes les lignes, false = vue vendeur

  const CommissionResumeWidget({
    super.key,
    required this.order,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Résumé financier',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Divider(height: 20),

          // Montant total
          _ligne('Total commande', order.total, color: Colors.black87),

          const SizedBox(height: 6),

          // Commission KenExpress
          _ligne(
            'Commission KenExpress (${(AppOrder.tauxCommission * 100).toStringAsFixed(0)}%)',
            -order.commission,
            color: Colors.red.shade700,
            icon: Icons.storefront,
          ),

          const Divider(height: 16),

          // Ce que reçoit le vendeur
          _ligne(
            isAdmin ? 'Montant vendeur (net)' : 'Vous recevrez',
            order.montantVendeur,
            color: Colors.green.shade700,
            bold: true,
            icon: Icons.account_balance_wallet,
          ),

          // Infos admin supplémentaires
          if (isAdmin) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Commission encaissée : ${order.commission.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ligne(String label, double montant, {
    Color color = Colors.black87,
    bool bold = false,
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          '${montant >= 0 ? '' : '- '}${montant.abs().toStringAsFixed(0)} FCFA',
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 15 : 13,
          ),
        ),
      ],
    );
  }
}


// ══════════════════════════════════════════════════════════════
// Carte dashboard ADMIN : total commissions
// ══════════════════════════════════════════════════════════════
class AdminCommissionCard extends StatefulWidget {
  const AdminCommissionCard({super.key});

  @override
  State<AdminCommissionCard> createState() => _AdminCommissionCardState();
}

class _AdminCommissionCardState extends State<AdminCommissionCard> {
  double _totalCommissions = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    // Calcul depuis les commandes livrées
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'livrée')
        .get();

    double total = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final montantBrut = (data['total'] as num?)?.toDouble() ?? 0;
      final commission = (data['commission'] as num?)?.toDouble()
          ?? (montantBrut * AppOrder.tauxCommission);
      total += commission;
    }

    if (mounted) setState(() { _totalCommissions = total; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Commissions KenExpress (5%)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
            '${_totalCommissions.toStringAsFixed(0)} FCFA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sur les commandes livrées',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
