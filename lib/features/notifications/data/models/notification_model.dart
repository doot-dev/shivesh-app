String _fmtNotifTime(String? iso) {
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

class AppNotification {
  const AppNotification({
    required this.id,
    required this.message,
    required this.time,
    this.isRead = false,
  });

  final String id;
  final String message;
  final String time;
  final bool isRead;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String? ?? '',
        message: json['message'] as String? ?? json['title'] as String? ?? '',
        time: _fmtNotifTime(json['createdAt'] as String?),
        isRead: json['isRead'] as bool? ?? false,
      );
}
