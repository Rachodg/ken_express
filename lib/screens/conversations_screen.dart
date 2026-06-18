import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/message_service.dart';
import '../main.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatelessWidget {
  final bool isVendeur;

  const ConversationsScreen({super.key, this.isVendeur = false});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final color = isVendeur ? Colors.orange : AppColors.clientPrimary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: isVendeur
            ? MessageService().getVendeurConversations(uid)
            : MessageService().getAcheteurConversations(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: color));
          }
          final docs = (snap.data?.docs ?? []).toList();
          docs.sort((a, b) {
            final ta = (a.data() as Map)['lastMessageTime'];
            final tb = (b.data() as Map)['lastMessageTime'];
            if (ta == null) return 1;
            if (tb == null) return -1;
            return (tb as Timestamp).compareTo(ta as Timestamp);
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
                    child: Icon(Icons.chat_bubble_outline,
                        size: 64, color: color),
                  ),
                  const SizedBox(height: 20),
                  const Text('Aucune conversation',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(
                    isVendeur
                        ? 'Vos clients vous contacteront ici'
                        : 'Contactez un vendeur depuis un produit',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final otherId =
              isVendeur ? data['acheteurId'] : data['vendeurId'];
              final convId = docs[i].id;

              // Vérifier si non lu
              final lastSenderId = data['lastSenderId'] ?? '';
              final isRead = data['isRead_$uid'] ?? true;
              final hasUnread = lastSenderId != uid && isRead == false;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherId)
                    .get(),
                builder: (context, userSnap) {
                  final userData =
                      userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final nom =
                  '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}'
                      .trim();
                  final photo = userData['photoUrl'] ?? '';
                  final lastMessage = data['lastMessage'] ?? '';
                  final lastTime = data['lastMessageTime'] != null
                      ? (data['lastMessageTime'] as Timestamp).toDate()
                      : DateTime.now();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: hasUnread ? 3 : 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: color.withValues(alpha: 0.15),
                            backgroundImage: photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo.isEmpty
                                ? Icon(
                                isVendeur
                                    ? Icons.person
                                    : Icons.store,
                                color: color)
                                : null,
                          ),
                          // Point vert "en ligne" — décoratif
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              nom.isEmpty ? 'Utilisateur' : nom,
                              style: TextStyle(
                                fontWeight: hasUnread
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(lastTime),
                            style: TextStyle(
                              color:
                              hasUnread ? color : Colors.grey.shade400,
                              fontSize: 11,
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage.isEmpty
                                  ? data['productName'] ?? ''
                                  : lastMessage,
                              style: TextStyle(
                                fontSize: 12,
                                color: hasUnread
                                    ? Colors.black87
                                    : Colors.grey,
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Badge non lu
                          if (hasUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      onTap: () async {
                        // Marquer comme lu avant d'ouvrir
                        await MessageService().markAsRead(convId);
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              convId: convId,
                              otherUserName:
                              nom.isEmpty ? 'Utilisateur' : nom,
                              productName: data['productName'] ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    return '${time.day}/${time.month}';
  }
}
