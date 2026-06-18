import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String id;
  final String userId;
  final String userRole; // 'client' ou 'vendeur'
  final String userName;
  final String subject;
  final String message;
  final String status; // 'en_attente', 'en_cours', 'resolue'
  final String? response;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.subject,
    required this.message,
    this.status = 'en_attente',
    this.response,
    required this.createdAt,
  });

  factory Complaint.fromMap(Map<String, dynamic> map, String id) {
    return Complaint(
      id: id,
      userId: map['userId'] ?? '',
      userRole: map['userRole'] ?? 'client',
      userName: map['userName'] ?? '',
      subject: map['subject'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'en_attente',
      response: map['response'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userRole': userRole,
    'userName': userName,
    'subject': subject,
    'message': message,
    'status': status,
    'response': response,
    'createdAt': Timestamp.now(),
  };
}
