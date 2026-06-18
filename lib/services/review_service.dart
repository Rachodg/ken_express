import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review.dart';

class ReviewService {
  final _db = FirebaseFirestore.instance;

  // ── Avis d'un produit, du plus recent au plus ancien ──
  Stream<List<Review>> getReviews(String productId) {
    return _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => Review.fromMap(d.data(), d.id)).toList());
  }

  // ── Verifie si l'utilisateur courant a deja laisse un avis ──
  Future<Review?> getUserReview(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return Review.fromMap(doc.data()!, doc.id);
  }

  // ── Ajouter ou modifier son avis (1 avis par utilisateur, doc id = uid) ──
  Future<void> submitReview({
    required String productId,
    required double rating,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Recuperer le nom de l'utilisateur
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final userName =
    '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}'.trim();
    final userPhoto = userData['photoUrl'] ?? '';

    final reviewRef = _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(user.uid);

    await reviewRef.set({
      'userId': user.uid,
      'userName': userName.isEmpty ? 'Utilisateur' : userName,
      'userPhoto': userPhoto,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.now(),
    });

    await _updateProductRating(productId);
  }

  Future<void> deleteReview(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(uid)
        .delete();
    await _updateProductRating(productId);
  }

  // ── Recalcule la note moyenne du produit ──
  Future<void> _updateProductRating(String productId) async {
    final snap = await _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .get();

    if (snap.docs.isEmpty) {
      await _db.collection('products').doc(productId).update({
        'rating': 0.0,
        'reviewCount': 0,
      });
      return;
    }

    double sum = 0;
    for (final doc in snap.docs) {
      sum += (doc.data()['rating'] as num?)?.toDouble() ?? 0;
    }
    final avg = sum / snap.docs.length;

    await _db.collection('products').doc(productId).update({
      'rating': double.parse(avg.toStringAsFixed(1)),
      'reviewCount': snap.docs.length,
    });
  }
}