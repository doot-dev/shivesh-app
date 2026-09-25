import 'package:intl/intl.dart';

/// Testing period for a concrete cube sample.
///
/// Wire values are the backend's `CubeTestPeriod` enum — send [apiValue],
/// never `.name`. A standard period means the test date is castingDate + N
/// days; [custom] is the date of a test that already happened.
enum CubeTestPeriod {
  sevenDays,
  fourteenDays,
  fifteenDays,
  twentyOneDays,
  twentyEightDays,
  custom,
}

/// D21: what the form offers for NEW tests. 14 and 21 days stay in the enum
/// only so older records still parse and show a label.
const selectableCubeTestPeriods = [
  CubeTestPeriod.sevenDays,
  CubeTestPeriod.fifteenDays,
  CubeTestPeriod.twentyEightDays,
  CubeTestPeriod.custom,
];

extension CubeTestPeriodX on CubeTestPeriod {
  String get apiValue => switch (this) {
    CubeTestPeriod.sevenDays => 'SEVEN_DAYS',
    CubeTestPeriod.fourteenDays => 'FOURTEEN_DAYS',
    CubeTestPeriod.fifteenDays => 'FIFTEEN_DAYS',
    CubeTestPeriod.twentyOneDays => 'TWENTYONE_DAYS',
    CubeTestPeriod.twentyEightDays => 'TWENTYEIGHT_DAYS',
    CubeTestPeriod.custom => 'CUSTOM',
  };

  /// Days added to the casting date. Null for [custom], which has no offset.
  int? get days => switch (this) {
    CubeTestPeriod.sevenDays => 7,
    CubeTestPeriod.fourteenDays => 14,
    CubeTestPeriod.fifteenDays => 15,
    CubeTestPeriod.twentyOneDays => 21,
    CubeTestPeriod.twentyEightDays => 28,
    CubeTestPeriod.custom => null,
  };

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

/// Who logged a test or added a file: the person's name, else the kind of
/// party (`addedByType` is USER, FIELD_TECH, CLIENT_CONTACT or SYSTEM).
String _addedByLabel(String? name, String? type) {
  if (name != null && name.isNotEmpty) return name;
  return switch (type) {
    'CLIENT_CONTACT' => 'Your team',
    'FIELD_TECH' => 'Field technician',
    'USER' || 'SYSTEM' => 'Shivesh office',
    _ => '',
  };
}

/// One result sheet or photo on a cube test. A test has any number, added at
/// any time.
class CubeTestAttachment {
  const CubeTestAttachment({
    required this.id,
    required this.fileUrl,
    this.fileName,
    this.addedByType,
    this.addedByName,
    this.createdAt,
  });

  final String id;

  /// Server-relative `/uploads/cube-tests/...` path, opened with openServerFile.
  final String fileUrl;
  final String? fileName;
  final String? addedByType;
  final String? addedByName;
  final DateTime? createdAt;

  /// The server lets a client remove only files a client contact added.
  bool get addedByClient => addedByType == 'CLIENT_CONTACT';

  String get displayName =>
      (fileName ?? '').isNotEmpty ? fileName! : fileUrl.split('/').last;

  /// "Rakesh Pawar · 12 Sep 2026, 1:48 PM".
  String get subtitle => [
    _addedByLabel(addedByName, addedByType),
    if (createdAt != null) _dateTimeFmt.format(createdAt!),
  ].where((s) => s.isNotEmpty).join(' · ');

  factory CubeTestAttachment.fromJson(Map<String, dynamic> json) =>
      CubeTestAttachment(
        id: json['id']?.toString() ?? '',
        fileUrl: json['fileUrl'] as String? ?? '',
        fileName: json['fileName'] as String?,
        addedByType: json['addedByType'] as String?,
        addedByName: json['addedByName'] as String?,
        createdAt: CubeTest._parseNullableDate(json['createdAt']),
      );
}

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
    this.attachments = const [],
    this.addedByType,
    this.addedByName,
  });

  final String id;
  final DateTime castingDate;
  final String quantity;
  final CubeTestPeriod period;

  /// The date the cube is/was tested.
  final DateTime toDate;

  /// The newest attachment's path (legacy single-file field; the server keeps
  /// it in step with [attachments]).
  final String? fileUrl;

  /// Result sheets and photos, oldest first.
  final List<CubeTestAttachment> attachments;

  /// Who logged the test: USER, FIELD_TECH or CLIENT_CONTACT (null on old rows).
  final String? addedByType;
  final String? addedByName;

  /// "Rakesh Pawar", or the kind of party when the name is unknown.
  String get addedByLabel => _addedByLabel(addedByName, addedByType);

  /// When this report was submitted (server time). Null on older rows.
  final DateTime? createdAt;

  bool get hasFile =>
      attachments.isNotEmpty || (fileUrl != null && fileUrl!.isNotEmpty);

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

  factory CubeTest.fromJson(Map<String, dynamic> json) {
    final fileUrl = json['fileUrl'] as String?;
    final attachments = ((json['attachments'] as List?) ?? const [])
        .map((a) => CubeTestAttachment.fromJson(a as Map<String, dynamic>))
        .toList();
    return CubeTest(
      id: json['id'] as String? ?? '',
      castingDate: _parseDate(json['castingDate']),
      quantity: json['quantity']?.toString() ?? '',
      period: CubeTestPeriodX.fromApi(json['period'] as String?),
      toDate: _parseDate(json['toDate']),
      fileUrl: fileUrl,
      createdAt: _parseNullableDate(json['createdAt']),
      // An offline copy saved before attachments existed has only fileUrl.
      attachments: attachments.isEmpty && (fileUrl ?? '').isNotEmpty
          ? [CubeTestAttachment(id: '', fileUrl: fileUrl!)]
          : attachments,
      addedByType: json['addedByType'] as String?,
      addedByName: json['addedByName'] as String?,
    );
  }
}

/// A cube test plus the order/project labels the backend flattens onto it.
///
/// What the cross-order Cube tests tab renders. `clientName` is deliberately
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

  /// Human order code (ORD-2025-0001) — used to open the order's cube tests.
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
