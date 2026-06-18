import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminLivraisonsTab extends StatelessWidget {
  const AdminLivraisonsTab({super.key});

  static const double _fraisLivraison = 1000;

  // ── Formate le message prêt à coller dans WhatsApp ──
  String _buildWhatsappMessage(Map<String, dynamic> notif) {
    final orderId  = (notif['orderId'] ?? '').toString();
    final shortId  = orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();
    final vendNom  = notif['vendeurNom']     ?? '';
    final vendTel  = notif['vendeurTel']     ?? '';
    final vendAddr = notif['vendeurAdresse'] ?? '';
    final cliNom   = notif['clientNom']      ?? '';
    final cliTel   = notif['clientTel']      ?? '';
    final cliAddr  = notif['clientAddress']  ?? '';

    // Livraison toujours fixée à 1 000 F
    return '🛵 LIVRAISON — ${_fraisLivraison.toStringAsFixed(0)} F\n'
        '📦 Commande : #$shortId\n'
        '🏪 Vendeur : $vendNom · $vendTel\n'
        '📍 Boutique : $vendAddr\n'
        '👤 Client : $cliNom · $cliTel\n'
        '📍 Livrer à : $cliAddr';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('type', isEqualTo: 'commande_en_livraison')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1A237E)),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text('Erreur : ${snap.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        final allDocs = snap.data?.docs ?? [];

        if (allDocs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining_outlined, size: 72, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucune livraison en cours',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                SizedBox(height: 8),
                Text('Les demandes apparaîtront ici en temps réel',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }

        // ── Tri : non lus en haut, lus en bas (chacun par date desc) ──
        final nonLus = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['isRead'] != true;
        }).toList();

        final lus = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['isRead'] == true;
        }).toList();

        final docs = [...nonLus, ...lus];

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final notif   = docs[i].data() as Map<String, dynamic>;
            final notifId = docs[i].id;
            final isRead  = notif['isRead'] == true;
            final createdAt = (notif['createdAt'] as Timestamp?)?.toDate();
            final dateStr = createdAt != null
                ? DateFormat('dd/MM · HH:mm').format(createdAt)
                : '';

            final orderId  = (notif['orderId'] ?? '').toString();
            final shortId  = orderId.length >= 8
                ? orderId.substring(0, 8).toUpperCase()
                : orderId.toUpperCase();
            final vendNom  = notif['vendeurNom']     ?? '';
            final vendTel  = notif['vendeurTel']     ?? '';
            final vendAddr = notif['vendeurAdresse'] ?? '';
            final cliNom   = notif['clientNom']      ?? '';
            final cliTel   = notif['clientTel']      ?? '';
            final cliAddr  = notif['clientAddress']  ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: isRead ? 1 : 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isRead
                    ? BorderSide.none
                    : const BorderSide(color: Color(0xFF1A237E), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── En-tête ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.grey.shade100
                          : const Color(0xFF1A237E).withValues(alpha: 0.07),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A237E).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delivery_dining,
                              color: Color(0xFF1A237E), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(
                                  'Commande #$shortId',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                if (!isRead) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('NOUVEAU',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5)),
                                  ),
                                ],
                              ]),
                              Text(dateStr,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        // Badge livraison fixe
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '1 000 F',
                            style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Infos vendeur ──
                  _infoSection(
                    icon: Icons.store,
                    color: Colors.orange,
                    title: 'Vendeur',
                    lines: [
                      if (vendNom.isNotEmpty) vendNom,
                      if (vendTel.isNotEmpty) vendTel,
                      if (vendAddr.isNotEmpty) vendAddr,
                    ],
                  ),

                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // ── Infos client ──
                  _infoSection(
                    icon: Icons.person,
                    color: Color(0xFF1E88E5),
                    title: 'Client',
                    lines: [
                      if (cliNom.isNotEmpty) cliNom,
                      if (cliTel.isNotEmpty) cliTel,
                      if (cliAddr.isNotEmpty) cliAddr,
                    ],
                  ),

                  // ── Aperçu message WhatsApp ──
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF43A047).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.chat_bubble_outline,
                              color: Color(0xFF43A047), size: 14),
                          const SizedBox(width: 6),
                          const Text(
                            'Message WhatsApp prêt',
                            style: TextStyle(
                                color: Color(0xFF43A047),
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          _buildWhatsappMessage(notif),
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  // ── Bouton Copier ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final msg = _buildWhatsappMessage(notif);
                          await Clipboard.setData(ClipboardData(text: msg));

                          // Marquer comme lu → passe automatiquement en bas
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(notifId)
                              .update({'isRead': true});

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Message copié ! Collez dans WhatsApp'),
                                ]),
                                backgroundColor: const Color(0xFF43A047),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                        label: Text(
                          isRead ? 'Copier à nouveau' : 'Copier le message WhatsApp',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRead
                              ? Colors.grey.shade500
                              : const Color(0xFF25D366),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Ligne d'infos réutilisable ──
  Widget _infoSection({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> lines,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const SizedBox(height: 2),
              ...lines.map((l) => Text(l,
                  style: const TextStyle(fontSize: 13, color: Colors.black87))),
              if (lines.isEmpty)
                const Text('—',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
