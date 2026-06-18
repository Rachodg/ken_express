import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vendeur_pub_screen.dart'; // ← AJOUT

class VendeurHomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  const VendeurHomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          final data = userSnap.data?.data() as Map<String, dynamic>? ?? {};
          final prenom = data['prenom'] ?? '';
          final nom = data['nom'] ?? '';
          final photoUrl = data['photoUrl'] ?? '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header dégradé orange ──
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6F00), Color(0xFFFFA726)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white24,
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty
                              ? const Icon(Icons.store, color: Colors.white, size: 26)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bonjour 👋',
                                style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Text('$prenom $nom',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.store, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text('Vendeur KenExpress',
                                    style: TextStyle(color: Colors.white, fontSize: 11)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ══════════════════════════════════════════
                // ── BANNIÈRE PUBLICITÉ (AJOUT) ──
                // ══════════════════════════════════════════
                const PubServiceBanner(),

                const SizedBox(height: 4),

                // ── Stats 4 cases ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Statistiques',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _statCard(uid, 'Produits', Icons.inventory_2,
                            const Color(0xFF1E88E5), 'products')),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard(uid, 'Commandes', Icons.receipt_long,
                            Colors.green, 'orders')),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _revenueCard(uid)),
                        const SizedBox(width: 10),
                        Expanded(child: _pendingCard(uid)),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Dernières commandes ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dernières commandes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => onNavigate(2),
                        child: const Text('Voir tout',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                _recentOrders(uid),

                const SizedBox(height: 20),

                // ── Actions rapides ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Actions rapides',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8)
                          ],
                        ),
                        child: Column(children: [
                          _actionTile(
                            icon: Icons.add_box_outlined,
                            color: Colors.orange,
                            title: 'Publier un nouveau produit',
                            subtitle: 'Ajouter un article à votre boutique',
                            onTap: () => onNavigate(1),
                          ),
                          _divider(),
                          _actionTile(
                            icon: Icons.receipt_long,
                            color: Colors.green,
                            title: 'Gérer les commandes',
                            subtitle: 'Confirmer, expédier, suivre',
                            onTap: () => onNavigate(2),
                          ),
                          _divider(),
                          _actionTile(
                            icon: Icons.inventory_2_outlined,
                            color: const Color(0xFF1E88E5),
                            title: 'Mes produits',
                            subtitle: 'Modifier ou supprimer vos articles',
                            onTap: () => onNavigate(1),
                          ),
                          _divider(),
                          _actionTile(
                            icon: Icons.campaign,
                            color: const Color(0xFFE53935),
                            title: 'Mes publicités',
                            subtitle: 'Promouvoir vos produits — 5 000 F/mois',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const VendeurPubScreen()),
                            ),
                          ),
                          _divider(),
                          _actionTile(
                            icon: Icons.person_outline,
                            color: Colors.purple,
                            title: 'Mon profil vendeur',
                            subtitle: 'Modifier vos informations',
                            onTap: () => onNavigate(3),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String uid, String title, IconData icon, Color color, String type) {
    final stream = type == 'products'
        ? FirebaseFirestore.instance
        .collection('products').where('vendeurId', isEqualTo: uid).snapshots()
        : FirebaseFirestore.instance
        .collection('orders').where('vendeurId', isEqualTo: uid).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return _statBox(icon, title, '$count', color);
      },
    );
  }

  Widget _revenueCard(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendeurId', isEqualTo: uid)
          .where('status', isEqualTo: 'livrée')
          .snapshots(),
      builder: (_, snap) {
        double total = 0;
        for (final doc in snap.data?.docs ?? []) {
          final d = doc.data() as Map<String, dynamic>;
          total += (d['total'] ?? 0).toDouble();
        }
        final display = total >= 1000000
            ? '${(total / 1000000).toStringAsFixed(1)}M'
            : total >= 1000
            ? '${(total / 1000).toStringAsFixed(0)}K'
            : total.toStringAsFixed(0);
        return _statBox(Icons.payments, 'Revenus', '$display F', Colors.green);
      },
    );
  }

  Widget _pendingCard(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendeurId', isEqualTo: uid)
          .where('status', isEqualTo: 'en_attente')
          .snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return _statBox(Icons.hourglass_empty, 'En attente', '$count', Colors.orange);
      },
    );
  }

  Widget _statBox(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ]),
    );
  }

  Widget _recentOrders(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendeurId', isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text('Erreur: ${snap.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          );
        }
        final allDocs = (snap.data?.docs ?? []).toList();
        int toMillis(dynamic raw) {
          if (raw is Timestamp) return raw.millisecondsSinceEpoch;
          if (raw is int) return raw;
          return 0;
        }
        allDocs.sort((a, b) {
          final ta = toMillis((a.data() as Map)['createdAt']);
          final tb = toMillis((b.data() as Map)['createdAt']);
          return tb.compareTo(ta);
        });
        final docs = allDocs.take(3).toList();
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('Aucune commande reçue',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          );
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final status = d['status'] ?? '';
            final color = status == 'livrée'
                ? Colors.green
                : status == 'en_livraison'
                ? Colors.orange
                : status == 'confirmée'
                ? const Color(0xFF1E88E5)
                : Colors.grey;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Commande #${doc.id.substring(0, 6).toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${(d['total'] ?? 0).toStringAsFixed(0)} FCFA',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status == 'en_attente' ? 'En attente'
                          : status == 'confirmée' ? 'Confirmée'
                          : status == 'en_livraison' ? 'En route'
                          : status == 'livrée' ? 'Livrée'
                          : status,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 60);
}