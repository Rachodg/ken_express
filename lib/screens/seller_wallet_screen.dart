import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/payment_service.dart';

class SellerWalletScreen extends StatefulWidget {
  const SellerWalletScreen({super.key});

  @override
  State<SellerWalletScreen> createState() => _SellerWalletScreenState();
}

class _SellerWalletScreenState extends State<SellerWalletScreen> {
  // CORRECTION : utilise PaymentService (pas WalletService) pour que
  // demanderRetrait() sauvegarde nomVendeur dans Firestore
  final _service = PaymentService();
  final _montantCtrl = TextEditingController();
  final _numeroCtrl  = TextEditingController();
  String _methodeRetrait = 'orange_money';
  bool _loading = false;

  String get _sellerId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _montantCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _demanderRetrait(double solde) async {
    final montant = double.tryParse(_montantCtrl.text.trim());
    if (montant == null || montant <= 0) {
      _snack('Montant invalide', Colors.red);
      return;
    }
    if (montant > solde) {
      _snack('Solde insuffisant', Colors.red);
      return;
    }
    if (_numeroCtrl.text.trim().isEmpty) {
      _snack('Entrez votre numéro de retrait', Colors.red);
      return;
    }

    // Confirmation avant envoi
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer le retrait'),
        content: Text(
          'Envoyer ${montant.toStringAsFixed(0)} FCFA\n'
              'vers ${_numeroCtrl.text.trim()}\n'
              'via ${_labelMethode(_methodeRetrait)} ?',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _service.demanderRetrait(
        sellerId:      _sellerId,
        montant:       montant,
        methode:       _methodeRetrait,
        numeroRetrait: _numeroCtrl.text.trim(),
      );
      _montantCtrl.clear();
      _numeroCtrl.clear();
      if (mounted) _snack('Demande envoyée ! L\'admin vous transférera sous peu.', Colors.green);
    } catch (e) {
      if (mounted) _snack('Erreur : $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _labelMethode(String m) {
    switch (m) {
      case 'orange_money':  return 'Orange Money';
      case 'moov_money':    return 'Moov Money';
      case 'telecel_money': return 'Telecel Money';
      case 'wave':          return 'Wave';
      default:              return m;
    }
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'paye':   return Colors.green;
      case 'rejete': return Colors.red;
      default:       return Colors.orange;
    }
  }

  String _texteStatut(String statut) {
    switch (statut) {
      case 'paye':   return 'Payé';
      case 'rejete': return 'Rejeté';
      default:       return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mon portefeuille'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _service.soldeVendeur(_sellerId),
        builder: (context, snapshot) {
          final data          = snapshot.data?.data() as Map<String, dynamic>?;
          final solde         = (data?['solde']         as num?)?.toDouble() ?? 0;
          final soldeEnAttente= (data?['soldeEnAttente'] as num?)?.toDouble() ?? 0;
          final soldeBloque   = (data?['soldeBloque']   as num?)?.toDouble() ?? 0;
          final totalGagne    = (data?['totalGagne']    as num?)?.toDouble() ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Carte solde ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${solde.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _miniStat('Commandes en cours', soldeEnAttente,
                            subtitle: 'libéré à réception')),
                        const SizedBox(width: 12),
                        Expanded(child: _miniStat('Retrait en cours', soldeBloque,
                            subtitle: 'en attente admin')),
                      ]),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text('Total gagné : ${totalGagne.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ],
                  ),
                ),

                // ── Explication du flux ──
                if (soldeEnAttente > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Des fonds sont en attente de confirmation de réception par le client.',
                          style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ),

                const SizedBox(height: 24),
                const Text('Demander un retrait',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  'L\'admin vous enverra le montant sur le numéro indiqué.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),

                // ── Formulaire retrait ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Moyen de retrait', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _methodeRetrait,
                        decoration: InputDecoration(
                          filled: true, fillColor: const Color(0xFFFAFAFA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'orange_money',  child: Text('Orange Money')),
                          DropdownMenuItem(value: 'moov_money',    child: Text('Moov Money')),
                          DropdownMenuItem(value: 'telecel_money', child: Text('Telecel Money')),
                          DropdownMenuItem(value: 'wave',          child: Text('Wave')),
                        ],
                        onChanged: (v) => setState(() => _methodeRetrait = v ?? 'orange_money'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _numeroCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: 'Numéro de retrait',
                          hintText: 'Ex: 0700000000',
                          helperText: 'Le numéro sur lequel vous souhaitez recevoir l\'argent',
                          filled: true, fillColor: const Color(0xFFFAFAFA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _montantCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Montant à retirer',
                          hintText: 'Ex: 5000',
                          suffixText: 'FCFA',
                          helperText: 'Solde disponible : ${solde.toStringAsFixed(0)} FCFA',
                          filled: true, fillColor: const Color(0xFFFAFAFA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_loading || solde <= 0) ? null : () => _demanderRetrait(solde),
                          icon: _loading
                              ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.account_balance_wallet_outlined),
                          label: Text(_loading ? 'Envoi...' : 'Demander le retrait'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Historique des retraits',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                // ── Liste des retraits ──
                StreamBuilder<QuerySnapshot>(
                  stream: _service.retraitsVendeur(_sellerId),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('Aucun retrait pour le moment.',
                            style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return Column(
                      children: docs.map((d) {
                        final r      = d.data() as Map<String, dynamic>;
                        final montant = (r['montant'] as num).toDouble();
                        final statut  = r['statut'] as String? ?? 'en_attente';
                        final methode = r['methode'] as String? ?? '';
                        final numero  = r['numeroRetrait'] as String? ?? '—';
                        final motif   = r['motifRejet'] as String?;
                        final color   = _couleurStatut(statut);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${montant.toStringAsFixed(0)} FCFA — ${_labelMethode(methode)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_texteStatut(statut),
                                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ]),
                              const SizedBox(height: 4),
                              Text('Vers : $numero',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              if (motif != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Motif rejet : $motif',
                                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniStat(String label, double valeur, {String? subtitle}) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 2),
        Text('${valeur.toStringAsFixed(0)} FCFA',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        if (subtitle != null)
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    ),
  );
}
