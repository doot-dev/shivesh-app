class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.location,
    required this.remainingCredits,
    required this.creditPeriod,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String location;
  final String remainingCredits;
  final String creditPeriod;
  final String? imageUrl;

  factory ProjectSummary.fromJson(Map<String, dynamic> json) {
    final creditAmount = (json['creditAmount'] as num?)?.toDouble() ?? 0;
    return ProjectSummary(
      id: json['projectId'] as String? ?? json['id'] as String? ?? '',
      name: json['projectName'] as String? ?? '',
      location: json['projectLocation'] as String? ?? '',
      remainingCredits: '₹${_formatCredit(creditAmount)}',
      creditPeriod: '${json['creditResetPeriodDays'] ?? 30} Days',
    );
  }

  static String _formatCredit(double amount) {
    if (amount >= 10000000)
      return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)} L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

class ProjectDetail {
  const ProjectDetail({
    required this.id,
    required this.name,
    required this.siteName,
    required this.location,
    required this.remainingCredits,
    required this.creditPeriod,
    this.projectManager,
    this.address,
  });

  final String id;
  final String name;
  final String siteName;
  final String location;
  final String remainingCredits;
  final String creditPeriod;
  final String? projectManager;
  final String? address;

  factory ProjectDetail.fromJson(Map<String, dynamic> json) {
    final creditAmount = (json['creditAmount'] as num?)?.toDouble() ?? 0;
    return ProjectDetail(
      id: json['projectId'] as String? ?? '',
      name: json['projectName'] as String? ?? '',
      siteName: json['siteName'] as String? ?? '',
      location: json['projectLocation'] as String? ?? '',
      remainingCredits: '₹${ProjectSummary._formatCredit(creditAmount)}',
      creditPeriod: '${json['creditResetPeriodDays'] ?? 30} Days',
      projectManager: json['projectManager'] as String?,
      address: json['address'] as String?,
    );
  }
}

class ProjectProduct {
  const ProjectProduct({required this.productName, required this.productGrade});

  final String productName;
  final String productGrade;

  factory ProjectProduct.fromJson(Map<String, dynamic> json) => ProjectProduct(
    productName: json['productName'] as String? ?? '',
    productGrade: json['productGrade'] as String? ?? '',
  );
}
