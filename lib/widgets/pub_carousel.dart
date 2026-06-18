// ══════════════════════════════════════════════════════════════
// lib/widgets/pub_carousel.dart
// Carrousel de publicités défilantes (10s/pub) — écran client
// ✅ Corrections :
//   - Timer.periodic propre (plus de Future.delayed récursif)
//   - StreamSubscription annulée dans dispose()
//   - Pause automatique au toucher, reprise après 3s
//   - Swipe manuel avec reprise auto
//   - Compteur de pub (ex: 1 / 3)
//   - Bouton "Voir le produit"
//   - Design carte avec ombre prononcée
// ══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/pub_service.dart';
import '../services/cart_service.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';

class PubCarousel extends StatefulWidget {
  final CartService cartService;
  const PubCarousel({super.key, required this.cartService});

  @override
  State<PubCarousel> createState() => _PubCarouselState();
}

class _PubCarouselState extends State<PubCarousel> {
  final PageController _ctrl = PageController();
  int _currentIndex = 0;
  List<Map<String, dynamic>> _pubs = [];
  bool _loading = true;
  bool _paused = false;

  Timer? _autoTimer;       // Timer du défilement automatique
  Timer? _resumeTimer;     // Timer de reprise après pause tactile
  StreamSubscription? _sub; // Subscription Firestore

  // ── Durées ──
  static const _autoDuration   = Duration(seconds: 10);
  static const _resumeDelay    = Duration(seconds: 3);
  static const _scrollDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _listenPubs();
  }

  // ── Écoute Firestore ──
  void _listenPubs() {
    _sub = PubService().pubsActives().listen((snap) {
      if (!mounted) return;
      final now = DateTime.now();
      final liste = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .where((p) {
        final dateFin = (p['dateFin'] as Timestamp?)?.toDate();
        return dateFin == null || dateFin.isAfter(now);
      }).toList();

      setState(() {
        _pubs  = liste;
        _loading = false;
      });

      // Relancer le timer proprement à chaque mise à jour
      _stopAutoScroll();
      if (liste.length > 1) _startAutoScroll();
    });
  }

  // ── Défilement auto ──
  void _startAutoScroll() {
    _autoTimer = Timer.periodic(_autoDuration, (_) {
      if (!mounted || _pubs.isEmpty || _paused) return;
      final next = (_currentIndex + 1) % _pubs.length;
      _ctrl.animateToPage(next,
          duration: _scrollDuration, curve: Curves.easeInOut);
    });
  }

  void _stopAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  // ── Pause au toucher ──
  void _onTouchDown() {
    if (_pubs.length <= 1) return;
    _resumeTimer?.cancel();
    setState(() => _paused = true);
  }

  // ── Reprise 3s après le lâcher ──
  void _onTouchUp() {
    if (_pubs.length <= 1) return;
    _resumeTimer = Timer(_resumeDelay, () {
      if (!mounted) return;
      setState(() => _paused = false);
    });
  }

  // ── Ouvre la page produit ──
  void _ouvrirProduit(BuildContext context, Map<String, dynamic> pub) {
    final product = Product(
      id: pub['productId'] ?? '',
      name: pub['productName'] ?? '',
      description: pub['productDescription'] ?? '',
      price: (pub['productPrice'] as num?)?.toDouble() ?? 0.0,
      imageUrl: pub['productImageUrl'] ?? '',
      category: '',
      vendeurId: pub['vendeurId'] ?? '',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          cartService: widget.cartService,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _resumeTimer?.cancel();
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 210,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_pubs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête : titre + compteur ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.campaign, color: Color(0xFFE53935), size: 20),
              const SizedBox(width: 6),
              const Text(
                'Publicités',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE53935),
                ),
              ),
              const Spacer(),
              // ── Compteur (ex: 1 / 3) ──
              if (_pubs.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_pubs.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ),
              // ── Indicateur pause ──
              if (_paused) ...[
                const SizedBox(width: 8),
                const Icon(Icons.pause_circle_outline,
                    size: 16, color: Colors.grey),
              ]
            ],
          ),
        ),

        // ── Carrousel ──
        SizedBox(
          height: 215,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _pubs.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (ctx, i) {
              final pub = _pubs[i];
              return GestureDetector(
                onTapDown: (_) => _onTouchDown(),
                onTapUp: (_) => _onTouchUp(),
                onTapCancel: _onTouchUp,
                onTap: () => _ouvrirProduit(ctx, pub),
                child: _PubCard(
                  pub: pub,
                  onVoirProduit: () => _ouvrirProduit(ctx, pub),
                ),
              );
            },
          ),
        ),

        // ── Indicateurs de points + barre de progression ──
        if (_pubs.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pubs.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentIndex == i ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _currentIndex == i
                      ? const Color(0xFFE53935)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ProgressBar(
              key: ValueKey('${_currentIndex}_${_paused}'),
              paused: _paused,
            ),
          ),
        ],

        const SizedBox(height: 12),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ── Carte individuelle de pub — Style carte à ombre prononcée ──
// ══════════════════════════════════════════════════════════════
class _PubCard extends StatelessWidget {
  final Map<String, dynamic> pub;
  final VoidCallback onVoirProduit;

  const _PubCard({required this.pub, required this.onVoirProduit});

  @override
  Widget build(BuildContext context) {
    final imageUrl = pub['productImageUrl'] as String? ?? '';
    final hasImage = imageUrl.isNotEmpty;
    final prix = (pub['productPrice'] as num?)?.toStringAsFixed(0) ?? '0';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // ── Ombre prononcée ──
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: const Color(0xFFE53935).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            // ── Image à gauche ──
            SizedBox(
              width: 130,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  hasImage
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageFallback(),
                  )
                      : _imageFallback(),

                  // Badge PUB
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: const Text(
                        'PUB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Infos à droite ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nom du produit
                    Text(
                      pub['productName'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Description
                    Text(
                      pub['productDescription'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),

                    const Spacer(),

                    // Prix
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF1E88E5).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$prix FCFA',
                        style: const TextStyle(
                          color: Color(0xFF1E88E5),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Bouton "Voir le produit" ──
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: onVoirProduit,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: const Text(
                          'Voir le produit',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() => Container(
    color: Colors.grey.shade100,
    child: const Center(
      child: Icon(Icons.shopping_bag_outlined,
          size: 44, color: Colors.grey),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// ── Barre de progression 10s avec support pause ──
// ══════════════════════════════════════════════════════════════
class _ProgressBar extends StatefulWidget {
  final bool paused;
  const _ProgressBar({super.key, required this.paused});

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward();
  }

  @override
  void didUpdateWidget(_ProgressBar old) {
    super.didUpdateWidget(old);
    if (widget.paused && !old.paused) {
      _anim.stop();
    } else if (!widget.paused && old.paused) {
      _anim.forward();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _anim.value,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
          minHeight: 4,
        ),
      ),
    );
  }
}