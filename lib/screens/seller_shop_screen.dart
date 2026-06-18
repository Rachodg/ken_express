// ══════════════════════════════════════════════════════════════
// lib/screens/seller_shop_screen.dart
// Page boutique d'un vendeur vue par le CLIENT :
//  - Photo + nom + description (SANS numéro de téléphone)
//  - Localisation sur carte (bouton Google Maps)
//  - Grille de tous ses produits actifs
//  - Bouton "Ajouter au panier" sur chaque produit
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../main.dart';
import 'product_detail_screen.dart';

class SellerShopScreen extends StatelessWidget {
  final String vendeurId;
  final CartService cartService;

  const SellerShopScreen({
    super.key,
    required this.vendeurId,
    required this.cartService,
  });

  // ── Ouvre Google Maps avec les coordonnées GPS ──
  Future<void> _ouvrirCarte(BuildContext context, double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir la carte'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(vendeurId)
            .snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.clientPrimary),
              ),
            );
          }

          final data =
              userSnap.data?.data() as Map<String, dynamic>? ?? {};

          // ── Données boutique — le numéro est volontairement exclu ──
          final prenom = data['prenom'] ?? '';
          final nom = data['nom'] ?? '';
          final nomComplet = '$prenom $nom'.trim();
          final photoUrl = data['photoUrl'] ?? '';
          final adresse = data['adresseBoutique'] ?? data['adresse'] ?? '';
          final localisation = data['localisation'] as Map<String, dynamic>?;
          final lat = (localisation?['latitude'] as num?)?.toDouble();
          final lng = (localisation?['longitude'] as num?)?.toDouble();

          return CustomScrollView(
            slivers: [
              // ══════════════════════════════════════════
              // APP BAR avec photo de la boutique
              // ══════════════════════════════════════════
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.clientPrimary,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fond dégradé
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.clientPrimary,
                              AppColors.clientSecondary
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Photo du vendeur centrée
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: Colors.white24,
                                child: photoUrl.isNotEmpty
                                    ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    width: 92,
                                    height: 92,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                    const Icon(Icons.store,
                                        color: Colors.white,
                                        size: 44),
                                  ),
                                )
                                    : const Icon(Icons.store,
                                    color: Colors.white, size: 44),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              nomComplet.isEmpty
                                  ? 'Boutique KenExpress'
                                  : nomComplet,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified,
                                      color: Colors.white, size: 13),
                                  SizedBox(width: 4),
                                  Text('Vendeur KenExpress',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ══════════════════════════════════════════
              // INFOS BOUTIQUE + LOCALISATION
              // ══════════════════════════════════════════
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // ── Carte localisation ──
                    if (lat != null && lng != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.location_on,
                                  color: AppColors.clientPrimary, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Localisation de la boutique',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            if (adresse.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  adresse,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _ouvrirCarte(context, lat, lng),
                                icon: const Icon(Icons.map_outlined,
                                    color: AppColors.clientSecondary),
                                label: const Text(
                                  'Voir sur Google Maps',
                                  style: TextStyle(
                                      color: AppColors.clientSecondary),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: AppColors.clientSecondary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                    // Pas de localisation enregistrée
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(children: [
                          Icon(Icons.location_off,
                              color: Colors.grey, size: 16),
                          SizedBox(width: 8),
                          Text('Localisation non renseignée',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ]),
                      ),

                    const SizedBox(height: 16),

                    // ── Titre section produits ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        const Icon(Icons.inventory_2_outlined,
                            color: AppColors.clientPrimary, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Produits de la boutique',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Spacer(),
                        // Compteur de produits en temps réel
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('products')
                              .where('vendeurId', isEqualTo: vendeurId)
                              .where('status', isEqualTo: 'actif')
                              .snapshots(),
                          builder: (_, snap) {
                            final count = snap.data?.docs.length ?? 0;
                            return Text(
                              '$count produit${count > 1 ? 's' : ''}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            );
                          },
                        ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // ══════════════════════════════════════════
              // GRILLE DES PRODUITS DU VENDEUR
              // ══════════════════════════════════════════
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('vendeurId', isEqualTo: vendeurId)
                    .where('status', isEqualTo: 'actif')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.clientPrimary),
                      ),
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  final products = docs
                      .map((d) => Product.fromMap(
                      d.data() as Map<String, dynamic>, d.id))
                      .toList();

                  if (products.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Aucun produit disponible',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    sliver: SliverGrid(
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (_, i) => _productCard(context, products[i]),
                        childCount: products.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Carte produit ──
  Widget _productCard(BuildContext context, Product product) {
    return Card(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
              cartService: cartService,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            Expanded(
              child: Stack(
                children: [
                  SizedBox.expand(
                    child: product.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.clientPrimary),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image,
                            color: Colors.grey, size: 40),
                      ),
                    )
                        : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image,
                          color: Colors.grey, size: 40),
                    ),
                  ),
                  // Badge catégorie
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.clientSecondary
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(product.category,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9)),
                    ),
                  ),
                  // Badge promo
                  if (product.isEnPromo && product.promoPercent > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('-${product.promoPercent}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),

            // ── Infos + bouton panier ──
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Prix (avec promo éventuelle)
                  if (product.isEnPromo && product.promoPercent > 0)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(0)} F',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${product.prixActuel.toStringAsFixed(0)} F',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '${product.price.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        color: AppColors.clientPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),

                  const SizedBox(height: 6),

                  // ── Bouton Ajouter au panier ──
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      cartService.add(product);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} ajouté'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: AppColors.clientPrimary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.clientPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_shopping_cart,
                              color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Ajouter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
