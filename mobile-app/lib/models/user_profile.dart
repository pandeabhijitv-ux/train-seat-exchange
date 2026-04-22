class UserProfile {
  final String phone;
  final String name;
  final String createdAt;
  final bool isVerified;

  const UserProfile({
    required this.phone,
    required this.name,
    required this.createdAt,
    this.isVerified = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'name': name,
      'created_at': createdAt,
      'is_verified': isVerified,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      phone: json['phone'] as String,
      name: json['name'] as String,
      createdAt: (json['created_at'] ?? json['last_verified_at'] ?? '') as String,
      isVerified: (json['is_verified'] ?? true) as bool,
    );
  }
}