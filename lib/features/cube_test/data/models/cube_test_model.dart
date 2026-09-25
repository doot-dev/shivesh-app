import 'package:intl/intl.dart';

/// Testing period for a concrete cube sample.
///
/// Wire values are the backend's `CubeTestPeriod` enum. The client app is
/// READ-ONLY for cube tests — technicians and admins create them — so this only
/// ever parses [fromApi], never sends.
enum CubeTestPeriod {
  sevenDays,
  fourteenDays,
  fifteenDays,
  twentyOneDays,
  twentyEightDays,
  custom,
}

extension CubeTestPeriodX on CubeTestPeriod {
  String get label {
    switch (this) {
      case CubeTestPeriod.sevenDays:
        return '7 days';
      case CubeTestPeriod.fourteenDays:
        return '14 days';
      case CubeTestPeriod.fifteenDays:
        return '15 days';
      case CubeTestPeriod.twentyOneDays:
        return '21 days';
      case CubeTestPeriod.twentyEightDays:
        return '28 days';
      case CubeTestPeriod.custom:
        return 'Custom date';
    }
  }

  static CubeTestPeriod fromApi(String? v) {
    switch (v) {
      case 'FOURTEEN_DAYS':
        return CubeTestPeriod.fourteenDays;
      case 'FIFTEEN_DAYS':
        return CubeTestPeriod.fifteenDays;
      case 'TWENTYONE_DAYS':
        return CubeTestPeriod.twentyOneDays;
      case 'TWENTYEIGHT_DAYS':
        return CubeTestPeriod.twentyEightDays;
      case 'CUSTOM':
        return CubeTestPeriod.custom;
      case 'SEVEN_DAYS':
      default:
        return CubeTestPeriod.sevenDays;
    }
  }
}

final _dateFmt = DateFormat('dd MMM yyyy');
final _dateTimeFmt = DateFormat('dd MMM yyyy, h:mm a');

/// One cube testing report on one of this client's orders.
///
/// [createdAt] is when the report was SUBMITTED, which is not [castingDate].
/// Results legitimately arrive weeks later — often after the order closed — so
/// the submission time is the audit trail showing when a late entry was made.
class CubeTest {
  const CubeTest({
    required this.id,
    required this.castingDate,
    required this.quantity,
    required this.period,
    required this.toDate,
    this.fileUrl,
    this.createdAt,
  });

  final String id;
  final DateTime castingDate;
  final String quantity;
  final CubeTestPeriod period;

  /// The date the cube is/was tested.
  final DateTime toDate;

  /// Server-relative path of the result sheet, e.g.
  /// `/uploads/cube-tests/ORD-2025-0001/report.pdf`. Needs the API base URL
  /// prefixed before it can be opened.
  final String? fileUrl;

  /// When this report was submitted (server time). Null on older rows.
  final DateTime? createdAt;

  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;

  String get castingDateLabel => _dateFmt.format(castingDate);
  String get testDateLabel => _dateFmt.format(toDate);

  /// "12 Sep 2026, 1:48 PM" — when this report was logged.
  String get addedAtLabel =>
      createdAt == null ? '' : _dateTimeFmt.format(createdAt!);

  /// True once the scheduled testing date has arrived.
  /// Test date passed and no result yet (matches the server's DUE status).
  bool get isDue => !hasFile && !toDate.isAfter(DateTime.now());

  /// Whole days until the test is due; negative once it has passed.
  int get daysUntilDue {
    final today = DateTime.now();
    final d = DateTime(toDate.year, toDate.month, toDate.day);
    final n = DateTime(today.year, today.month, today.day);
    return d.difference(n).inDays;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
    return DateTime.now();
  }

  /// Unlike [_parseDate] this returns null rather than "now" — a missing
  /// timestamp must read as unknown, not as if it were just submitted.
  static DateTime? _parseNullableDate(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
    return null;
  }

  factory CubeTest.fromJson(Map<String, dynamic> json) => CubeTest(
    id: json['id'] as String? ?? '',
    castingDate: _parseDate(json['castingDate']),
    quantity: json['quantity']?.toString() ?? '',
    period: CubeTestPeriodX.fromApi(json['period'] as String?),
    toDate: _parseDate(json['toDate']),
    fileUrl: json['fileUrl'] as String?,
    createdAt: _parseNullableDate(json['createdAt']),
  );
}

/// A cube test plus the order/project labels the backend flattens onto it.
///
/// The client app only ever shows cube tests in one cross-order list, so this
/// — not bare [CubeTest] — is what the UI renders. `clientName` is deliberately
/// not carried: every row already belongs to the signed-in client.
class CubeTestEntry {
  const CubeTestEntry({
    required this.test,
    required this.orderId,
    this.productName,
    this.productGrade,
    this.projectName,
    this.siteName,
  });

  final CubeTest test;

  /// Human order code (ORD-2025-0001) — used to open the order screen.
  final String orderId;

  final String? productName;
  final String? productGrade;
  final String? projectName;
  final String? siteName;

  /// "M25 — OPC" style label, skipping whichever half is missing.
  String get productLabel =>
      [?productName, ?productGrade].where((s) => s.isNotEmpty).join(' — ');

  /// Project with its site in brackets, when both are known and differ.
  String get projectLabel {
    final p = projectName ?? '';
    final s = siteName ?? '';
    if (p.isEmpty) return s;
    if (s.isEmpty || s == p) return p;
    return '$p ($s)';
  }

  factory CubeTestEntry.fromJson(Map<String, dynamic> json) => CubeTestEntry(
    test: CubeTest.fromJson(json),
    orderId: json['orderId'] as String? ?? '',
    productName: json['productName'] as String?,
    productGrade: json['productGrade'] as String?,
    projectName: json['projectName'] as String?,
    siteName: json['siteName'] as String?,
  );
}
