// ══════════════════════════════════════════════════════════════
// lib/services/order_service.dart
// CORRECTION : notification vendeur affiche le bon montantVendeur
// et les champs commission/montantVendeur sont toujours enregistrés
// ══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/cart_item.dart';
import '../models/order.dart';
import '../main.dart'; // kAdminEmail
import 'notification_service.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;

  static const double _tauxCommission = AppOrder.tauxCommission; // 5%

  // ── Créer les commandes ET retourner leurs IDs ──
  Future<List<String>> placeOrderAndReturnIds({
    required String userId,
    required List<CartItem> items,
    required String address,
  }) async {
    final Map<String, List<CartItem>> byVendeur = {};
    for (final item in items) {
      byVendeur.putIfAbsent(item.product.vendeurId, () => []).add(item);
    }

    final List<String> createdOrderIds = [];

    for (final entry in byVendeur.entries) {
      final total = entry.value.fold(0.0, (s, i) => s + i.total);

      // ── Calcul commission ──
      final commission = double.parse(
          (total * _tauxCommission).toStringAsFixed(0));
      final montantVendeur = double.parse(
          (total - commission).toStringAsFixed(0));

      final orderRef = await _db.collection('orders').add({
        'userId':        userId,
        'vendeurId':     entry.key,
        'items': entry.value.map((i) => {
          'productId': i.product.id,
          'name':      i.product.name,
          'price':     i.product.prixActuel,
          'quantity':  i.quantity,
          'imageUrl':  i.product.imageUrl,
          'vendor':    i.product.vendeurId,
        }).toList(),
        'total':          total,
        'commission':     commission,       // ← Part KenExpress (5%)
        'montantVendeur': montantVendeur,   // ← Part vendeur (95%)
        'tauxCommission': _tauxCommission,
        'status':         'en_attente',
        'address':        address,
        'paiement': {
          'statut': 'en_attente',
        },
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      createdOrderIds.add(orderRef.id);

      // ── Notification vendeur avec le bon montant ──
      await NotificationService().sendNotification(
        toUserId: entry.key,
        title: 'Nouvelle commande ! 🛒',
        body: 'Commande de ${total.toStringAsFixed(0)} FCFA reçue. '
            'Vous recevrez ${montantVendeur.toStringAsFixed(0)} FCFA '
            'après commission KenExpress (${(commission).toStringAsFixed(0)} FCFA).',
        type:    'nouvelle_commande',
        orderId: orderRef.id,
      );
    }

    return createdOrderIds;
  }

  // ── Compatibilité ──
  Future<void> placeOrder({
    required String userId,
    required List<CartItem> items,
    required String address,
  }) async {
    await placeOrderAndReturnIds(
        userId: userId, items: items, address: address);
  }

  // ── Commandes d'un client ──
  Stream<List<AppOrder>> getUserOrders(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list =
      snap.docs.map((d) => AppOrder.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ── Commandes d'un vendeur ──
  Stream<List<AppOrder>> getVendeurOrders(String vendeurId) {
    return _db
        .collection('orders')
        .where('vendeurId', isEqualTo: vendeurId)
        .snapshots()
        .map((snap) {
      final list =
      snap.docs.map((d) => AppOrder.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ── Toutes les commandes (admin) ──
  Stream<List<AppOrder>> getAllOrders() {
    return _db
        .collection('orders')
        .snapshots()
        .map((snap) {
      final list =
      snap.docs.map((d) => AppOrder.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ── Nombre de commandes par statut (vendeur) ──
  Stream<int> getOrdersCountByStatus(String vendeurId, String status) {
    return _db
        .collection('orders')
        .where('vendeurId', isEqualTo: vendeurId)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ── Récupère l'UID admin ──
  Future<String?> _getAdminUid() async {
    final emailNormalise = kAdminEmail.trim().toLowerCase();

    var snap = await _db
        .collection('users')
        .where('email', isEqualTo: kAdminEmail)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;

    snap = await _db.collection('users').get();
    for (final doc in snap.docs) {
      final email =
      (doc.data()['email'] ?? '').toString().trim().toLowerCase();
      if (email == emailNormalise) return doc.id;
    }

    debugPrint(
        'OrderService: admin introuvable avec email "$kAdminEmail".');
    return null;
  }

  // ── Vendeur change le statut → notification client (+ admin si en livraison) ──
  Future<void> updateStatus(String orderId, String status) async {
    final doc  = await _db.collection('orders').doc(orderId).get();
    final data = doc.data();
    if (data == null) return;

    await _db.collection('orders').doc(orderId).update({'status': status});

    final userId         = data['userId'] ?? '';
    final total          = (data['total'] as num?)?.toDouble() ?? 0;

    // ✅ On lit montantVendeur depuis la commande
    final commission     = (data['commission'] as num?)?.toDouble()
        ?? double.parse((total * _tauxCommission).toStringAsFixed(0));
    final montantVendeur = (data['montantVendeur'] as num?)?.toDouble()
        ?? double.parse((total - commission).toStringAsFixed(0));

    String title, body, type;
    switch (status) {
      case 'confirmée':
        title = 'Commande confirmée ! ✅';
        body  = 'Votre commande de ${total.toStringAsFixed(0)} FCFA a été confirmée par le vendeur.';
        type  = 'commande_confirmee';
        break;
      case 'en_livraison':
        title = 'Commande en livraison ! 🚀';
        body  = 'Votre commande est en route vers vous.';
        type  = 'en_livraison';
        break;
      case 'annulée':
        title = 'Commande annulée';
        body  = 'Votre commande a été annulée par le vendeur.';
        type  = 'annulee';
        break;
      default:
        return;
    }

    await NotificationService().sendNotification(
      toUserId: userId,
      title:    title,
      body:     body,
      type:     type,
      orderId:  orderId,
    );

    // ── Notification admin quand commande en livraison ──
    if (status == 'en_livraison') {
      final adminUid = await _getAdminUid();
      if (adminUid != null) {
        final vendeurId = data['vendeurId'] ?? '';

        // Infos VENDEUR
        String vendeurNom     = '';
        String vendeurTel     = '';
        String vendeurAdresse = '';
        double? vendeurLat;
        double? vendeurLng;

        if (vendeurId.isNotEmpty) {
          final vendeurDoc =
          await _db.collection('users').doc(vendeurId).get();
          final vData = vendeurDoc.data();
          if (vData != null) {
            vendeurNom     = '${vData['prenom'] ?? ''} ${vData['nom'] ?? ''}'.trim();
            vendeurTel     = vData['telephone'] ?? '';
            vendeurAdresse = vData['adresseBoutique'] ?? vData['adresse'] ?? '';
            final loc = vData['localisation'] as Map<String, dynamic>?;
            vendeurLat     = (loc?['latitude']  as num?)?.toDouble();
            vendeurLng     = (loc?['longitude'] as num?)?.toDouble();
          }
        }

        // Infos CLIENT
        String clientNom = '';
        String clientTel = '';

        if (userId.isNotEmpty) {
          final clientDoc =
          await _db.collection('users').doc(userId).get();
          final cData = clientDoc.data();
          if (cData != null) {
            clientNom = '${cData['prenom'] ?? ''} ${cData['nom'] ?? ''}'.trim();
            clientTel = cData['telephone'] ?? '';
          }
        }

        await _db.collection('notifications').add({
          'toUserId': adminUid,
          'title':    'Commande en livraison 🛵',
          'body': 'Commande #${orderId.substring(0, 8).toUpperCase()} '
              '| Total : ${total.toStringAsFixed(0)} FCFA '
              '| Commission KenExpress : ${commission.toStringAsFixed(0)} FCFA '
              '| Net vendeur : ${montantVendeur.toStringAsFixed(0)} FCFA'
              '${vendeurNom.isNotEmpty ? ' | Vendeur : $vendeurNom' : ''}'
              '${vendeurTel.isNotEmpty ? ' | Tél : $vendeurTel' : ''}',
          'type':           'commande_en_livraison',
          'orderId':        orderId,
          // Vendeur
          'vendeurId':      vendeurId,
          'vendeurNom':     vendeurNom,
          'vendeurTel':     vendeurTel,
          'vendeurAdresse': vendeurAdresse,
          'vendeurLat':     vendeurLat,
          'vendeurLng':     vendeurLng,
          // Client
          'clientId':       userId,
          'clientNom':      clientNom,
          'clientTel':      clientTel,
          'clientAddress':  data['address'] ?? '',
          // Méta financière
          'total':          total,
          'commission':     commission,
          'montantVendeur': montantVendeur,
          'isRead':         false,
          'createdAt':      FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // ── Client confirme réception → notification vendeur ──
  Future<void> confirmerReception(String orderId) async {
    final doc  = await _db.collection('orders').doc(orderId).get();
    final data = doc.data();
    if (data == null) return;

    await _db.collection('orders').doc(orderId).update({'status': 'livrée'});

    final vendeurId      = data['vendeurId'] ?? '';
    final total          = (data['total'] as num?)?.toDouble() ?? 0;
    final montantVendeur = (data['montantVendeur'] as num?)?.toDouble()
        ?? double.parse((total * (1 - _tauxCommission)).toStringAsFixed(0));

    await NotificationService().sendNotification(
      toUserId: vendeurId,
      title:    'Commande livrée ✅',
      body:     'Le client a confirmé la réception. '
          'Vous recevrez ${montantVendeur.toStringAsFixed(0)} FCFA sur votre solde.',
      type:     'livree',
      orderId:  orderId,
    );
  }
}