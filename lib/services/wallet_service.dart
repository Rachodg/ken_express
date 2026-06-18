// ══════════════════════════════════════════════════════════════
// lib/services/wallet_service.dart
// Gestion des soldes vendeurs avec commission 5% KenExpress
// ══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart';

enum StatutRetrait { enAttente, paye, rejete }

class WalletService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _sellers => _db.collection('sellers');
  CollectionReference get _retraits => _db.collection('retraits');
  CollectionReference get _orders => _db.collection('orders');

  // ══════════════════════════════════════════════════════════════
  // COMMISSION : quand admin valide le paiement
  // On crédite UNIQUEMENT montantVendeur (95%) dans son solde
  // La commission (5%) reste dans Firestore pour comptabilité admin
  // ══════════════════════════════════════════════════════════════

  /// Appelé par PaymentService.validerPaiement()
  /// Crédite le solde "en attente" du vendeur avec son montant NET (95%)
  Future<void> crediterSoldeEnAttente(String sellerId, double montant) async {
    // montant ici = total brut de la commande
    final montantNet = double.parse(
      (montant * (1 - AppOrder.tauxCommission)).toStringAsFixed(0),
    );
    final commission = double.parse(
      (montant * AppOrder.tauxCommission).toStringAsFixed(0),
    );

    // Créditer le vendeur avec son montant net
    await _sellers.doc(sellerId).set({
      'soldeEnAttente': FieldValue.increment(montantNet),
      'totalCommissionsPayees': FieldValue.increment(commission), // suivi des commissions
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Enregistrer la commission dans la collection admin_finances
    await _db.collection('admin_finances').add({
      'type': 'commission',
      'sellerId': sellerId,
      'montantBrut': montant,
      'commission': commission,
      'montantNet': montantNet,
      'tauxCommission': AppOrder.tauxCommission,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Version si on a déjà le montantNet calculé (depuis order.montantVendeur)
  Future<void> crediterSoldeEnAttenteNet({
    required String sellerId,
    required double montantNet,
    required double commission,
    required String orderId,
  }) async {
    final batch = _db.batch();

    // Crédit vendeur
    batch.set(
      _sellers.doc(sellerId),
      {
        'soldeEnAttente': FieldValue.increment(montantNet),
        'totalCommissionsPayees': FieldValue.increment(commission),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Historique commission admin
    final financeRef = _db.collection('admin_finances').doc();
    batch.set(financeRef, {
      'type': 'commission',
      'sellerId': sellerId,
      'orderId': orderId,
      'montantBrut': montantNet + commission,
      'commission': commission,
      'montantNet': montantNet,
      'tauxCommission': AppOrder.tauxCommission,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ══════════════════════════════════════════════════════════════
  // SOLDE DISPONIBLE : quand commande livrée confirmée
  // ══════════════════════════════════════════════════════════════

  Future<void> libererSolde(String sellerId, double montantNet) async {
    await _sellers.doc(sellerId).set({
      'soldeEnAttente': FieldValue.increment(-montantNet),
      'soldeDisponible': FieldValue.increment(montantNet),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ══════════════════════════════════════════════════════════════
  // SOLDE DU VENDEUR
  // ══════════════════════════════════════════════════════════════

  Stream<Map<String, dynamic>> getSolde(String sellerId) {
    return _sellers.doc(sellerId).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return {
        'soldeDisponible': (data['soldeDisponible'] as num?)?.toDouble() ?? 0.0,
        'soldeEnAttente': (data['soldeEnAttente'] as num?)?.toDouble() ?? 0.0,
        'totalCommissionsPayees': (data['totalCommissionsPayees'] as num?)?.toDouble() ?? 0.0,
      };
    });
  }

  // ══════════════════════════════════════════════════════════════
  // DEMANDE DE RETRAIT
  // ══════════════════════════════════════════════════════════════

  Future<void> demanderRetrait({
    required String sellerId,
    required double montant,
    required String modePaiement,
    required String numero,
  }) async {
    // Vérifier que le solde est suffisant
    final sellerDoc = await _sellers.doc(sellerId).get();
    final data = sellerDoc.data() as Map<String, dynamic>? ?? {};
    final solde = (data['soldeDisponible'] as num?)?.toDouble() ?? 0.0;

    if (montant > solde) {
      throw Exception('Solde insuffisant. Disponible : ${solde.toStringAsFixed(0)} FCFA');
    }

    // Bloquer le montant le temps du traitement
    await _sellers.doc(sellerId).update({
      'soldeDisponible': FieldValue.increment(-montant),
      'soldeEnAttente': FieldValue.increment(montant),
    });

    await _retraits.add({
      'sellerId': sellerId,
      'montant': montant,
      'modePaiement': modePaiement,
      'numero': numero,
      'statut': 'en_attente',
      'createdAt': Timestamp.now(),
    });
  }

  // ── Admin : valider un retrait ──
  Future<void> validerRetrait(String retraitId) async {
    final doc = await _retraits.doc(retraitId).get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final sellerId = data['sellerId'] ?? '';
    final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;

    await _retraits.doc(retraitId).update({
      'statut': 'paye',
      'payeAt': Timestamp.now(),
    });

    // Libérer le montant bloqué (retrait validé)
    await _sellers.doc(sellerId).update({
      'soldeEnAttente': FieldValue.increment(-montant),
    });
  }

  // ── Admin : rejeter un retrait ──
  Future<void> rejeterRetrait(String retraitId, {String? motif}) async {
    final doc = await _retraits.doc(retraitId).get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final sellerId = data['sellerId'] ?? '';
    final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;

    await _retraits.doc(retraitId).update({
      'statut': 'rejete',
      'motif': motif ?? '',
    });

    // Rembourser le montant bloqué
    await _sellers.doc(sellerId).update({
      'soldeEnAttente': FieldValue.increment(-montant),
      'soldeDisponible': FieldValue.increment(montant),
    });
  }

  // ── Historique des retraits d'un vendeur ──
  Stream<QuerySnapshot> getRetraits(String sellerId) {
    return _retraits
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Admin : toutes les commissions encaissées ──
  Stream<QuerySnapshot> getToutesLesCommissions() {
    return _db
        .collection('admin_finances')
        .where('type', isEqualTo: 'commission')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Admin : total commissions encaissées ──
  Future<double> getTotalCommissions() async {
    final snap = await _db
        .collection('admin_finances')
        .where('type', isEqualTo: 'commission')
        .get();
    double total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['commission'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }
}
