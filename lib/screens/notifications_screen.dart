import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';
import '../main.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'complaint_screen.dart'; // ← AJOUT

class NotificationsScreen extends StatelessWidget {
  final bool isVendeur;
  // Permet, côté vendeur, de revenir à l'onglet "Commandes" de la navigation
  // principale plutôt que de pousser un écran sans bouton retour.
  final void Function(int)? onNavigateVendeur;
  const NotificationsScreen({super.key, this.isVendeur = false, this.onNavigateVendeur});

  IconData _iconForType(String type) {
    switch (type) {
      case 'nouvelle_commande': return Icons.shopping_bag;
      case 'commande_confirmee': return Icons.check_circle;
      case 'en_livraison': return Icons.delivery_dining;
      case 'commande_en_livraison': return Icons.local_shipping;
      case 'livree': return Icons.done_all;
      case 'annulee': return Icons.cancel;
      case 'message': return Icons.chat;
      case 'reclamation_repondue': return Icons.support_agent; // ← AJOUT
      default: return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'nouvelle_commande': return Colors.orange;
      case 'commande_confirmee': return Colors.blue;
      case 'en_livraison': return Colors.orange;
      case 'commande_en_livraison': return Colors.deepPurple;
      case 'livree': return Colors.green;
      case 'annulee': return Colors.red;
      case 'message': return Colors.purple;
      case 'reclamation_repondue': return Colors.teal; // ← AJOUT
      default: return Colors.grey;
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    DateTime date;
    if (raw is Timestamp) {
      date = raw.toDate();
    } else if (raw is int) {
      date = DateTime.fromMillisecondsSinceEpoch(raw);
    } else {
      return '';
    }
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'A instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _appeler(BuildContext context, String tel) async {
    final uri = Uri(scheme: 'tel', path: tel);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'appeler $tel'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _ouvrirCarte(BuildContext context, double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir la carte'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Types de notifications liés à une commande ──
  static const _orderTypes = {
    'nouvelle_commande', 'commande_confirmee', 'en_livraison',
    'commande_en_livraison', 'livree', 'annulee',
  };

  Future<void> _ouvrirDestination(BuildContext context, String notifId, Map<String, dynamic> data) async {
    await NotificationService().markAsRead(notifId);
    if (!context.mounted) return;

    final type = (data['type'] ?? '').toString();
    final orderId = data['orderId'] as String?;
    final convId = data['convId'] as String?;

    // ── Notification de message → ouvrir directement la conversation ──
    if (type == 'message' && convId != null && convId.isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final convDoc = await FirebaseFirestore.instance.collection('conversations').doc(convId).get();
      if (!context.mounted) return;
      if (!convDoc.exists) return;
      final convData = convDoc.data() as Map<String, dynamic>;
      final acheteurId = convData['acheteurId'] ?? '';
      final vendeurId = convData['vendeurId'] ?? '';
      final productName = convData['productName'] ?? '';
      final otherId = uid == acheteurId ? vendeurId : acheteurId;

      String otherUserName = '';
      if (otherId.toString().isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherId).get();
        final userData = userDoc.data();
        otherUserName = '${userData?['prenom'] ?? ''} ${userData?['nom'] ?? ''}'.trim();
      }
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(
          convId: convId,
          otherUserName: otherUserName.isEmpty ? 'Conversation' : otherUserName,
          productName: productName,
        ),
      ));
      return;
    }

    // ── AJOUT : Notification de réponse à une réclamation → ouvrir l'écran des réclamations ──
    if (type == 'reclamation_repondue') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ComplaintScreen(isVendeur: isVendeur),
      ));
      return;
    }

    // ── Notification liée à une commande → ouvrir "Mes commandes" / "Commandes reçues" ──
    if (_orderTypes.contains(type) || (orderId != null && orderId.isNotEmpty)) {
      if (isVendeur) {
        // On revient à la navigation principale et on bascule sur l'onglet Commandes
        // (pas de bouton retour sur cet écran quand il est utilisé comme onglet).
        Navigator.of(context).pop();
        onNavigateVendeur?.call(2);
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientOrdersScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final color = isVendeur ? Colors.orange : AppColors.clientPrimary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: true,
        actions: [
          TextButton(
            onPressed: () => NotificationService().markAllAsRead(uid),
            child: const Text('Tout lire',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: color));
          }
          final docs = snap.data?.docs ?? [];
          // Tri côté client
          docs.sort((a, b) {
            final ta = (a.data() as Map)['createdAt'];
            final tb = (b.data() as Map)['createdAt'];
            DateTime? da = ta is Timestamp ? ta.toDate() : (ta is int ? DateTime.fromMillisecondsSinceEpoch(ta) : null);
            DateTime? db = tb is Timestamp ? tb.toDate() : (tb is int ? DateTime.fromMillisecondsSinceEpoch(tb) : null);
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_none,
                        size: 64, color: color),
                  ),
                  const SizedBox(height: 20),
                  const Text('Aucune notification',
                      style: TextStyle(color: Colors.grey, fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final type = data['type'] ?? '';
              final typeColor = _colorForType(type);

              return GestureDetector(
                onTap: () => _ouvrirDestination(context, docs[i].id, data),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRead
                          ? Colors.grey.shade200
                          : color.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_iconForType(type),
                              color: typeColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(data['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                          fontSize: 14,
                                        )),
                                  ),
                                  if (!isRead)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8, top: 4),
                                      width: 10, height: 10,
                                      decoration: BoxDecoration(
                                          color: color, shape: BoxShape.circle),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(data['body'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(_formatTime(data['createdAt']),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w500)),
                              if (type == 'commande_en_livraison') ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if ((data['vendeurTel'] ?? '').toString().isNotEmpty)
                                      OutlinedButton.icon(
                                        onPressed: () => _appeler(context, data['vendeurTel']),
                                        icon: const Icon(Icons.phone, size: 16),
                                        label: const Text('Appeler vendeur', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.green,
                                          side: const BorderSide(color: Colors.green),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                        ),
                                      ),
                                    if (data['vendeurLat'] != null && data['vendeurLng'] != null)
                                      OutlinedButton.icon(
                                        onPressed: () => _ouvrirCarte(
                                          context,
                                          (data['vendeurLat'] as num).toDouble(),
                                          (data['vendeurLng'] as num).toDouble(),
                                        ),
                                        icon: const Icon(Icons.location_on, size: 16),
                                        label: const Text('Localisation vendeur', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.deepPurple,
                                          side: const BorderSide(color: Colors.deepPurple),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}