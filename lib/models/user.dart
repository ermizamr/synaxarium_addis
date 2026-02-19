enum UserTier { demo, normal, familiar }

class User {
  const User({
    this.id,
    required this.name,
    required this.phone,
    required this.tier,
    this.promoCode,
  });

  /// Supabase user id (uuid) if available.
  final String? id;
  final String name;
  final String phone;
  final UserTier tier;
  final String? promoCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'tier': tier.name,
      'promoCode': promoCode,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final rawTier = (json['tier'] as String? ?? '').toLowerCase();
    final normalizedTier = rawTier == 'vip' ? 'familiar' : rawTier;

    return User(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      tier: UserTier.values.firstWhere(
        (t) => t.name == normalizedTier,
        orElse: () => UserTier.normal,
      ),
      id: json['id'] as String?,
      promoCode: json['promoCode'] as String?,
    );
  }

  factory User.demo() {
    return const User(
      id: null,
      name: 'የማሳያ ተጠቃሚ',
      phone: '0900000000',
      tier: UserTier.demo,
    );
  }
}
