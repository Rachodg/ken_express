import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/payment_service.dart';

class ClientOrdersScreen extends StatelessWidget {
  const ClientOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes commandes'),
        backgroundColor: AppColors.clientPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ── CORRECTION : 'userId' et non 'clientId' ──
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.clientPrimary));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Erreur : ${snap.error}', style: const TextStyle(color: Colors.red)),
            );
          }
          // Tri côté client : du plus récent au plus ancien
          final docs = snap.data?.docs ?? [];
          docs.sort((a, b) {
            final aDate = (a.data() as Map)['createdAt'];
            final bDate = (b.data() as Map)['createdAt'];
            if (aDate == null || bDate == null) return 0;
            if (aDate is int && bDate is int) return bDate.compareTo(aDate);
            return 0;
          });
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Aucune commande pour le moment',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) => _OrderCard(doc: docs[i]),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CARTE D'UNE COMMANDE CLIENT
// ══════════════════════════════════════════════════════════════
class _OrderCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _OrderCard({required this.doc});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _loading = false;

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate());
    if (ts is int) return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));
    return '—';
  }

  ({Color color, String label, IconData icon}) _statutInfo(String status) {
    switch (status) {
      case 'en_attente':   return (color: Colors.grey,   label: 'En attente de paiement',   icon: Icons.hourglass_empty);
      case 'confirmée':    return (color: Colors.blue,   label: 'Paiement confirmé',         icon: Icons.check_circle_outline);
      case 'en_livraison': return (color: Colors.orange, label: 'En cours de livraison',     icon: Icons.delivery_dining);
      case 'livrée':       return (color: Colors.green,  label: 'Livrée',                    icon: Icons.done_all);
      case 'annulée':      return (color: Colors.red,    label: 'Annulée',                   icon: Icons.cancel);
      default:             return (color: Colors.grey,   label: status,                      icon: Icons.receipt_long);
    }
  }

  String _methodeLabel(dynamic methode) {
    switch (methode) {
      case 'orange_money':  return 'Orange Money';
      case 'moov_money':    return 'Moov Money';
      case 'telecel_money': return 'Telecel Money';
      case 'wave':          return 'Wave';
      default:              return methode?.toString() ?? '—';
    }
  }

  ({Color color, IconData icon, String label}) _paiementInfo(String? statut) {
    switch (statut) {
      case 'valide':
        return (color: Colors.green, icon: Icons.check_circle, label: 'Paiement validé ✓');
      case 'rejete':
        return (color: Colors.red, icon: Icons.cancel, label: 'Paiement rejeté');
      case 'en_attente':
        return (color: Colors.orange, icon: Icons.hourglass_bottom, label: 'Paiement en cours de vérification');
      default:
        return (color: Colors.grey, icon: Icons.payment, label: 'Paiement non soumis');
    }
  }

  // ── Confirmer réception ──
  Future<void> _confirmerReception(String commandeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la réception'),
        content: const Text(
          'Confirmez-vous avoir bien reçu votre produit ?\n\n'
              'Cette action est définitive et déclenche le paiement du vendeur.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Oui, j\'ai reçu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await PaymentService().confirmerReceptionCommande(commandeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merci ! Le vendeur a été crédité.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Ouvrir le formulaire de paiement ──
  Future<void> _ouvrirPaiement(String orderId, String uid) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaiementRapideSheet(uid: uid, orderId: orderId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final data = widget.doc.data() as Map<String, dynamic>;
    final status = (data['status'] ?? '').toString();
    final total = (data['total'] ?? 0).toDouble();
    final info = _statutInfo(status);
    final paiement = data['paiement'] as Map<String, dynamic>?;
    final paiementStatut = paiement?['statut'] as String?;
    final paiementMethode = paiement?['methode'] as String?;
    final paiementMotif = paiement?['motifRejet'] as String?;
    final pInfo = _paiementInfo(paiementStatut);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── En-tête ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Commande #${widget.doc.id.substring(0, 6).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: info.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(info.icon, color: info.color, size: 14),
                      const SizedBox(width: 4),
                      Text(info.label,
                          style: TextStyle(color: info.color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Total ──
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text('${total.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.clientPrimary)),
              ]),

              // ── Méthode si paiement soumis ──
              if (paiementMethode != null) ...[
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Paiement', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(_methodeLabel(paiementMethode), style: const TextStyle(fontSize: 13)),
                ]),
              ],

              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Date', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(_formatDate(data['createdAt']), style: const TextStyle(fontSize: 13)),
              ]),

              const SizedBox(height: 12),
              const Divider(height: 4),
              const SizedBox(height: 10),

              // ══════════════════════════════════════════
              // BLOC STATUT PAIEMENT (NOUVEAU)
              // ══════════════════════════════════════════
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pInfo.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pInfo.color.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(pInfo.icon, color: pInfo.color, size: 15),
                    const SizedBox(width: 8),
                    Text(pInfo.label,
                        style: TextStyle(color: pInfo.color, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                  if (paiementStatut == 'rejete' && paiementMotif != null) ...[
                    const SizedBox(height: 4),
                    Text('Motif : $paiementMotif',
                        style: const TextStyle(color: Colors.red, fontSize: 11)),
                  ],
                ]),
              ),
            ]),
          ),

          // ── Bouton : soumettre paiement (si aucun soumis ou rejeté) ──
          if ((paiementStatut == null || paiementStatut == 'rejete') && status == 'en_attente')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _ouvrirPaiement(widget.doc.id, uid),
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: Text(
                    paiementStatut == 'rejete' ? 'Soumettre un nouveau paiement' : 'Soumettre le paiement',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clientPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

          // ── Bouton : confirmer réception ──
          if (status == 'en_livraison')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : () => _confirmerReception(widget.doc.id),
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_loading ? 'Confirmation...' : 'J\'ai reçu mon produit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

          if (status == 'livrée')
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                Icon(Icons.verified, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Text('Réception confirmée — merci !',
                    style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FORMULAIRE DE PAIEMENT RAPIDE (depuis "Mes commandes")
// Identique au _PaiementSheet de cart_screen.dart mais pour
// une seule commande existante.
// ══════════════════════════════════════════════════════════════
class _PaiementRapideSheet extends StatefulWidget {
  final String uid;
  final String orderId;
  const _PaiementRapideSheet({required this.uid, required this.orderId});

  @override
  State<_PaiementRapideSheet> createState() => _PaiementRapideSheetState();
}

class _PaiementRapideSheetState extends State<_PaiementRapideSheet> {
  MethodePaiement? _methodChoisie;
  final _numeroCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _methodes = [
    (methode: MethodePaiement.orangeMoney,  label: 'Orange Money',  color: Color(0xFFFF6600)),
    (methode: MethodePaiement.moovMoney,    label: 'Moov Money',    color: Color(0xFF0066CC)),
    (methode: MethodePaiement.telecelMoney, label: 'Telecel Money', color: Color(0xFFCC0000)),
    (methode: MethodePaiement.wave,         label: 'Wave',          color: Color(0xFF009688)),
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
      // Récupérer le montant depuis la commande
      final orderSnap = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      final montant = ((orderSnap.data() ?? {})['total'] as num?)?.toDouble() ?? 0;

      await PaymentService().soumettreGeneral(
        uid: widget.uid,
        commandeId: widget.orderId,
        montant: montant,
        numeroPaiement: _numeroCtrl.text.trim(),
        referenceTransaction: _refCtrl.text.trim(),
        description: 'Commande KenExpress',
        methode: _methodChoisie!.firestoreKey,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paiement soumis ! En attente de validation.'),
          backgroundColor: Colors.green,
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
            const Text('Soumettre le paiement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Choisissez votre moyen de paiement',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),

            // ── Choix méthode ──
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.8,
              children: _methodes.map((m) {
                final selected = _methodChoisie == m.methode;
                return GestureDetector(
                  onTap: () => setState(() => _methodChoisie = m.methode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected ? m.color : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? m.color : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(m.label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            if (_methodChoisie != null) ...[
              const Text('Numéro utilisé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _numeroCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Ex : 07X XXX XXX',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.clientPrimary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Référence de transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _refCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Ex : TXN123456789',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.clientPrimary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _soumettre,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.clientPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Soumettre', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
