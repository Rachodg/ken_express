// ══════════════════════════════════════════════════════════════
// commandes_recues_screen.dart
// CORRECTION : Affichage enrichi des produits commandés
//  - Photo du produit visible sur chaque ligne
//  - Nom, quantité, prix unitaire ET sous-total bien distincts
//  - Section produits plus lisible avec séparateurs
//  - Info client (adresse de livraison) bien mise en évidence
// ══════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';

class CommandesRecuesScreen extends StatelessWidget {
  const CommandesRecuesScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmée':    return Colors.blue;
      case 'en_livraison': return Colors.orange;
      case 'livrée':       return Colors.green;
      case 'annulée':      return Colors.red;
      default:             return Colors.grey;
    }
  }

  int _prioriteStatut(String status) {
    switch (status) {
      case 'en_attente':   return 0;
      case 'confirmée':    return 1;
      case 'en_livraison': return 2;
      case 'livrée':       return 3;
      case 'annulée':      return 4;
      default:             return 5;
    }
  }

  List<AppOrder> _trier(List<AppOrder> orders) {
    final liste = [...orders];
    liste.sort((a, b) {
      final pa = _prioriteStatut(a.status);
      final pb = _prioriteStatut(b.status);
      if (pa != pb) return pa.compareTo(pb);
      return b.createdAt.compareTo(a.createdAt);
    });
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Commandes reçues'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // ── Bandeau commandes confirmées en attente de livraison ──
          StreamBuilder<int>(
            stream: OrderService().getOrdersCountByStatus(uid, 'confirmée'),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.hourglass_top, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      count == 1
                          ? '1 commande confirmée en attente de livraison'
                          : '$count commandes confirmées en attente de livraison',
                      style: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ]),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<AppOrder>>(
              stream: OrderService().getVendeurOrders(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                if (snap.hasError) {
                  return Center(child: Text('Erreur: ${snap.error}',
                      style: const TextStyle(color: Colors.red)));
                }
                final orders = _trier(snap.data ?? []);
                if (orders.isEmpty) {
                  return const Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucune commande reçue',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ]),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _orderCard(context, orders[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context, AppOrder order) {
    final color = _statusColor(order.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête commande ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'Commande #${order.id.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}  '
                        '${order.createdAt.hour.toString().padLeft(2, '0')}h${order.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    order.status.replaceAll('_', ' '),
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ── Liste des produits commandés ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(children: [
              const Icon(Icons.shopping_bag_outlined, size: 15, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                '${order.items.length} produit${order.items.length > 1 ? 's' : ''} commandé${order.items.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ]),
          ),

          // ── Chaque produit avec photo ──
          ...order.items.map((item) {
            final name      = item['name'] ?? 'Produit';
            final quantity  = (item['quantity'] as num?)?.toInt() ?? 1;
            final price     = (item['price'] as num?)?.toDouble() ?? 0;
            final imageUrl  = item['imageUrl'] ?? '';
            final sousTotal = price * quantity;

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // Photo produit
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 60, height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 60, height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                        : Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: Colors.orange, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nom + détails
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'x$quantity',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${price.toStringAsFixed(0)} F / unité',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  // Sous-total
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      '${sousTotal.toStringAsFixed(0)} F',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87),
                    ),
                    const Text('sous-total',
                        style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ]),
                ],
              ),
            );
          }),

          // ── Total + Adresse ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total commande',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  '${order.total.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.address,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ]),
          ),

          // ── Boutons d'action ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: _buildActions(order),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(AppOrder order) {
    // En attente + paiement validé → Confirmer / Annuler
    if (order.status == 'en_attente' && order.paiementStatut == 'valide') {
      return Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async =>
            await OrderService().updateStatus(order.id, 'confirmée'),
            icon: const Icon(Icons.check, color: Colors.white, size: 16),
            label: const Text('Confirmer', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async =>
            await OrderService().updateStatus(order.id, 'annulée'),
            icon: const Icon(Icons.close, color: Colors.red, size: 16),
            label: const Text('Annuler', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
      ]);
    }

    // En attente + paiement non validé
    if (order.status == 'en_attente' && order.paiementStatut != 'valide') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              order.paiementStatut == 'rejete'
                  ? 'Paiement rejeté par l\'admin. Le client doit resoumettre.'
                  : 'En attente de validation du paiement par l\'admin.',
              style: const TextStyle(
                  color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      );
    }

    // Confirmée → Marquer en livraison
    if (order.status == 'confirmée') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async =>
          await OrderService().updateStatus(order.id, 'en_livraison'),
          icon: const Icon(Icons.delivery_dining, color: Colors.white),
          label: const Text('Marquer en livraison',
              style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      );
    }

    // En livraison → attente client
    if (order.status == 'en_livraison') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'En attente de confirmation du client. Fonds libérés dès réception confirmée.',
              style: TextStyle(
                  color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      );
    }

    // Livrée
    if (order.status == 'livrée') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.done_all, color: Colors.green),
          SizedBox(width: 8),
          Text('Livraison confirmée — fonds disponibles',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ]),
      );
    }

    return const SizedBox.shrink();
  }
}
