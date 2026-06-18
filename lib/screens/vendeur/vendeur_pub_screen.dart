// ══════════════════════════════════════════════════════════════
// lib/screens/vendeur/vendeur_pub_screen.dart
// Écran Publicités — espace VENDEUR
//
// Fonctionnalités :
//   • Liste de toutes les demandes de pub du vendeur connecté
//   • Soumettre une nouvelle demande de pub (choisir un produit)
//   • Voir le statut (en_attente | active | refusee | expiree)
//   • Infos tarifaires (5 000 FCFA / mois)
//   • Explication claire du processus
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/pub_service.dart';
import '../../main.dart'; // AppColors

class VendeurPubScreen extends StatefulWidget {
  const VendeurPubScreen({super.key});

  @override
  State<VendeurPubScreen> createState() => _VendeurPubScreenState();
}

class _VendeurPubScreenState extends State<VendeurPubScreen> {
  static const Color _orange = AppColors.vendeurPrimary;

  // ── Couleur & libellé selon statut ──
  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'active':
        return Colors.green;
      case 'refusee':
        return Colors.red;
      case 'expiree':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _iconeStatut(String statut) {
    switch (statut) {
      case 'active':
        return Icons.check_circle;
      case 'refusee':
        return Icons.cancel;
      case 'expiree':
        return Icons.timer_off;
      default:
        return Icons.hourglass_top;
    }
  }

  String _libelleStatut(String statut) {
    switch (statut) {
      case 'active':
        return 'Active';
      case 'refusee':
        return 'Refusée';
      case 'expiree':
        return 'Expirée';
      default:
        return 'En attente';
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

  // ── Ouvre la bottom‑sheet pour soumettre une nouvelle demande ──
  void _ouvrirFormulaire() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NouvelleDemandeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mes publicités',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Comment ça marche ?',
            onPressed: _showInfoDialog,
          ),
        ],
      ),

      // ── FAB : nouvelle demande ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirFormulaire,
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign),
        label: const Text('Nouvelle pub'),
      ),

      body: Column(
        children: [
          // ── Bandeau tarifaire ──
          _BandeauTarif(orange: _orange),

          // ── Liste des demandes ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: PubService().mesDemandes(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _orange),
                  );
                }

                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Erreur : ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];

                // Tri : en_attente → active → refusee → expiree
                docs.sort((a, b) {
                  const order = {
                    'en_attente': 0,
                    'active': 1,
                    'refusee': 2,
                    'expiree': 3,
                  };
                  final sa = (a.data() as Map)['statut'] ?? '';
                  final sb = (b.data() as Map)['statut'] ?? '';
                  return (order[sa] ?? 9).compareTo(order[sb] ?? 9);
                });

                if (docs.isEmpty) {
                  return _EtatVide(onCta: _ouvrirFormulaire, orange: _orange);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx2, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final statut = data['statut'] ?? 'en_attente';
                    final dateDebut =
                    (data['dateDebut'] as Timestamp?)?.toDate();
                    final dateFin =
                    (data['dateFin'] as Timestamp?)?.toDate();
                    final createdAt =
                    (data['createdAt'] as Timestamp?)?.toDate();
                    final motifRefus = data['motifRefus'] as String?;

                    return _PubCard(
                      data: data,
                      statut: statut,
                      dateDebut: dateDebut,
                      dateFin: dateFin,
                      createdAt: createdAt,
                      motifRefus: motifRefus,
                      couleurStatut: _couleurStatut(statut),
                      iconeStatut: _iconeStatut(statut),
                      libelleStatut: _libelleStatut(statut),
                      fmt: _fmt,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialog explicatif ──
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.campaign, color: _orange),
          const SizedBox(width: 8),
          const Text('Comment ça marche ?'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoStep('1', 'Choisissez un de vos produits à promouvoir.',
                color: _orange),
            const SizedBox(height: 10),
            _infoStep(
              '2',
              'Soumettez une demande de publicité (5 000 FCFA / mois).',
              color: _orange,
            ),
            const SizedBox(height: 10),
            _infoStep(
              '3',
              "L'administrateur valide votre demande après réception du paiement.",
              color: _orange,
            ),
            const SizedBox(height: 10),
            _infoStep(
              '4',
              "Votre produit s'affiche en carrousel sur la page d'accueil des clients pendant 1 mois.",
              color: _orange,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.payments_outlined, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contactez l\'administrateur pour régler le paiement du service publicitaire.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.orange, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Compris', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _infoStep(String num, String texte, {required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(num,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texte,
              style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Bandeau tarifaire en haut de l'écran
// ══════════════════════════════════════════════════════════════
class _BandeauTarif extends StatelessWidget {
  final Color orange;
  const _BandeauTarif({required this.orange});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [orange, Colors.deepOrange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Boostez vos ventes !',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Votre produit affiché en carrousel — 5 000 FCFA / mois',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Carte d'une demande de pub
// ══════════════════════════════════════════════════════════════
class _PubCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String statut;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final DateTime? createdAt;
  final String? motifRefus;
  final Color couleurStatut;
  final IconData iconeStatut;
  final String libelleStatut;
  final String Function(DateTime) fmt;

  const _PubCard({
    required this.data,
    required this.statut,
    required this.dateDebut,
    required this.dateFin,
    required this.createdAt,
    required this.motifRefus,
    required this.couleurStatut,
    required this.iconeStatut,
    required this.libelleStatut,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['productImageUrl'] as String? ?? '';
    final nomProduit = data['productName'] as String? ?? '';
    final description = data['productDescription'] as String? ?? '';
    final prix =
        (data['productPrice'] as num?)?.toStringAsFixed(0) ?? '0';
    final prixService = data['prixService'] ?? 5000;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statut == 'en_attente'
              ? Colors.orange.shade200
              : statut == 'active'
              ? Colors.green.shade200
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── En‑tête coloré (statut) ──
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: couleurStatut.withOpacity(0.1),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(iconeStatut, color: couleurStatut, size: 18),
                const SizedBox(width: 6),
                Text(
                  libelleStatut,
                  style: TextStyle(
                    color: couleurStatut,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    'Demandé le ${fmt(createdAt!)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
          ),

          // ── Corps : image + infos ──
          Row(
            children: [
              // Image
              ClipRRect(
                borderRadius:
                const BorderRadius.only(bottomLeft: Radius.circular(14)),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.image,
                        color: Colors.grey, size: 36),
                  ),
                )
                    : Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.shopping_bag,
                      color: Colors.grey, size: 36),
                ),
              ),

              // Détails
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomProduit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.sell_outlined,
                            size: 13, color: Color(0xFF1E88E5)),
                        const SizedBox(width: 4),
                        Text(
                          '$prix FCFA',
                          style: const TextStyle(
                              color: Color(0xFF1E88E5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.payments_outlined,
                            size: 13, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'Service : $prixService FCFA',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Période d'activité (si active) ──
          if (statut == 'active' &&
              dateDebut != null &&
              dateFin != null) ...[
            const Divider(height: 1),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                const Icon(Icons.date_range,
                    size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  'Diffusion : ${fmt(dateDebut!)} → ${fmt(dateFin!)}',
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],

          // ── Motif de refus ──
          if (statut == 'refusee' &&
              motifRefus != null &&
              motifRefus!.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Motif : $motifRefus',
                      style: const TextStyle(
                          color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Message d'attente ──
          if (statut == 'en_attente') ...[
            const Divider(height: 1),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'En attente de validation par l\'administrateur.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// État vide (aucune demande)
// ══════════════════════════════════════════════════════════════
class _EtatVide extends StatelessWidget {
  final VoidCallback onCta;
  final Color orange;
  const _EtatVide({required this.onCta, required this.orange});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.campaign_outlined,
                  size: 60, color: orange),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucune publicité',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vous n\'avez pas encore soumis de demande de publicité.\n'
                  'Boostez vos ventes en affichant votre produit sur l\'accueil client !',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Créer une publicité'),
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Bottom‑sheet : Nouvelle demande de pub
// Charge les produits du vendeur et laisse le choix
// ══════════════════════════════════════════════════════════════
class _NouvelleDemandeSheet extends StatefulWidget {
  const _NouvelleDemandeSheet();

  @override
  State<_NouvelleDemandeSheet> createState() =>
      _NouvelleDemandeSheetState();
}

class _NouvelleDemandeSheetState extends State<_NouvelleDemandeSheet> {
  static const Color _orange = AppColors.vendeurPrimary;

  String? _selectedProductId;
  String? _selectedProductName;
  String? _selectedImageUrl;
  String? _selectedDescription;
  double _selectedPrice = 0;

  List<Map<String, dynamic>> _produits = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chargerProduits();
  }

  Future<void> _chargerProduits() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('vendeurId', isEqualTo: uid)
          .where('status', isEqualTo: 'actif')
          .get();

      final liste = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': data['name'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'description': data['description'] ?? '',
          'price': (data['price'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _produits = liste;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Erreur : $e';
        });
      }
    }
  }

  Future<void> _soumettre() async {
    if (_selectedProductId == null) {
      setState(() => _error = 'Veuillez sélectionner un produit.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await PubService().demanderPub(
        productId: _selectedProductId!,
        productName: _selectedProductName ?? '',
        productImageUrl: _selectedImageUrl ?? '',
        productDescription: _selectedDescription ?? '',
        productPrice: _selectedPrice,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Demande envoyée ! L\'admin validera sous peu.')),
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erreur : $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Poignée ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Titre ──
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign,
                    color: _orange, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nouvelle publicité',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '5 000 FCFA / mois',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),

            // ── Contenu selon état ──
            if (_loading)
              const Center(
                  child: CircularProgressIndicator(color: _orange))
            else if (_produits.isEmpty)
              _EtatAucunProduit()
            else ...[
                const Text(
                  'Choisissez le produit à promouvoir :',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),

                // ── Liste produits ──
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _produits.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = _produits[i];
                    final selected = _selectedProductId == p['id'];
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedProductId = p['id'];
                        _selectedProductName = p['name'];
                        _selectedImageUrl = p['imageUrl'];
                        _selectedDescription = p['description'];
                        _selectedPrice = (p['price'] as num).toDouble();
                        _error = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.orange.shade50
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? _orange
                                : Colors.grey.shade200,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          // Miniature
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(10)),
                            child: (p['imageUrl'] as String).isNotEmpty
                                ? Image.network(
                              p['imageUrl'],
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: Colors.grey.shade100,
                                child: const Icon(Icons.image,
                                    color: Colors.grey),
                              ),
                            )
                                : Container(
                              width: 64,
                              height: 64,
                              color: Colors.grey.shade100,
                              child: const Icon(Icons.shopping_bag,
                                  color: Colors.grey),
                            ),
                          ),
                          // Infos
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['name'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: selected
                                          ? _orange
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${(p['price'] as num).toStringAsFixed(0)} FCFA',
                                    style: const TextStyle(
                                        color: Color(0xFF1E88E5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Check
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color:
                              selected ? _orange : Colors.grey.shade300,
                              size: 22,
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ── Résumé tarif ──
                if (_selectedProductId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Résumé de votre demande',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        _ligne('Produit', _selectedProductName ?? ''),
                        _ligne('Prix produit',
                            '${_selectedPrice.toStringAsFixed(0)} FCFA'),
                        _ligne('Service pub', '5 000 FCFA / mois'),
                        _ligne('Durée', '1 mois'),
                        _ligne('Statut initial', 'En attente'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Erreur ──
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Bouton soumettre ──
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _soumettre,
                    icon: _submitting
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _submitting
                          ? 'Envoi en cours...'
                          : 'Soumettre la demande',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _ligne(String label, String valeur) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(
        width: 110,
        child: Text(label,
            style:
            const TextStyle(color: Colors.grey, fontSize: 12)),
      ),
      Expanded(
        child: Text(valeur,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
// Aucun produit actif trouvé pour le vendeur
// ══════════════════════════════════════════════════════════════
class _EtatAucunProduit extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucun produit actif',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez d\'abord des produits dans votre boutique\navant de créer une publicité.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PubServiceBanner — Bannière publicitaire affichée sur le
// tableau de bord vendeur (VendeurHomeScreen).
// Redirige vers VendeurPubScreen au tap.
// ══════════════════════════════════════════════════════════════
class PubServiceBanner extends StatelessWidget {
  const PubServiceBanner({super.key});

  static const Color _orange = AppColors.vendeurPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VendeurPubScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6F00), Color(0xFFFFA726)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône megaphone
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),

            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚀 Boostez vos ventes !',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Affichez votre produit sur l\'accueil client — 5 000 FCFA / mois',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Flèche
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}
