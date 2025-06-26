import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String uid;
  final String name;
  final String email;
  final DateTime createdAt;

  User({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  // Factory constructor to create User from Firestore document
  factory User.fromMap(String uid, Map<String, dynamic> data) {
    return User(
      uid: uid,
      name: data['details']['name'] ?? 'Anonymous',
      email: data['details']['email'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert User to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'details': {
        'name': name,
        'email': email,
      },
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}