class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.companyName,
    required this.address,
    required this.paymentDue,
    required this.creditDaysRemaining,
    required this.creditPeriodDays,
    this.avatarUrl,
  });

  final String name;
  final String email;
  final String phone;
  final String companyName;
  final String address;
  final double paymentDue;
  final int creditDaysRemaining;
  final int creditPeriodDays;
  final String? avatarUrl;

  double get creditProgress =>
      1 - (creditDaysRemaining / creditPeriodDays).clamp(0.0, 1.0);

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['ownerName'] as String? ?? json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone:
            json['contactNumber'] as String? ?? json['phone'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        address: json['address'] as String? ?? '',
        paymentDue: 0,
        creditDaysRemaining: 0,
        creditPeriodDays: 30,
      );
}
