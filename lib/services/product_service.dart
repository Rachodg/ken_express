import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class ProductService {
  final _db = FirebaseFirestore.instance;

  // ── Produits visibles clients : status == 'actif' uniquement ──
  // 'category' == 'Promos' -> uniquement les produits en promo validee
  // par l'admin (isEnPromo == true), toutes categories confondues.
  Stream<List<Product>> getProducts({String? category}) {
    Query query = _db
        .collection('products')
        .where('status', isEqualTo: 'actif');
    if (category == 'Promos') {
      query = query.where('isEnPromo', isEqualTo: true);
    } else if (category != null && category != 'Tous') {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((d) => Product.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList());
  }

  // ── Recherche : uniquement produits actifs ──
  Stream<List<Product>> searchProducts(String searchQuery) {
    return _db
        .collection('products')
        .where('status', isEqualTo: 'actif')
        .snapshots()
        .map((snap) => snap.docs
        .map((d) =>
        Product.fromMap(d.data() as Map<String, dynamic>, d.id))
        .where((p) =>
        p.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList());
  }

  // ── Migration : ajouter status 'actif' aux anciens produits ──
  Future<void> migrerProduits() async {
    final snap = await _db.collection('products').get();
    final batch = _db.batch();
    int count = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['status'] == null) {
        batch.update(doc.reference, {'status': 'actif'});
        count++;
      }
    }
    if (count > 0) await batch.commit();
  }

  // ── Activer un produit (admin) ──
  Future<void> activerProduit(String productId) async {
    await _db
        .collection('products')
        .doc(productId)
        .update({'status': 'actif'});
  }

  // ── Bloquer un produit (admin) ──
  Future<void> bloquerProduit(String productId) async {
    await _db
        .collection('products')
        .doc(productId)
        .update({'status': 'bloque'});
  }

  // ── Supprimer un produit (admin) ──
  Future<void> supprimerProduit(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }
}
