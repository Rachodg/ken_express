import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/payment_service.dart';

/// Écran "Mes commandes" pour le client.
/// Affiche toutes les commandes du client connecté, avec :
/// - le statut visuel de chaque commande
/// - un bouton "J'ai reçu mon produit" quand status == 'en_livraison'
///   qui appelle PaymentService().confirmerReceptionCommande(commandeId)
///   pour libérer les fonds vers le solde disponible du vendeur.
class ClientOrdersScreen extends StatelessWidget {
  const ClientOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes commandes'),
        backgroundColor: AppColors.clientPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('clientId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.clientPrimary));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Erreur : ${snap.error}', style: const TextStyle(color: Colors.red)),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Aucune commande pour le moment',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) => _OrderCard(doc: docs[i]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _OrderCard({required this.doc});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _loading = false;

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    final dt = (ts as Timestamp).toDate();
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  ({Color color, String label, IconData icon}) _statutInfo(String status) {
    switch (status) {
      case 'en_attente':
        return (color: Colors.grey, label: 'En attente de paiement', icon: Icons.hourglass_empty);
      case 'confirmée':
        return (color: Colors.blue, label: 'Paiement confirmé', icon: Icons.check_circle_outline);
      case 'en_livraison':
        return (color: Colors.orange, label: 'En cours de livraison', icon: Icons.delivery_dining);
      case 'livrée':
        return (color: Colors.green, label: 'Livrée', icon: Icons.done_all);
      default:
        return (color: Colors.grey, label: status, icon: Icons.receipt_long);
    }
  }

  Future<void> _confirmerReception(String commandeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la réception'),
        content: const Text(
          'Confirmez-vous avoir bien reçu votre produit ?\n\n'
              'Cette action est définitive et déclenche le paiement du vendeur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Oui, j\'ai reçu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await PaymentService().confirmerReceptionCommande(commandeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Merci ! Le vendeur a été crédité.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final status = (data['status'] ?? '').toString();
    final total = (data['total'] ?? 0).toDouble();
    final info = _statutInfo(status);
    final paiement = data['paiement'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Commande #${widget.doc.id.substring(0, 6).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(info.icon, color: info.color, size: 14),
                          const SizedBox(width: 4),
                          Text(info.label,
                              style: TextStyle(color: info.color, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text('${total.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.clientPrimary)),
                  ],
                ),
                if (paiement != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Paiement', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text(_methodeLabel(paiement['methode']), style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Date', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text(_formatDate(data['createdAt']), style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          // Bouton de confirmation de réception
          if (status == 'en_livraison')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : () => _confirmerReception(widget.doc.id),
                  icon: _loading
                      ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_loading ? 'Confirmation...' : 'J\'ai reçu mon produit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

          if (status == 'livrée')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  const Text('Réception confirmée — merci !',
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _methodeLabel(dynamic methode) {
    switch (methode) {
      case 'orange_money':  return 'Orange Money';
      case 'moov_money':    return 'Moov Money';
      case 'telecel_money': return 'Telecel Money';
      case 'wave':          return 'Wave';
      default:              return methode?.toString() ?? '—';
    }
  }
}