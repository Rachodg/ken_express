import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/pub_service.dart';
import '../../main.dart'; // AppColors

class AdminPubsScreen extends StatelessWidget {
  const AdminPubsScreen({super.key});

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

  void _showActionDialog(BuildContext ctx, String pubId, String statut) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Gérer cette publicité',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (statut == 'en_attente') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await PubService().activerPub(pubId);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Publicité activée !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Activer (paiement reçu)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final motif = await _demanderMotif(ctx);
                    await PubService()
                        .refuserPub(pubId, motif: motif);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Publicité refusée'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('Refuser',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else
              const Text(
                'Cette demande a déjà été traitée.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _demanderMotif(BuildContext ctx) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Motif du refus'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Ex: produit non conforme...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicités vendeurs'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: PubService().toutesLesDemandes(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          // Tri: en_attente en premier
          docs.sort((a, b) {
            final sa = (a.data() as Map)['statut'] ?? '';
            final sb = (b.data() as Map)['statut'] ?? '';
            if (sa == 'en_attente' && sb != 'en_attente') return -1;
            if (sb == 'en_attente' && sa != 'en_attente') return 1;
            return 0;
          });

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aucune demande de publicité',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
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

              return InkWell(
                onTap: () => _showActionDialog(ctx2, doc.id, statut),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statut == 'en_attente'
                          ? Colors.orange.shade200
                          : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(14)),
                        child: data['productImageUrl'] != null &&
                            (data['productImageUrl'] as String)
                                .isNotEmpty
                            ? Image.network(
                          data['productImageUrl'],
                          width: 80,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 90,
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.image,
                                color: Colors.grey),
                          ),
                        )
                            : Container(
                          width: 80,
                          height: 90,
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.image,
                              color: Colors.grey),
                        ),
                      ),
                      // Infos
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['productName'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _couleurStatut(statut)
                                          .withOpacity(0.15),
                                      borderRadius:
                                      BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _libelleStatut(statut),
                                      style: TextStyle(
                                        color: _couleurStatut(statut),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vendeur : ${data['vendeurNom'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Prix : ${(data['productPrice'] as num?)?.toStringAsFixed(0) ?? '0'} F CFA',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E88E5)),
                              ),
                              if (dateDebut != null && dateFin != null)
                                Text(
                                  'Du ${_fmt(dateDebut)} au ${_fmt(dateFin)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.green),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.payments_outlined,
                                      size: 13, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Service : ${data['prixService'] ?? 5000} F/mois',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (statut == 'en_attente')
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(Icons.chevron_right,
                              color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
