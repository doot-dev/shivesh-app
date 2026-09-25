String _fmtTimeAgo(String? iso) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  } catch (_) {
    return '';
  }
}

/// Map the server's single order status (2026-09-26: NEW → CONFIRMED →
/// DISPATCHED → REACHED → COMPLETED, plus DELAYED and CANCELLED) to the group
/// the UI colours by. Shared with the realtime layer. IN_PROGRESS / DELIVERED
/// are the old values, still in offline copies saved before the change.
OrderStatus mapOrderStatus(String? s) {
  switch (s) {
    case 'CANCELLED':
      return OrderStatus.cancelled;
    case 'COMPLETED':
      return OrderStatus.completed;
    case 'CONFIRMED':
    case 'DISPATCHED':
    case 'REACHED':
    case 'IN_PROGRESS':
    case 'DELIVERED':
      return OrderStatus.active;
    default: // NEW (waiting for the office), DELAYED
      return OrderStatus.pending;
  }
}

/// The step name people read: "Dispatched", "Delayed", …
String orderStatusLabel(String raw) => switch (raw) {
  'NEW' => 'New',
  'IN_PROGRESS' => 'Dispatched',
  'DELIVERED' => 'Reached',
  '' => 'Pending',
  _ => raw[0] + raw.substring(1).toLowerCase(),
};

enum OrderStatus { active, completed, pending, cancelled }

class TmDetail {
  const TmDetail({
    this.id = '',
    this.status = 'ASSIGNED',
    this.approvalStatus = 'PENDING',
    this.rejectionReason,
    this.rejectedByType,
    required this.tmNumber,
    required this.truckNo,
    required this.qty,
    required this.batchStartTime,
    required this.batchEndTime,
    required this.challanNo,
    this.challanUrl,
  });

  final String id;

  /// ASSIGNED / IN_TRANSIT / REACHED / DELIVERED — per truck (W32).
  final String status;

  /// PENDING / ACCEPTED / REJECTED.
  final String approvalStatus;
  final String? rejectionReason;

  /// CLIENT when the client rejected it at site, USER when the office did.
  final String? rejectedByType;

  final String tmNumber;
  final String truckNo;
  final String qty;
  final String batchStartTime;
  final String batchEndTime;
  final String challanNo;
  final String? challanUrl;

  /// D18: the client may reject a truck once it has reached site, before the
  /// challan is added (the server enforces the same rule).
  bool get canClientReject =>
      status == 'REACHED' &&
      (challanUrl == null || challanUrl!.isEmpty) &&
      approvalStatus == 'PENDING';

  bool get isRejected => approvalStatus == 'REJECTED';

  factory TmDetail.fromJson(Map<String, dynamic> json) => TmDetail(
    id: json['id'] as String? ?? '',
    status: json['status'] as String? ?? 'ASSIGNED',
    approvalStatus: json['approvalStatus'] as String? ?? 'PENDING',
    rejectionReason: json['rejectionReason'] as String?,
    rejectedByType: json['rejectedByType'] as String?,
    tmNumber: json['tmNumber'] as String? ?? '',
    truckNo: json['truckNo'] as String? ?? '',
    qty: json['qty'] as String? ?? '',
    batchStartTime: json['batchStartTime'] as String? ?? '',
    batchEndTime: json['batchEndTime'] as String? ?? '',
    challanNo: json['challanNo'] as String? ?? '',
    challanUrl: json['challanUrl'] as String?,
  );
}

class Comment {
  const Comment({
    required this.author,
    required this.message,
    required this.timeAgo,
    required this.isMe,
    this.id,
    this.pending = false,
  });

  final String author;
  final String message;
  final String timeAgo;
  final bool isMe;

  /// Server id. Null for a locally-echoed comment that has not round-tripped.
  final String? id;

  /// True while an optimistic comment is still in flight — the UI dims it.
  final bool pending;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String?,
    author: json['authorName'] as String? ?? '',
    message: json['message'] as String? ?? '',
    timeAgo: _fmtTimeAgo(json['createdAt'] as String?),
    isMe: (json['authorType'] as String?) == 'CLIENT',
  );

  Comment copyWith({bool? pending}) => Comment(
    id: id,
    author: author,
    message: message,
    timeAgo: timeAgo,
    isMe: isMe,
    pending: pending ?? this.pending,
  );
}

class Order {
  const Order({
    required this.id,
    required this.projectName,
    required this.status,
    required this.grade,
    required this.quantity,
    required this.product,
    required this.date,
    required this.time,
    required this.fieldTechnician,
    this.site,
    this.deliveryAddress,
    this.tmDetails = const [],
    this.comments = const [],
    this.rawStatus = '',
    this.placedBy,
  });

  /// docs/06: who placed it from the app, e.g. "Rakesh Pawar (Site Engineer)".
  final String? placedBy;

  /// The server's single order status (NEW, CONFIRMED, DISPATCHED, …).
  final String rawStatus;

  /// D15: the client can cancel until the order is dispatched.
  bool get canClientCancel =>
      const ['NEW', 'CONFIRMED', 'DELAYED'].contains(rawStatus) &&
      tmDetails.every((tm) => tm.status == 'ASSIGNED');

  final String id;
  final String projectName;
  final OrderStatus status;
  final String grade;
  final String quantity;
  final String product;
  final String date;
  final String time;
  final String fieldTechnician;
  final String? site;
  final String? deliveryAddress;
  final List<TmDetail> tmDetails;
  final List<Comment> comments;

  Order copyWith({
    OrderStatus? status,
    String? rawStatus,
    List<Comment>? comments,
  }) => Order(
    id: id,
    projectName: projectName,
    status: status ?? this.status,
    grade: grade,
    quantity: quantity,
    product: product,
    date: date,
    time: time,
    fieldTechnician: fieldTechnician,
    site: site,
    deliveryAddress: deliveryAddress,
    tmDetails: tmDetails,
    comments: comments ?? this.comments,
    rawStatus: rawStatus ?? this.rawStatus,
    placedBy: placedBy,
  );

  /// True when a real technician is attached.
  ///
  /// [fieldTechnician] falls back to the literal string 'Not assigned' in
  /// [Order.fromJson], so a plain isNotEmpty check is always true and the UI
  /// ends up rendering an avatar with the initial "N". Use this instead.
  bool get hasTechnician {
    final t = fieldTechnician.trim();
    return t.isNotEmpty && t.toLowerCase() != 'not assigned';
  }

  String get statusLabel => orderStatusLabel(rawStatus);

  factory Order.fromJson(Map<String, dynamic> json) {
    final project = json['project'] as Map<String, dynamic>?;
    final assignedTo = json['assignedTo'] as Map<String, dynamic>?;
    final tmList = (json['tmDetails'] as List<dynamic>?) ?? [];
    final commentList = (json['comments'] as List<dynamic>?) ?? [];
    final placer = json['placedBy'] as Map<String, dynamic>?;
    final placerRole =
        (placer?['role'] as Map<String, dynamic>?)?['name'] as String?;

    return Order(
      placedBy: placer == null
          ? null
          : '${placer['name']}${placerRole != null ? ' ($placerRole)' : ''}',
      id: json['orderId'] as String? ?? json['id'] as String? ?? '',
      projectName: project?['projectName'] as String? ?? '',
      status: mapOrderStatus(json['status'] as String?),
      rawStatus: json['status'] as String? ?? '',
      grade: json['productGrade'] as String? ?? '',
      quantity: json['quantity'] as String? ?? '',
      product: json['productName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      fieldTechnician: assignedTo?['name'] as String? ?? 'Not assigned',
      site: project?['siteName'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
      tmDetails: tmList
          .map((t) => TmDetail.fromJson(t as Map<String, dynamic>))
          .toList(),
      comments: commentList
          .map((c) => Comment.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
