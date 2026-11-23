import 'package:cloud_firestore/cloud_firestore.dart';

class UserLifeStage {
  static const Map<String, String> labels = {
    'general': 'General / Prefer not to say',
    'student': 'Student',
    'young_adult': 'Young Adult',
    'working_adult': 'Working Adult',
    'family': 'Family / Household',
    'retiree': 'Retiree / Senior',
  };

  static String labelOf(String? key) => labels[key] ?? labels['general']!;
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final double monthlyAllowance;
  final String currency;
  final String lifeStage;
  final bool biometricEnabled;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.monthlyAllowance,
    this.currency = 'MYR',
    this.lifeStage = 'general',
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
      lifeStage: data['lifeStage'] ?? 'general',
      biometricEnabled: data['biometricEnabled'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'monthlyAllowance': monthlyAllowance,
      'currency': currency,
      'lifeStage': lifeStage,
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
    String? lifeStage,
    bool? biometricEnabled,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      monthlyAllowance: monthlyAllowance ?? this.monthlyAllowance,
      currency: currency ?? this.currency,
      lifeStage: lifeStage ?? this.lifeStage,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      createdAt: createdAt,
    );
  }
}
