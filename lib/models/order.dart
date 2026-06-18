// ══════════════════════════════════════════════════════════════
// lib/models/order.dart
// Modèle commande avec commission 5% intégrée
// ══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

class AppOrder {
  final String id;
  final String userId;
  final String vendeurId;
  final List<Map<String, dynamic>> items;
  final double total;
  final double commission;      // ← NOUVEAU : 5% du total (part KenExpress)
  final double montantVendeur;  // ← NOUVEAU : 95% du total (part vendeur)
  final String status;
  final String address;
  final DateTime createdAt;
  final String paiementStatut;

  // Taux de commission global (modifier ici si changement futur)
  static const double tauxCommission = 0.05; // 5%

  AppOrder({
    required this.id,
    required this.userId,
    required this.vendeurId,
    required this.items,
    required this.total,
    double? commission,
    double? montantVendeur,
    required this.status,
    required this.address,
    required this.createdAt,
    this.paiementStatut = 'en_attente',
  })  : commission = commission ?? (total * tauxCommission),
        montantVendeur = montantVendeur ?? (total * (1 - tauxCommission));

  factory AppOrder.fromMap(Map<String, dynamic> map, String id) {
    DateTime date;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      date = raw.toDate();
    } else if (raw is int) {
      date = DateTime.fromMillisecondsSinceEpoch(raw);
    } else {
      date = DateTime.now();
    }

    final total = (map['total'] as num?)?.toDouble() ?? 0.0;
    final paiement = map['paiement'] as Map<String, dynamic>?;

    return AppOrder(
      id: id,
      userId: map['userId'] ?? '',
      vendeurId: map['vendeurId'] ?? '',
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      total: total,
      // Lire depuis Firestore si présent, sinon calculer
      commission: (map['commission'] as num?)?.toDouble() ?? (total * AppOrder.tauxCommission),
      montantVendeur: (map['montantVendeur'] as num?)?.toDouble() ?? (total * (1 - AppOrder.tauxCommission)),
      status: map['status'] ?? 'en_attente',
      address: map['address'] ?? '',
      createdAt: date,
      paiementStatut: paiement?['statut'] ?? map['paiementStatut'] ?? 'en_attente',
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'vendeurId': vendeurId,
    'items': items,
    'total': total,
    'commission': commission,
    'montantVendeur': montantVendeur,
    'status': status,
    'address': address,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'paiementStatut': paiementStatut,
  };
}
