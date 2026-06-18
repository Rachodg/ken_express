import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../services/cart_service.dart';
import '../services/message_service.dart';
import '../services/review_service.dart';
import 'chat_screen.dart';
import '../main.dart'; // AppColors

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final CartService cartService;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.cartService,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  bool _isFavorite = false;
  bool _chatLoading = false;
  String? _vendeurName;
  String? _vendeurPhone;
  final _reviewService = ReviewService();
  double _myRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submittingReview = false;
  Review? _myExistingReview;

  @override
  void initState() {
    super.initState();
    _loadVendeurInfo();
    _loadMyReview();
    _loadFavoriteStatus();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // ── Charger l'état favori depuis Firestore ──
  Future<void> _loadFavoriteStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final favoris = List<String>.from(doc.data()?['favoris'] ?? []);
      if (mounted) {
        setState(() => _isFavorite = favoris.contains(widget.product.id));
      }
    } catch (_) {}
  }

  // ── Toggler le favori dans Firestore ──
  Future<void> _toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref =
    FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      if (_isFavorite) {
        await ref.update({
          'favoris': FieldValue.arrayRemove([widget.product.id]),
        });
      } else {
        await ref.update({
          'favoris': FieldValue.arrayUnion([widget.product.id]),
        });
      }
      if (mounted) setState(() => _isFavorite = !_isFavorite);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur favoris : $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadMyReview() async {
    final review = await _reviewService.getUserReview(widget.product.id);
    if (review != null && mounted) {
      setState(() {
        _myExistingReview = review;
        _myRating = review.rating;
        _commentCtrl.text = review.comment;
      });
    }
  }

  Future<void> _submitReview() async {
    if (_myRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une note (etoiles)')),
      );
      return;
    }
    setState(() => _submittingReview = true);
    try {
      await _reviewService.submitReview(
        productId: widget.product.id,
        rating: _myRating,
        comment: _commentCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avis enregistre, merci !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadMyReview();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  Future<void> _loadVendeurInfo() async {
    if (widget.product.vendeurId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.product.vendeurId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          final data = doc.data()!;
          _vendeurName =
              '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
          _vendeurPhone = data['telephone'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _openChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (widget.product.vendeurId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vendeur non disponible'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _chatLoading = true);
    try {
      final convId = await MessageService().getOrCreateConversation(
        acheteurId: uid,
        vendeurId: widget.product.vendeurId,
        productId: widget.product.id,
        productName: widget.product.name,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            convId: convId,
            otherUserName: _vendeurName ?? 'Vendeur',
            productName: widget.product.name,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erreur ouverture chat'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  void _addToCart() {
    for (int i = 0; i < _quantity; i++) {
      widget.cartService.add(widget.product);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$_quantity × ${widget.product.name} ajouté au panier'),
        backgroundColor: AppColors.clientPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Voir panier',
          textColor: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // ── AppBar avec image ──
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.clientPrimary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red.shade300 : Colors.white,
                ),
                onPressed: _toggleFavorite, // ✅ écrit dans Firestore
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image produit
                  product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.clientPrimary),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image,
                          size: 80, color: Colors.grey),
                    ),
                  )
                      : Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image,
                        size: 80, color: Colors.grey),
                  ),
                  // Dégradé bas
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  // Badge catégorie
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.clientSecondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.category,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (product.isEnPromo && product.promoPercent > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '-${product.promoPercent}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        if (product.recommande) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Recommande',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenu ──
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Carte principale ──
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom + prix
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (product.isEnPromo && product.promoPercent > 0)
                                Text(
                                  '${product.price.toStringAsFixed(0)} FCFA',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                '${product.prixActuel.toStringAsFixed(0)} FCFA',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: product.isEnPromo &&
                                      product.promoPercent > 0
                                      ? Colors.red
                                      : AppColors.clientPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Note + ventes (en direct via Firestore)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('products')
                            .doc(product.id)
                            .snapshots(),
                        builder: (context, snap) {
                          final data = snap.data?.data()
                          as Map<String, dynamic>?;
                          final rating =
                              (data?['rating'] as num?)?.toDouble() ??
                                  product.rating;
                          final reviewCount =
                              (data?['reviewCount'] as num?)?.toInt() ??
                                  product.reviewCount;

                          return Row(
                            children: [
                              ...List.generate(5, (i) {
                                return Icon(
                                  i < rating.floor()
                                      ? Icons.star
                                      : (i < rating
                                      ? Icons.star_half
                                      : Icons.star_border),
                                  color: Colors.amber,
                                  size: 18,
                                );
                              }),
                              const SizedBox(width: 6),
                              Text(
                                '$rating',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              if (reviewCount > 0)
                                Text(
                                  ' ($reviewCount avis)',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              const SizedBox(width: 16),
                              const Icon(Icons.shopping_bag_outlined,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              const Text('Disponible',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ── Description ──
                if (product.description.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Description',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          product.description,
                          style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Avis & notes ──
                _buildReviewsSection(),

                const SizedBox(height: 16),

                // ── Vendeur ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                        AppColors.clientSecondary.withValues(alpha: 0.15),
                        child: const Icon(Icons.store,
                            color: AppColors.clientSecondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _vendeurName ?? 'Chargement...',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.verified,
                                  color: AppColors.clientSecondary, size: 14),
                              const SizedBox(width: 4),
                              const Text('Vendeur KenExpress',
                                  style: TextStyle(
                                      color: AppColors.clientSecondary,
                                      fontSize: 12)),
                            ]),
                          ],
                        ),
                      ),
                      // Bouton chat
                      GestureDetector(
                        onTap: _chatLoading ? null : _openChat,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.clientSecondary
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: _chatLoading
                              ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.clientSecondary))
                              : const Icon(Icons.chat,
                              color: AppColors.clientSecondary, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bouton appel
                      if (_vendeurPhone != null && _vendeurPhone!.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Appeler : $_vendeurPhone'),
                                backgroundColor: AppColors.clientPrimary,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                              AppColors.clientPrimary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone,
                                color: AppColors.clientPrimary, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Quantité ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quantité',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          // Moins
                          GestureDetector(
                            onTap: () {
                              if (_quantity > 1) {
                                setState(() => _quantity--);
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _quantity > 1
                                    ? AppColors.clientPrimary
                                    .withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.remove,
                                  color: _quantity > 1
                                      ? AppColors.clientPrimary
                                      : Colors.grey,
                                  size: 18),
                            ),
                          ),
                          // Nombre
                          SizedBox(
                            width: 48,
                            child: Center(
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          // Plus
                          GestureDetector(
                            onTap: () => setState(() => _quantity++),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.clientPrimary
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add,
                                  color: AppColors.clientPrimary, size: 18),
                            ),
                          ),
                        ],
                      ),
                      // Sous-total
                      Text(
                        '${(product.prixActuel * _quantity).toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.clientPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Espace pour le bouton bas
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // ── Bouton bas fixe ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            // Bouton chat rapide
            GestureDetector(
              onTap: _chatLoading ? null : _openChat,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.clientSecondary, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.chat_outlined,
                    color: AppColors.clientSecondary),
              ),
            ),
            const SizedBox(width: 12),
            // Bouton ajouter au panier
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _addToCart,
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white),
                  label: Text(
                    'Ajouter au panier · ${(product.prixActuel * _quantity).toStringAsFixed(0)} FCFA',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clientPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carte: Avis & notes ──
  Widget _buildReviewsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Avis clients',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // ── Formulaire pour laisser/modifier son avis ──
          _buildMyReviewForm(),

          const Divider(height: 28),

          // ── Liste des avis ──
          StreamBuilder<List<Review>>(
            stream: _reviewService.getReviews(widget.product.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.clientPrimary)),
                );
              }
              final reviews = snap.data ?? [];
              if (reviews.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                        'Aucun avis pour le moment. Soyez le premier !',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                );
              }
              return Column(
                children: reviews.map((r) => _reviewTile(r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Formulaire: choisir les etoiles + laisser un commentaire ──
  Widget _buildMyReviewForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _myExistingReview != null ? 'Modifier mon avis' : 'Laisser un avis',
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final starValue = i + 1;
            return GestureDetector(
              onTap: () => setState(() => _myRating = starValue.toDouble()),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  starValue <= _myRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 30,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Votre commentaire (optionnel)...',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submittingReview ? null : _submitReview,
            icon: _submittingReview
                ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, color: Colors.white, size: 18),
            label: Text(
              _myExistingReview != null
                  ? 'Mettre a jour mon avis'
                  : 'Publier mon avis',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.clientPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Affichage d'un avis ──
  Widget _reviewTile(Review review) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isMine = review.userId == uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine
            ? AppColors.clientPrimary.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMine
              ? AppColors.clientPrimary.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                AppColors.clientSecondary.withValues(alpha: 0.15),
                backgroundImage: review.userPhoto.isNotEmpty
                    ? NetworkImage(review.userPhoto)
                    : null,
                child: review.userPhoto.isEmpty
                    ? const Icon(Icons.person,
                    color: AppColors.clientSecondary, size: 16)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMine ? '${review.userName} (Vous)' : review.userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < review.rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(review.createdAt),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
