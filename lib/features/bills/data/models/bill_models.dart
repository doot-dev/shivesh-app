/// Real credit position from GET /client/credit (W17, P1.14) — replaces the
/// hard-coded "Payment Due ₹0" and the limit shown as "remaining".
class CreditPosition {
  const CreditPosition({
    required this.limit,
    required this.used,
    required this.available,
    required this.outstanding,
    required this.unbilled,
    required this.overdueAmount,
    required this.flag,
    this.creditDays,
    this.nextDueDate,
    this.daysLeft,
  });

  final double limit;
  final double used;
  final double available;
  final double outstanding;
  final double unbilled;
  final double overdueAmount;
  final int? creditDays;
  final DateTime? nextDueDate;
  final int? daysLeft;

  /// OK | OVERDUE | OVER_LIMIT
  final String flag;

  double get utilisation => limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0;

  static double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

  factory CreditPosition.fromJson(Map<String, dynamic> j) => CreditPosition(
    limit: _d(j['limit']),
    used: _d(j['used']),
    available: _d(j['available']),
    outstanding: _d(j['outstanding']),
    unbilled: _d(j['unbilled']),
    overdueAmount: _d(j['overdueAmount']),
    flag: j['flag'] as String? ?? 'OK',
    creditDays: (j['creditDays'] as num?)?.toInt(),
    nextDueDate: j['nextDueDate'] != null ? DateTime.tryParse(j['nextDueDate'] as String) : null,
    daysLeft: (j['daysLeft'] as num?)?.toInt(),
  );
}

/// An issued bill (SENT / PAID / OVERDUE) from GET /client/bills (W16).
class ClientBill {
  const ClientBill({
    required this.billNo,
    required this.amount,
    required this.status,
    required this.orderId,
    required this.product,
    required this.projectName,
    this.issueDate,
    this.dueDate,
    this.daysOverdue = 0,
  });

  final String billNo;
  final double amount;
  final String status;
  final String orderId;
  final String product;
  final String projectName;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final int daysOverdue;

  factory ClientBill.fromJson(Map<String, dynamic> j) {
    final order = j['order'] as Map<String, dynamic>? ?? {};
    final project = order['project'] as Map<String, dynamic>? ?? {};
    return ClientBill(
      billNo: j['billNo'] as String? ?? '',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      status: j['status'] as String? ?? '',
      orderId: order['orderId'] as String? ?? '',
      product: '${order['productName'] ?? ''} ${order['productGrade'] ?? ''}'.trim(),
      projectName: project['projectName'] as String? ?? '',
      issueDate: j['issueDate'] != null ? DateTime.tryParse(j['issueDate'] as String) : null,
      dueDate: j['dueDate'] != null ? DateTime.tryParse(j['dueDate'] as String) : null,
      daysOverdue: (j['daysOverdue'] as num?)?.toInt() ?? 0,
    );
  }
}
