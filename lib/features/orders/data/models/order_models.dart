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

/// Map a backend order status string (`NEW`, `IN_PROGRESS`, `DELIVERED`, …)
/// to the tri-state the UI renders. Shared with the realtime layer, which
/// receives raw status strings over the WebSocket.
OrderStatus mapOrderStatus(String? s) {
  switch (s) {
    case 'DELIVERED':
    case 'COMPLETED':
    case 'CANCELLED':
      return OrderStatus.completed;
    case 'NEW':
    case 'CONFIRMED':
    case 'IN_PROGRESS':
      return OrderStatus.active;
    default:
      return OrderStatus.pending;
  }
}

enum OrderStatus { active, completed, pending }

class TmDetail {
  const TmDetail({
    required this.tmNumber,
    required this.truckNo,
    required this.qty,
    required this.batchStartTime,
    required this.batchEndTime,
    required this.challanNo,
    this.challanUrl,
  });

  final String tmNumber;
  final String truckNo;
  final String qty;
  final String batchStartTime;
  final String batchEndTime;
  final String challanNo;
  final String? challanUrl;

  factory TmDetail.fromJson(Map<String, dynamic> json) => TmDetail(
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
  });

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

  Order copyWith({OrderStatus? status, List<Comment>? comments}) => Order(
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

  String get statusLabel {
    switch (status) {
      case OrderStatus.active:
        return 'Active';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.pending:
        return 'Pending';
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final project = json['project'] as Map<String, dynamic>?;
    final assignedTo = json['assignedTo'] as Map<String, dynamic>?;
    final tmList = (json['tmDetails'] as List<dynamic>?) ?? [];
    final commentList = (json['comments'] as List<dynamic>?) ?? [];

    return Order(
      id: json['orderId'] as String? ?? json['id'] as String? ?? '',
      projectName: project?['projectName'] as String? ?? '',
      status: mapOrderStatus(json['status'] as String?),
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
