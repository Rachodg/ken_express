// ══════════════════════════════════════════════════════════════
// cart_screen.dart  —  Panier scrollable + mode livraison + paiement
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/payment_service.dart';

class CartScreen extends StatefulWidget {
  final CartService cartService;
  final VoidCallback onOrderPlaced;

  const CartScreen({super.key, required this.cartService, required this.onOrderPlaced});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addressCtrl = TextEditingController();
  final _orderService = OrderService();
  bool _loading = false;
  bool _avecLivraison = true; // true = livraison, false = retrait sur place

  static const double _fraisLivraison = 1000;

  double get _totalFinal =>
      widget.cartService.total + (_avecLivraison ? _fraisLivraison : 0);

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_avecLivraison && _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer une adresse de livraison')));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final address = _avecLivraison
          ? _addressCtrl.text.trim()
          : 'Retrait sur place';

      final orderIds = await _orderService.placeOrderAndReturnIds(
        userId: user.uid,
        items: widget.cartService.items.toList(),
        address: address,
      );

      widget.cartService.clear();
      widget.onOrderPlaced();
      _addressCtrl.clear();
      setState(() {});

      if (!mounted) return;

      await _showPaiementSheet(user.uid, orderIds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPaiementSheet(String uid, List<String> orderIds) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaiementSheet(uid: uid, orderIds: orderIds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.cartService.items;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Panier (${widget.cartService.count})'),
        backgroundColor: const Color(0xFF0F8B8D),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () {
                widget.cartService.clear();
                setState(() {});
              },
              child: const Text('Vider', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),

      // ── Corps entièrement scrollable ──
      body: items.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Votre panier est vide',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 8),
            Text('Ajoutez des produits depuis la boutique',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── SECTION 1 : Articles du panier ──
            _sectionTitre('🛒 Mes articles'),
            const SizedBox(height: 8),
            ...items.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Photo produit
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.product.imageUrl.isNotEmpty
                          ? Image.network(
                        item.product.imageUrl,
                        width: 52, height: 52, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _iconeProduit(),
                      )
                          : _iconeProduit(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.product.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('${item.product.prixActuel.toStringAsFixed(0)} FCFA/unité',
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Quantité
                    Row(
                      children: [
                        _boutonQte(
                          icon: Icons.remove_circle_outline,
                          onTap: () => setState(() =>
                              widget.cartService.decreaseQuantity(item.product.id)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('${item.quantity}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        _boutonQte(
                          icon: Icons.add_circle_outline,
                          onTap: () =>
                              setState(() => widget.cartService.add(item.product)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text('${item.total.toStringAsFixed(0)}\nFCFA',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F8B8D),
                            fontSize: 12)),
                  ],
                ),
              ),
            )),

            const SizedBox(height: 20),

            // ── SECTION 2 : Mode de réception ──
            _sectionTitre('📦 Mode de réception'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _carteMode(
                    selected: _avecLivraison,
                    icon: Icons.electric_moped,
                    label: 'Avec livraison',
                    sousTitre: '+1 000 FCFA',
                    onTap: () => setState(() => _avecLivraison = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _carteMode(
                    selected: !_avecLivraison,
                    icon: Icons.store,
                    label: 'Sans livraison',
                    sousTitre: 'Retrait sur place',
                    onTap: () => setState(() => _avecLivraison = false),
                  ),
                ),
              ],
            ),

            // ── Adresse (si livraison choisie) ──
            if (_avecLivraison) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Adresse de livraison (quartier, rue...)',
                  prefixIcon:
                  const Icon(Icons.location_on, color: Color(0xFF0F8B8D)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                      const BorderSide(color: Color(0xFFDDDDDD))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                    const BorderSide(color: Color(0xFF0F8B8D), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Conseil adresse
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb, color: Color(0xFFFFA726), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Conseil : Choisissez un lieu connu et facilement repérable, '
                            'proche de votre position (ex : un marché, une école, une mosquée…). '
                            'Cela facilite la livraison et réduit les délais.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B5E00),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── SECTION 3 : Récapitulatif + bouton commander ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ],
              ),
              child: Column(
                children: [
                  // Sous-total articles
                  _ligneRecap(
                    label: 'Sous-total (${widget.cartService.count} articles)',
                    valeur:
                    '${widget.cartService.total.toStringAsFixed(0)} FCFA',
                  ),
                  if (_avecLivraison) ...[
                    const SizedBox(height: 6),
                    _ligneRecap(
                        label: 'Frais de livraison',
                        valeur: '+1 000 FCFA',
                        couleurValeur: Colors.orange),
                  ],
                  const Divider(height: 20),
                  // Total final
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        '${_totalFinal.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F8B8D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Bouton commander
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _placeOrder,
                      icon: _loading
                          ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline,
                          color: Colors.white),
                      label: Text(
                        _loading ? 'Traitement...' : 'Passer la commande',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F8B8D),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Widgets helpers ──

  Widget _sectionTitre(String titre) => Text(
    titre,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
  );

  Widget _iconeProduit() => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: Colors.teal.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.shopping_bag, color: Color(0xFF0F8B8D)),
  );

  Widget _boutonQte({required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: const Color(0xFF0F8B8D), size: 28),
      );

  Widget _carteMode({
    required bool selected,
    required IconData icon,
    required String label,
    required String sousTitre,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F8B8D) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF0F8B8D) : const Color(0xFFDDDDDD),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                  color: const Color(0xFF0F8B8D).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: selected ? Colors.white : Colors.grey),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: selected ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                sousTitre,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white70 : Colors.grey),
              ),
            ],
          ),
        ),
      );

  Widget _ligneRecap(
      {required String label, required String valeur, Color? couleurValeur}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(valeur,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: couleurValeur ?? Colors.black87)),
        ],
      );
}

// ══════════════════════════════════════════════════════════════
// BOTTOMSHEET : Choix du moyen de paiement (inchangé)
// ══════════════════════════════════════════════════════════════
class _PaiementSheet extends StatefulWidget {
  final String uid;
  final List<String> orderIds;

  const _PaiementSheet({required this.uid, required this.orderIds});

  @override
  State<_PaiementSheet> createState() => _PaiementSheetState();
}

class _PaiementSheetState extends State<_PaiementSheet> {
  MethodePaiement? _methodChoisie;
  final _numeroCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _methodes = [
    (methode: MethodePaiement.orangeMoney,  label: 'Orange Money',  color: Color(0xFFFF6600), icon: Icons.phone_android),
    (methode: MethodePaiement.moovMoney,    label: 'Moov Money',    color: Color(0xFF0066CC), icon: Icons.phone_android),
    (methode: MethodePaiement.telecelMoney, label: 'Telecel Money', color: Color(0xFFCC0000), icon: Icons.phone_android),
    (methode: MethodePaiement.wave,         label: 'Wave',          color: Color(0xFF009688), icon: Icons.waves),
  ];

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    if (_methodChoisie == null) {
      setState(() => _error = 'Choisissez un moyen de paiement');
      return;
    }
    if (_numeroCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Entrez votre numéro de téléphone utilisé');
      return;
    }
    if (_refCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Entrez la référence de transaction');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      for (final orderId in widget.orderIds) {
        final orderSnap = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get();
        final montant =
            ((orderSnap.data() ?? {})['total'] as num?)?.toDouble() ?? 0;

        await PaymentService().soumettreGeneral(
          uid: widget.uid,
          commandeId: orderId,
          montant: montant,
          numeroPaiement: _numeroCtrl.text.trim(),
          referenceTransaction: _refCtrl.text.trim(),
          description: 'Commande KenExpress',
          methode: _methodChoisie!.firestoreKey,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Paiement soumis !'),
          ]),
          content: const Text(
            'Votre paiement a été soumis et est en attente de validation par notre équipe.\n\n'
                'Vous recevrez une notification dès que votre paiement sera confirmé.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F8B8D)),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F8B8D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payment, color: Color(0xFF0F8B8D)),
              ),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Paiement',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Choisissez votre moyen de paiement',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 20),

            const Text('Moyen de paiement',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.5,
              children: _methodes.map((m) {
                final isSelected = _methodChoisie == m.methode;
                return GestureDetector(
                  onTap: () => setState(() => _methodChoisie = m.methode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? m.color.withValues(alpha: 0.12)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? m.color : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(m.icon, color: m.color, size: 18),
                        const SizedBox(width: 6),
                        Text(m.label,
                            style: TextStyle(
                                color: m.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Numéro de téléphone
            const Text('Numéro utilisé pour le paiement',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _numeroCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Ex: 70 XX XX XX',
                prefixIcon:
                const Icon(Icons.phone, color: Color(0xFF0F8B8D)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: Color(0xFF0F8B8D), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Référence transaction
            const Text('Référence de transaction',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _refCtrl,
              decoration: InputDecoration(
                hintText: 'Ex: TXN123456789',
                prefixIcon: const Icon(Icons.tag, color: Color(0xFF0F8B8D)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: Color(0xFF0F8B8D), width: 2),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _soumettre,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F8B8D),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirmer le paiement',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}