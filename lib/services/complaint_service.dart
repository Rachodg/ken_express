import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/complaint.dart';

class ComplaintService {
  final _db = FirebaseFirestore.instance;

  // ── Soumettre une plainte / reclamation ──
  Future<void> submitComplaint({
    required String subject,
    required String message,
    required String userRole,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final userName =
    '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}'.trim();

    await _db.collection('complaints').add({
      'userId': user.uid,
      'userRole': userRole,
      'userName': userName.isEmpty ? (user.email ?? 'Utilisateur') : userName,
      'subject': subject,
      'message': message,
      'status': 'en_attente',
      'response': null,
      'createdAt': Timestamp.now(),
    });
  }

  // ── Mes plaintes (client ou vendeur connecte) ──
  Stream<List<Complaint>> getMyComplaints() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('complaints')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list =
      snap.docs.map((d) => Complaint.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ── Admin : toutes les plaintes ──
  Stream<List<Complaint>> getAllComplaints() {
    return _db.collection('complaints').snapshots().map((snap) {
      final list =
      snap.docs.map((d) => Complaint.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ── Admin : changer le statut / repondre ──
  Future<void> updateStatus(String complaintId, String status,
      {String? response}) async {
    final data = <String, dynamic>{'status': status};
    if (response != null) data['response'] = response;
    await _db.collection('complaints').doc(complaintId).update(data);
  }
}
