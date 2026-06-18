// ══════════════════════════════════════════════════════════════
// lib/services/pub_service.dart
// Gère les demandes de publicité (vendeurs) et les pubs actives
// ══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PubService {
  final _db = FirebaseFirestore.instance;

  // ── Vendeur : soumettre une demande de pub ──
  Future<void> demanderPub({
    required String productId,
    required String productName,
    required String productImageUrl,
    required String productDescription,
    required double productPrice,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final vendeurNom =
    '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}'.trim();

    await _db.collection('publicites').add({
      'vendeurId': uid,
      'vendeurNom': vendeurNom,
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'productDescription': productDescription,
      'productPrice': productPrice,
      'statut': 'en_attente', // en_attente | active | refusee | expiree
      'prixService': 5000,
      'createdAt': Timestamp.now(),
      'dateDebut': null,
      'dateFin': null,
    });
  }

  // ── Mes demandes de pub (vendeur) ──
  Stream<QuerySnapshot> mesDemandes() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _db
        .collection('publicites')
        .where('vendeurId', isEqualTo: uid)
        .snapshots();
  }

  // ── Admin : toutes les demandes ──
  Stream<QuerySnapshot> toutesLesDemandes() {
    return _db.collection('publicites').snapshots();
  }

  // ── Admin : activer une pub (après paiement confirmé) ──
  Future<void> activerPub(String pubId, {int dureeMois = 1}) async {
    final debut = DateTime.now();
    final fin = DateTime(debut.year, debut.month + dureeMois, debut.day);
    await _db.collection('publicites').doc(pubId).update({
      'statut': 'active',
      'dateDebut': Timestamp.fromDate(debut),
      'dateFin': Timestamp.fromDate(fin),
    });
  }

  // ── Admin : refuser une pub ──
  Future<void> refuserPub(String pubId, {String? motif}) async {
    await _db.collection('publicites').doc(pubId).update({
      'statut': 'refusee',
      'motifRefus': motif ?? '',
    });
  }

  // ── Client : pubs actives à afficher sur l'accueil ──
  Stream<QuerySnapshot> pubsActives() {
    return _db
        .collection('publicites')
        .where('statut', isEqualTo: 'active')
        .snapshots();
  }
}
