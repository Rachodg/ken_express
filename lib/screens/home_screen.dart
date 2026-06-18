// ══════════════════════════════════════════════════════════════
// lib/screens/home_screen.dart
// Écran "Mes commandes" du client — ClientOrdersScreen
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';                    // AppColors
import '../models/order.dart';            // AppOrder
import '../services/order_service.dart';  // OrderService
import '../services/payment_service.dart'; // PaymentService, MethodePaiement

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
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<List<AppOrder>>(
        stream: OrderService().getUserOrders(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.clientPrimary),
            );
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune commande pour l\'instant',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vos commandes apparaîtront ici',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (_, i) => _OrderCard(order: orders[i], uid: uid),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Carte commande individuelle
// ══════════════════════════════════════════════════════════════
class _OrderCard extends StatefulWidget {
  final AppOrder order;
  final String uid;
  const _OrderCard({required this.order, required this.uid});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _loading = false;

  // ── Couleur selon statut ──
  Color get _statusColor {
    switch (widget.order.status) {
      case 'en_attente':  return Colors.orange;
      case 'confirmée':   return Colors.blue;
      case 'en_livraison': return Colors.purple;
      case 'livrée':      return Colors.green;
      case 'annulée':     return Colors.red;
      default:            return Colors.grey;
    }
  }

  IconData get _statusIcon {
    switch (widget.order.status) {
      case 'en_attente':   return Icons.hourglass_top_rounded;
      case 'confirmée':    return Icons.check_circle_outline;
      case 'en_livraison': return Icons.delivery_dining;
      case 'livrée':       return Icons.done_all;
      case 'annulée':      return Icons.cancel_outlined;
      default:             return Icons.info_outline;
    }
  }

  Future<void> _confirmerReception() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la réception ?'),
        content: const Text(
          'En confirmant, vous attestez avoir reçu votre commande. '
              'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await OrderService().confirmerReception(widget.order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réception confirmée — merci !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _ouvrirPaiement(String orderId, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _PaiementRapideSheet(uid: uid, orderId: orderId),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}h'
          '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final color = _statusColor;

    // Lire paiement depuis Firestore en temps réel
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final paiement = data['paiement'] as Map<String, dynamic>?;
        final paiementStatut = paiement?['statut'] as String?;
        final paiementMethode = paiement?['methode'] as String?;
        final paiementMotif = paiement?['motif'] as String?;
        final status = data['status'] ?? order.status;
        final total = (data['total'] as num?)?.toDouble() ?? order.total;

        // Infos statut paiement
        final _PaiementInfo pInfo = _paiementInfo(paiementStatut);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ──
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.07),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'Commande #${order.id.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(order.createdAt),
                        style:
                        const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_statusIcon, color: color, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          status.replaceAll('_', ' '),
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),

              // ── Articles ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 15, color: AppColors.clientPrimary),
                  const SizedBox(width: 6),
                  Text(
                    '${order.items.length} produit${order.items.length > 1 ? 's' : ''}',
                    style: TextStyle(
                        color: AppColors.clientPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ]),
              ),

              // ── Liste produits ──
              ...order.items.map((item) {
                final name = item['name'] ?? 'Produit';
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                final price = (item['price'] as num?)?.toDouble() ?? 0;
                final imageUrl = item['imageUrl'] ?? '';

                return Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            width: 52,
                            height: 52,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image,
                                color: Colors.grey, size: 20)),
                        errorWidget: (_, __, ___) => Container(
                            width: 52,
                            height: 52,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey, size: 20)),
                      )
                          : Container(
                        width: 52,
                        height: 52,
                        color: AppColors.clientPrimary.withOpacity(0.1),
                        child: const Icon(Icons.inventory_2_outlined,
                            color: AppColors.clientPrimary, size: 24),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Text('x$qty  •  ${price.toStringAsFixed(0)} F/u',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          ]),
                    ),
                    Text(
                      '${(price * qty).toStringAsFixed(0)} F',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87),
                    ),
                  ]),
                );
              }),

              // ── Total + adresse ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '${total.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                            color: AppColors.clientPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(children: [
                  const Icon(Icons.location_on,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(order.address,
                        style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ]),
              ),

              // ── Bloc statut paiement ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pInfo.color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pInfo.color.withOpacity(0.3)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(pInfo.icon, color: pInfo.color, size: 15),
                          const SizedBox(width: 8),
                          Text(pInfo.label,
                              style: TextStyle(
                                  color: pInfo.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          if (paiementMethode != null) ...[
                            const SizedBox(width: 8),
                            Text('• ${_methodeLabel(paiementMethode)}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          ],
                        ]),
                        if (paiementStatut == 'rejete' &&
                            paiementMotif != null) ...[
                          const SizedBox(height: 4),
                          Text('Motif : $paiementMotif',
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 11)),
                        ],
                      ]),
                ),
              ),

              // ── Bouton paiement ──
              if ((paiementStatut == null || paiementStatut == 'rejete') &&
                  status == 'en_attente')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _ouvrirPaiement(order.id, widget.uid),
                      icon: const Icon(Icons.payment, color: Colors.white),
                      label: Text(
                        paiementStatut == 'rejete'
                            ? 'Soumettre un nouveau paiement'
                            : 'Soumettre le paiement',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.clientPrimary,
                        padding:
                        const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),

              // ── Bouton confirmer réception ──
              if (status == 'en_livraison')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _confirmerReception,
                      icon: _loading
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                          _loading ? 'Confirmation...' : 'J\'ai reçu mon produit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),

              if (status == 'livrée')
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(children: [
                    Icon(Icons.verified, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Text('Réception confirmée — merci !',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),

              if (status != 'en_livraison' &&
                  status != 'livrée' &&
                  !(paiementStatut == null && status == 'en_attente') &&
                  !(paiementStatut == 'rejete' && status == 'en_attente'))
                const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

// ── Infos statut paiement ──
class _PaiementInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _PaiementInfo(
      {required this.label, required this.color, required this.icon});
}

_PaiementInfo _paiementInfo(String? statut) {
  switch (statut) {
    case 'valide':
      return const _PaiementInfo(
          label: 'Paiement validé',
          color: Colors.green,
          icon: Icons.check_circle);
    case 'rejete':
      return const _PaiementInfo(
          label: 'Paiement rejeté',
          color: Colors.red,
          icon: Icons.cancel);
    case 'en_attente':
      return const _PaiementInfo(
          label: 'Paiement en attente de validation',
          color: Colors.orange,
          icon: Icons.hourglass_top_rounded);
    default:
      return const _PaiementInfo(
          label: 'Paiement non soumis',
          color: Colors.grey,
          icon: Icons.payment);
  }
}

String _methodeLabel(String methode) {
  switch (methode) {
    case 'orange_money':  return 'Orange Money';
    case 'moov_money':    return 'Moov Money';
    case 'telecel_money': return 'Telecel Money';
    case 'wave':          return 'Wave';
    default:              return methode;
  }
}

// ══════════════════════════════════════════════════════════════
// Feuille de paiement rapide (depuis Mes commandes)
// ══════════════════════════════════════════════════════════════
class _PaiementRapideSheet extends StatefulWidget {
  final String uid;
  final String orderId;
  const _PaiementRapideSheet({required this.uid, required this.orderId});

  @override
  State<_PaiementRapideSheet> createState() => _PaiementRapideSheetState();
}

class _PaiementRapideSheetState extends State<_PaiementRapideSheet> {
  MethodePaiement? _methodChoisie;
  final _numeroCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _methodes = [
    (methode: MethodePaiement.orangeMoney,  label: 'Orange Money',  color: Color(0xFFFF6600)),
    (methode: MethodePaiement.moovMoney,    label: 'Moov Money',    color: Color(0xFF0066CC)),
    (methode: MethodePaiement.telecelMoney, label: 'Telecel Money', color: Color(0xFFCC0000)),
    (methode: MethodePaiement.wave,         label: 'Wave',          color: Color(0xFF009688)),
  ];

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    if (_methodChoisie == null) {
      setState(() => _error = 'Choisissez un moyen de paiement');
      return;
    }
    if (_numeroCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Entrez votre numéro de téléphone utilisé');
      return;
    }
    if (_refCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Entrez la référence de transaction');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final orderSnap = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      final montant =
          ((orderSnap.data() ?? {})['total'] as num?)?.toDouble() ?? 0;

      await PaymentService().soumettreGeneral(
        uid: widget.uid,
        commandeId: widget.orderId,
        montant: montant,
        numeroPaiement: _numeroCtrl.text.trim(),
        referenceTransaction: _refCtrl.text.trim(),
        description: 'Commande KenExpress',
        methode: _methodChoisie!.firestoreKey,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paiement soumis ! En attente de validation.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Soumettre le paiement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Choisissez votre moyen de paiement',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.8,
              children: _methodes.map((m) {
                final selected = _methodChoisie == m.methode;
                return GestureDetector(
                  onTap: () => setState(() => _methodChoisie = m.methode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected ? m.color : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                        selected ? m.color : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(m.label,
                          style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            if (_methodChoisie != null) ...[
              const Text('Numéro utilisé',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _numeroCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Ex : 07X XXX XXX',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.clientPrimary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Référence de transaction',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _refCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Ex : TXN123456789',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.clientPrimary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!,
                    style:
                    const TextStyle(color: Colors.red, fontSize: 13)),
              ),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _soumettre,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.clientPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Soumettre',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}