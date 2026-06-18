// ══════════════════════════════════════════════════════════════
// lib/screens/products_screen.dart  — MODIFIÉ
// Ajout : PubCarousel affiché en haut de l'écran boutique client
// Ajout : icône boutique 🏪 sur chaque carte produit →
//         ouvre SellerShopScreen (produits + localisation sans numéro)
// ══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart';
import '../services/message_service.dart';
import '../main.dart';
import 'chat_screen.dart';
import 'product_detail_screen.dart';
import 'seller_shop_screen.dart';
import '../widgets/pub_carousel.dart'; // ← AJOUT : carrousel de publicités

class ProductsScreen extends StatefulWidget {
  final CartService cartService;
  const ProductsScreen({super.key, required this.cartService});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _productService = ProductService();
  String _selectedCategory = 'Tous';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final _categories = [
    'Tous',
    'Promos',
    'Telephones',
    'Mode',
    'Aliments',
    'Electronique',
    'Véhicules',
  ];

  bool get _isPromos => _selectedCategory == 'Promos';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filtrer(List<Product> products) {
    if (_searchQuery.isEmpty) return products;
    final q = _searchQuery.toLowerCase();
    return products
        .where((p) =>
    p.name.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q))
        .toList();
  }

  Stream<List<Product>> _streamPromos() {
    return FirebaseFirestore.instance
        .collection('products')
        .where('isEnPromo', isEqualTo: true)
        .where('promoValidee', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) =>
        Product.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Boutique'),
        backgroundColor: AppColors.clientPrimary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // ── Barre de recherche ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                hintStyle:
                const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Filtres catégories ──
          Container(
            color: Colors.white,
            child: SizedBox(
              height: 46,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = cat == _selectedCategory;
                  final isPromoTab = cat == 'Promos';
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding:
                      const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? (isPromoTab
                            ? Colors.red
                            : AppColors.clientPrimary)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? (isPromoTab
                              ? Colors.red
                              : AppColors.clientPrimary)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPromoTab) ...[
                              Text('🔥',
                                  style: TextStyle(
                                      fontSize: selected ? 13 : 12)),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              isPromoTab ? 'Promos' : cat,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : (isPromoTab
                                    ? Colors.red
                                    : Colors.grey.shade700),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Contenu ──
          Expanded(
            child: _isPromos ? _buildPromosView() : _buildNormalView(),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // VUE NORMALE — avec PubCarousel en haut ← MODIFIÉ
  // ════════════════════════════════════════════
  Widget _buildNormalView() {
    return StreamBuilder<List<Product>>(
      stream: _productService.getProducts(category: _selectedCategory),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.clientPrimary));
        }
        final products = _filtrer(snap.data ?? []);

        if (products.isEmpty) {
          return ListView(
            children: [
              // ── Carrousel publicités (même si pas de produits) ──
              PubCarousel(cartService: widget.cartService),

              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Aucun résultat pour "$_searchQuery"'
                            : 'Aucun produit disponible',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // ListView parent pour combiner le carousel + la grille
        return ListView(
          children: [
            // ── Carrousel de publicités ──
            PubCarousel(cartService: widget.cartService), // ← AJOUT

            // ── Grille de produits ──
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) => _productCard(products[i]),
            ),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════
  // VUE PROMOS
  // ════════════════════════════════════════════
  Widget _buildPromosView() {
    return StreamBuilder<List<Product>>(
      stream: _streamPromos(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.red));
        }
        final products = _filtrer(snap.data ?? []);
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                const Text('Aucune promotion en cours',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                const Text('Revenez bientôt pour les bons plans !',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFFF6F00)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Offres du moment',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(
                          '${products.length} produit${products.length > 1 ? 's' : ''} en promotion',
                          style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ]),
                ),
              ]),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => _promoCard(products[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════
  // CARTE NORMALE — avec icône boutique
  // ════════════════════════════════════════════
  Widget _productCard(Product product) {
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
              cartService: widget.cartService,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14)),
                    child: product.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.clientPrimary)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image,
                            size: 50, color: Colors.grey),
                      ),
                    )
                        : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image,
                            size: 50, color: Colors.grey)),
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
                  // Badge recommandé
                  if (product.recommande)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 10),
                            SizedBox(width: 3),
                            Text('Recommandé',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  if (product.isEnPromo && product.promoPercent > 0)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${product.price.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 4),
                        Text(
                            '${product.prixActuel.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    )
                  else
                    Text('${product.price.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                            color: AppColors.clientPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  const SizedBox(height: 4),

                  // ── Ligne d'actions : note | chat | boutique | panier ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.star, color: Colors.amber, size: 13),
                        Text(' ${product.rating}',
                            style: const TextStyle(fontSize: 11)),
                      ]),
                      Row(children: [
                        // Bouton Chat
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final uid =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null ||
                                product.vendeurId.isEmpty) return;
                            try {
                              final convId = await MessageService()
                                  .getOrCreateConversation(
                                acheteurId: uid,
                                vendeurId: product.vendeurId,
                                productId: product.id,
                                productName: product.name,
                              );
                              if (!context.mounted) return;
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      convId: convId,
                                      otherUserName: 'Vendeur',
                                      productName: product.name,
                                    ),
                                  ));
                            } catch (_) {}
                          },
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.clientSecondary
                                .withValues(alpha: 0.15),
                            child: const Icon(Icons.chat,
                                color: AppColors.clientSecondary, size: 14),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Bouton Boutique
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (product.vendeurId.isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SellerShopScreen(
                                  vendeurId: product.vendeurId,
                                  cartService: widget.cartService,
                                ),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor:
                            Colors.orange.withValues(alpha: 0.15),
                            child: const Icon(Icons.store,
                                color: Colors.orange, size: 14),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Bouton Panier
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            widget.cartService.add(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} ajouté'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: AppColors.clientPrimary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.clientPrimary
                                .withValues(alpha: 0.15),
                            child: const Icon(Icons.add_shopping_cart,
                                color: AppColors.clientPrimary, size: 14),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // CARTE PROMO — avec icône boutique
  // ════════════════════════════════════════════
  Widget _promoCard(Product product) {
    final economie = product.price - product.prixActuel;
    return Card(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
              cartService: widget.cartService,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                                color: Colors.red)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image,
                            size: 50, color: Colors.grey),
                      ),
                    )
                        : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image,
                            size: 50, color: Colors.grey)),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12)),
                      ),
                      child: Text('-${product.promoPercent}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(product.category,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${product.price.toStringAsFixed(0)} F',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 5),
                      Text('${product.prixActuel.toStringAsFixed(0)} F',
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  Text('Économie : ${economie.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),

                  // ── Boutons : boutique + panier ──
                  Row(children: [
                    // Bouton boutique
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (product.vendeurId.isEmpty) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerShopScreen(
                                vendeurId: product.vendeurId,
                                cartService: widget.cartService,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store,
                                  color: Colors.orange, size: 13),
                              SizedBox(width: 3),
                              Text('Boutique',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Bouton panier
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          widget.cartService.add(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} ajouté'),
                              duration: const Duration(seconds: 1),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_shopping_cart,
                                  color: Colors.white, size: 13),
                              SizedBox(width: 4),
                              Text('Ajouter',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}