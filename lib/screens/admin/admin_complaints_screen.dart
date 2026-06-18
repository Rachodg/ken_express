import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart'; // AppColors
import '../../services/notification_service.dart'; // ← AJOUT

class AdminComplaintsScreen extends StatelessWidget {
  final bool embedded;
  const AdminComplaintsScreen({super.key, this.embedded = false});

  Color _statusColor(String status) {
    switch (status) {
      case 'en_cours': return Colors.blue;
      case 'resolue': return Colors.green;
      default: return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'en_cours': return 'En cours';
      case 'resolue': return 'Résolue';
      default: return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.adminPrimary));
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.adminPrimary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inbox_outlined,
                      size: 64, color: AppColors.adminPrimary),
                ),
                const SizedBox(height: 20),
                const Text('Aucune réclamation',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final subject = data['subject'] ?? '';
            final message = data['message'] ?? '';
            final status = data['status'] ?? 'en_attente';
            final userName = data['userName'] ?? '';
            final userRole = data['userRole'] ?? '';
            final response = data['response'];
            final color = _statusColor(status);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(subject,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Text(_statusLabel(status),
                            style: TextStyle(color: color, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(
                      userRole == 'vendeur' ? Icons.store : Icons.person,
                      size: 13, color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(userName.isEmpty ? 'Utilisateur' : userName,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  Text(message, style: const TextStyle(fontSize: 13)),
                  if (response != null && (response as String).isNotEmpty) ...[
                    const Divider(height: 16),
                    Row(children: [
                      const Icon(Icons.support_agent,
                          color: AppColors.adminPrimary, size: 16),
                      const SizedBox(width: 6),
                      const Text('Votre réponse',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    Text(response, style: const TextStyle(fontSize: 13)),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _replyDialog(context, doc.id, data),
                      icon: const Icon(Icons.reply, size: 16,
                          color: AppColors.adminPrimary),
                      label: const Text('Répondre',
                          style: TextStyle(color: AppColors.adminPrimary)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (embedded) return Container(color: const Color(0xFFF5F5F5), child: body);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Réclamations'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }

  void _replyDialog(
      BuildContext context,
      String complaintId,
      Map<String, dynamic> data,
      ) {
    final controller = TextEditingController(text: data['response'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Répondre au client'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Écris la réponse du support...',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.adminPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final reponse = controller.text.trim();

              // ── On garde une référence au contexte du dialog pour le fermer/afficher l'erreur ──
              final dialogContext = context;

              try {
                await FirebaseFirestore.instance
                    .collection('complaints')
                    .doc(complaintId)
                    .update({
                  'response': reponse,
                  'status': 'resolue',
                  'repliedAt': FieldValue.serverTimestamp(),
                });

                // ── AJOUT : notifier le client/vendeur qu'une réponse est arrivée ──
                await NotificationService().sendNotification(
                  toUserId: data['userId'] ?? '',
                  title: 'Réponse à votre réclamation',
                  body: reponse.length > 60
                      ? '${reponse.substring(0, 60)}...'
                      : reponse,
                  type: 'reclamation_repondue',
                );

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                // ── AJOUT : si l'enregistrement échoue, on le voit enfin ──
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}