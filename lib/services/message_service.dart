import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class MessageService {
  final _db = FirebaseFirestore.instance;

  Future<String> getOrCreateConversation({
    required String acheteurId,
    required String vendeurId,
    required String productId,
    required String productName,
  }) async {
    final convId = '${acheteurId}_${vendeurId}_$productId';
    final doc = await _db.collection('conversations').doc(convId).get();
    if (!doc.exists) {
      await _db.collection('conversations').doc(convId).set({
        'acheteurId': acheteurId,
        'vendeurId': vendeurId,
        'productId': productId,
        'productName': productName,
        'participants': [acheteurId, vendeurId],
        'lastMessage': '',
        'lastMessageTime': Timestamp.now(),
        'lastSenderId': '',
        'isRead_$acheteurId': true,
        'isRead_$vendeurId': true,
        'createdAt': Timestamp.now(),
      });
    } else {
      final data = doc.data() as Map<String, dynamic>;
      if (data['participants'] == null) {
        await _db.collection('conversations').doc(convId).update({
          'participants': [acheteurId, vendeurId],
        });
      }
    }
    return convId;
  }

  // ── Envoyer message + notification ──
  Future<void> sendMessage({
    required String convId,
    required String content,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final convDoc = await _db.collection('conversations').doc(convId).get();
    final convData = convDoc.data() as Map<String, dynamic>? ?? {};
    final acheteurId = convData['acheteurId'] ?? '';
    final vendeurId = convData['vendeurId'] ?? '';
    final productName = convData['productName'] ?? '';
    final otherId = uid == acheteurId ? vendeurId : acheteurId;

    final batch = _db.batch();

    final msgRef = _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'senderId': uid,
      'content': content,
      'createdAt': Timestamp.now(),
      'isRead': false,
    });

    batch.update(_db.collection('conversations').doc(convId), {
      'lastMessage': content,
      'lastMessageTime': Timestamp.now(),
      'lastSenderId': uid,
      'isRead_$uid': true,
      'isRead_$otherId': false,
    });

    await batch.commit();

    // ── Notification au destinataire ──
    final senderDoc = await _db.collection('users').doc(uid).get();
    final senderData = senderDoc.data() ?? {};
    final senderName = '${senderData['prenom'] ?? ''} ${senderData['nom'] ?? ''}'.trim();

    await NotificationService().sendNotification(
      toUserId: otherId,
      title: senderName.isEmpty ? 'Nouveau message' : senderName,
      body: content.length > 60 ? '${content.substring(0, 60)}...' : content,
      type: 'message',
      convId: convId,
    );
  }

  Future<void> markAsRead(String convId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('conversations').doc(convId).update({
      'isRead_$uid': true,
    });
  }

  Stream<QuerySnapshot> getMessages(String convId) {
    return _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  // ── Sans orderBy pour eviter crash index ──
  Stream<QuerySnapshot> getAcheteurConversations(String acheteurId) {
    return _db
        .collection('conversations')
        .where('acheteurId', isEqualTo: acheteurId)
        .snapshots();
  }

  Stream<QuerySnapshot> getVendeurConversations(String vendeurId) {
    return _db
        .collection('conversations')
        .where('vendeurId', isEqualTo: vendeurId)
        .snapshots();
  }

  Stream<QuerySnapshot> getAllConversations(String uid) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots();
  }
}
