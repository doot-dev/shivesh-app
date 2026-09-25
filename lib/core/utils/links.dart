import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/dio_provider.dart';
import '../providers/storage_providers.dart';

/// Open a server file or PDF (an /uploads path or an API path) in the browser.
///
/// A browser can't send our Authorization header, so the token rides along as
/// ?token= — the backend accepts it for uploads (P1.9) and the invoice route.
Future<bool> openServerLink(WidgetRef ref, String path) async {
  final token = await ref.read(secureStorageProvider).read(key: tokenKey);
  final sep = path.contains('?') ? '&' : '?';
  final url =
      '$apiBaseUrl$path${token != null ? '${sep}token=${Uri.encodeQueryComponent(token)}' : ''}';
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
