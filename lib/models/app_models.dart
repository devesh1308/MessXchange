class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final int messCredits;
  // CHANGE THIS: Ensure it is 'double' and not 'int'
  final double refundCredits;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.messCredits,
    required this.refundCredits,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? 'User',
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',

      // Mess Credits are always whole numbers (1095, 1094...)
      messCredits: (data['mess_credits'] as num?)?.toInt() ?? 1095,

      // Refund Credits can be decimals (0.5, 1.0, 1.5...)
      refundCredits: (data['refund_credits'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'mess_credits': messCredits,
      'refund_credits': refundCredits,
    };
  }
}