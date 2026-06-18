import 'package:cloud_firestore/cloud_firestore.dart';

enum StatutPaiement { enAttente, valide, rejete }
enum StatutRetrait { enAttente, paye, rejete }

enum MethodePaiement {
  orangeMoney,
  moovMoney,
  telecelMoney,
  wave;

  String get label {
    switch (this) {
      case MethodePaiement.orangeMoney:  return 'Orange Money';
      case MethodePaiement.moovMoney:    return 'Moov Money';
      case MethodePaiement.telecelMoney: return 'Telecel Money';
      case MethodePaiement.wave:         return 'Wave';
    }
  }

  String get firestoreKey {
    switch (this) {
      case MethodePaiement.orangeMoney:  return 'orange_money';
      case MethodePaiement.moovMoney:    return 'moov_money';
      case MethodePaiement.telecelMoney: return 'telecel_money';
      case MethodePaiement.wave:         return 'wave';
    }
  }
}

class PaymentService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _paiements => _db.collection('paiements');
  CollectionReference get _orders    => _db.collection('orders');
  CollectionReference get _sellers   => _db.collection('sellers');
  CollectionReference get _retraits  => _db.collection('retraits');
  CollectionReference get _users     => _db.collection('users');

  // ════════════════════════════════════════════════════
  // PAIEMENTS CLIENT
  // ════════════════════════════════════════════════════

  Future<String> soumettreGeneral({
    required String uid,
    required String commandeId,
    required double montant,
    required String numeroPaiement,
    required String referenceTransaction,
    required String description,
    required String methode,
  }) async {
    final doc = await _paiements.add({
      'uid':                  uid,
      'commandeId':           commandeId,
      'montant':              montant,
      'numeroPaiement':       numeroPaiement,
      'referenceTransaction': referenceTransaction.toUpperCase(),
      'description':          description,
      'methode':              methode,
      'statut':               'en_attente',
      'createdAt':            FieldValue.serverTimestamp(),
      'updatedAt':            FieldValue.serverTimestamp(),
    });

    await _orders.doc(commandeId).update({
      'paiement': {
        'methode':              methode,
        'statut':               'en_attente',
        'paiementId':           doc.id,
        'numeroPaiement':       numeroPaiement,
        'referenceTransaction': referenceTransaction.toUpperCase(),
        'montant':              montant,
        'soumisAt':             FieldValue.serverTimestamp(),
      },
    });

    return doc.id;
  }

  // Alias Orange Money pour compatibilité
  Future<String> soumettreOrangeMoney({
    required String uid,
    required String commandeId,
    required double montant,
    required String numeroPaiement,
    required String referenceTransaction,
    required String description,
  }) => soumettreGeneral(
    uid: uid,
    commandeId: commandeId,
    montant: montant,
    numeroPaiement: numeroPaiement,
    referenceTransaction: referenceTransaction,
    description: description,
    methode: 'orange_money',
  );

  // ════════════════════════════════════════════════════
  // ADMIN — Valider un paiement
  // ════════════════════════════════════════════════════
  // Flux : paiement validé → order.status = 'confirmée'
  //        → seller.soldeEnAttente += montantVendeur (95%)
  //        → KenExpress garde la commission (5%)
  Future<void> validerPaiement(String paiementId) async {
    final paiementRef = _paiements.doc(paiementId);
    final snap        = await paiementRef.get();
    if (!snap.exists) throw Exception('Paiement introuvable');
    final data       = snap.data() as Map<String, dynamic>;
    final commandeId = data['commandeId'] as String;
    final montant    = (data['montant'] as num).toDouble();

    final orderSnap = await _orders.doc(commandeId).get();
    if (!orderSnap.exists) throw Exception('Commande introuvable');
    final orderData = orderSnap.data() as Map<String, dynamic>;

    final sellerId = (orderData['vendeurId'] ?? orderData['sellerId']) as String?;

    // ── CORRECTION : lire montantVendeur depuis la commande ──
    // Si absent (anciennes commandes), calculer 95% du total
    final montantVendeur = (orderData['montantVendeur'] as num?)?.toDouble()
        ?? (montant * 0.95);
    final commission = (orderData['commission'] as num?)?.toDouble()
        ?? (montant * 0.05);

    final batch = _db.batch();

    // 1. Marquer le paiement comme validé
    batch.update(paiementRef, {
      'statut':    'valide',
      'updatedAt': FieldValue.serverTimestamp(),
      'valideAt':  FieldValue.serverTimestamp(),
    });

    // 2. Passer la commande en 'confirmée'
    batch.update(_orders.doc(commandeId), {
      'status':              'confirmée',
      'paiement.statut':     'valide',
      'paiement.valideAt':   FieldValue.serverTimestamp(),
    });

    // 3. Créditer UNIQUEMENT montantVendeur (95%) au vendeur
    //    La commission (5%) reste chez KenExpress
    if (sellerId != null && sellerId.isNotEmpty) {
      batch.set(_sellers.doc(sellerId), {
        'soldeEnAttente': FieldValue.increment(montantVendeur), // ← 95% seulement
        'updatedAt':      FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // ════════════════════════════════════════════════════
  // ADMIN — Rejeter un paiement
  // ════════════════════════════════════════════════════
  Future<void> rejetterPaiement(String paiementId, String motif) async {
    final paiementRef = _paiements.doc(paiementId);
    final snap        = await paiementRef.get();
    if (!snap.exists) throw Exception('Paiement introuvable');
    final data       = snap.data() as Map<String, dynamic>;
    final commandeId = data['commandeId'] as String;

    final batch = _db.batch();
    batch.update(paiementRef, {
      'statut':      'rejete',
      'motifRejet':  motif,
      'updatedAt':   FieldValue.serverTimestamp(),
    });
    batch.update(_orders.doc(commandeId), {
      'paiement.statut':      'rejete',
      'paiement.motifRejet':  motif,
    });
    await batch.commit();
  }

  // ════════════════════════════════════════════════════
  // CLIENT — Confirme réception du produit
  // ════════════════════════════════════════════════════
  // Flux : réception confirmée → soldeEnAttente -= montantVendeur
  //        → solde (disponible) += montantVendeur
  //        → totalGagne += montantVendeur
  //        → order.status = 'livrée'
  Future<void> confirmerReceptionCommande(String commandeId) async {
    final orderRef  = _orders.doc(commandeId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) throw Exception('Commande introuvable');
    final data = orderSnap.data() as Map<String, dynamic>;

    final sellerId = (data['vendeurId'] ?? data['sellerId']) as String?;

    // ── CORRECTION : utiliser montantVendeur (95%) et non le montant brut ──
    final montantBrut    = (data['paiement']?['montant'] as num?)?.toDouble()
        ?? (data['total'] as num?)?.toDouble()
        ?? 0.0;
    final montantVendeur = (data['montantVendeur'] as num?)?.toDouble()
        ?? (montantBrut * 0.95);

    if (sellerId == null || sellerId.isEmpty) {
      throw Exception('Vendeur introuvable sur la commande');
    }

    final sellerRef = _sellers.doc(sellerId);
    final batch = _db.batch();

    // Débloquer les fonds : en attente → disponible (95% seulement)
    batch.set(sellerRef, {
      'soldeEnAttente': FieldValue.increment(-montantVendeur),
      'solde':          FieldValue.increment(montantVendeur),
      'totalGagne':     FieldValue.increment(montantVendeur),
      'updatedAt':      FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Clôturer la commande
    batch.update(orderRef, {
      'status':          'livrée',
      'fondsLiberes':    true,
      'fondsLiberesAt':  FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ════════════════════════════════════════════════════
  // VENDEUR — Demande de retrait
  // ════════════════════════════════════════════════════
  Future<String> demanderRetrait({
    required String sellerId,
    required double montant,
    required String methode,
    required String numeroRetrait,
  }) async {
    if (montant <= 0) throw Exception('Montant invalide');

    final sellerRef  = _sellers.doc(sellerId);
    final sellerSnap = await sellerRef.get();
    final sellerData = sellerSnap.data() as Map<String, dynamic>?;
    final solde      = (sellerData?['solde'] as num?)?.toDouble() ?? 0;

    if (montant > solde) throw Exception('Solde insuffisant');

    final userSnap   = await _users.doc(sellerId).get();
    final userData   = userSnap.data() as Map<String, dynamic>?;
    final nomVendeur = userData?['name'] ?? userData?['nom'] ?? userData?['displayName'] ?? '';

    final retraitRef = _retraits.doc();
    final batch = _db.batch();

    batch.set(retraitRef, {
      'sellerId':      sellerId,
      'nomVendeur':    nomVendeur,
      'montant':       montant,
      'methode':       methode,
      'numeroRetrait': numeroRetrait,
      'statut':        'en_attente',
      'createdAt':     FieldValue.serverTimestamp(),
      'traiteAt':      null,
    });

    batch.set(sellerRef, {
      'solde':        FieldValue.increment(-montant),
      'soldeBloque':  FieldValue.increment(montant),
      'updatedAt':    FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    return retraitRef.id;
  }

  // ════════════════════════════════════════════════════
  // ADMIN — Valider un retrait
  // ════════════════════════════════════════════════════
  Future<void> validerRetrait(String retraitId) async {
    final retraitRef = _retraits.doc(retraitId);
    final snap       = await retraitRef.get();
    if (!snap.exists) throw Exception('Retrait introuvable');
    final data     = snap.data() as Map<String, dynamic>;
    final sellerId = data['sellerId'] as String;
    final montant  = (data['montant'] as num).toDouble();

    final batch = _db.batch();
    batch.update(retraitRef, {
      'statut':    'paye',
      'traiteAt':  FieldValue.serverTimestamp(),
    });
    batch.set(_sellers.doc(sellerId), {
      'soldeBloque': FieldValue.increment(-montant),
      'updatedAt':   FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ════════════════════════════════════════════════════
  // ADMIN — Rejeter un retrait
  // ════════════════════════════════════════════════════
  Future<void> rejeterRetrait(String retraitId, String motif) async {
    final retraitRef = _retraits.doc(retraitId);
    final snap       = await retraitRef.get();
    if (!snap.exists) throw Exception('Retrait introuvable');
    final data     = snap.data() as Map<String, dynamic>;
    final sellerId = data['sellerId'] as String;
    final montant  = (data['montant'] as num).toDouble();

    final batch = _db.batch();
    batch.update(retraitRef, {
      'statut':      'rejete',
      'motifRejet':  motif,
      'traiteAt':    FieldValue.serverTimestamp(),
    });
    batch.set(_sellers.doc(sellerId), {
      'solde':        FieldValue.increment(montant),
      'soldeBloque':  FieldValue.increment(-montant),
      'updatedAt':    FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ════════════════════════════════════════════════════
  // STREAMS PAIEMENTS
  // ════════════════════════════════════════════════════
  Stream<QuerySnapshot> paiementsEnAttente() => _paiements
      .where('statut', isEqualTo: 'en_attente')
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> paiementsEnAttenteParMethode(String methode) => _paiements
      .where('statut', isEqualTo: 'en_attente')
      .where('methode', isEqualTo: methode)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> paiementsUtilisateur(String uid) => _paiements
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> tousLesPaiements() =>
      _paiements.orderBy('createdAt', descending: true).snapshots();

  // ════════════════════════════════════════════════════
  // HISTORIQUE PAIEMENTS
  // ════════════════════════════════════════════════════
  Stream<QuerySnapshot> historiquePaiements() => _paiements
      .where('statut', whereIn: ['valide', 'rejete'])
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> historiquePaiementsParMethode(String methode) => _paiements
      .where('statut', whereIn: ['valide', 'rejete'])
      .where('methode', isEqualTo: methode)
      .orderBy('createdAt', descending: true)
      .snapshots();

  // ════════════════════════════════════════════════════
  // STREAMS RETRAITS
  // ════════════════════════════════════════════════════
  Stream<DocumentSnapshot> soldeVendeur(String sellerId) =>
      _sellers.doc(sellerId).snapshots();

  Stream<QuerySnapshot> retraitsVendeur(String sellerId) => _retraits
      .where('sellerId', isEqualTo: sellerId)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> retraitsEnAttente() => _retraits
      .where('statut', isEqualTo: 'en_attente')
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> retraitsEnAttenteParMethode(String methode) => _retraits
      .where('statut', isEqualTo: 'en_attente')
      .where('methode', isEqualTo: methode)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> tousLesRetraits() =>
      _retraits.orderBy('createdAt', descending: true).snapshots();

  // ════════════════════════════════════════════════════
  // HISTORIQUE RETRAITS
  // ════════════════════════════════════════════════════
  Stream<QuerySnapshot> historiqueRetraits() => _retraits
      .where('statut', whereIn: ['paye', 'rejete'])
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot> historiqueRetraitsParMethode(String methode) => _retraits
      .where('statut', whereIn: ['paye', 'rejete'])
      .where('methode', isEqualTo: methode)
      .orderBy('createdAt', descending: true)
      .snapshots();
}