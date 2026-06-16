import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final double monthlyAllowance;
  final String currency;
  final bool biometricEnabled;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.monthlyAllowance,
    this.currency = 'MYR',
    this.biometricEnabled = false,
    required this.createdAt,
  });

  // Convert Firestore document to UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      monthlyAllowance: (data['monthlyAllowance'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'MYR',
      biometricEnabled: data['biometricEnabled'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'monthlyAllowance': monthlyAllowance,
      'currency': currency,
      'biometricEnabled': biometricEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // CopyWith for updating fields
  UserModel copyWith({
    String? name,
    String? email,
    double? monthlyAllowance,
    String? currency,
    bool? biometricEnabled,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      monthlyAllowance: monthlyAllowance ?? this.monthlyAllowance,
      currency: currency ?? this.currency,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      createdAt: createdAt,
    );
  }
}
