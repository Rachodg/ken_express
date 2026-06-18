import 'package:cloud_firestore/cloud_firestore.dart';

class PromotionService {
  final _db = FirebaseFirestore.instance;

  // Appliquer ou retirer une promo sur un produit
  Future<void> setPromo(String productId, int percent) async {
    await _db.collection('products').doc(productId).update({
      'promoPercent': percent,
      'isEnPromo': percent > 0,
    });
  }

  // Calculer le prix après promo
  static double prixPromo(double price, int percent) {
    if (percent <= 0) return price;
    return price * (1 - percent / 100);
  }

  // Stream produits en promo
  Stream<QuerySnapshot> getPromos() {
    return _db
        .collection('products')
        .where('status', isEqualTo: 'actif')
        .where('isEnPromo', isEqualTo: true)
        .snapshots();
  }
}
