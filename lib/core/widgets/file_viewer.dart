import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../providers/dio_provider.dart';
import '../providers/storage_providers.dart';
import '../theme/app_colors.dart';

/// Open a server file (an /uploads path, or an API path like the invoice)
/// inside the app: PDFs page by page, photos with pinch-zoom. Never the
/// browser, so the token stays in the header instead of the URL.
Future<void> openServerFile(
  BuildContext context,
  String path, {
  required String title,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => FileViewerPage(path: path, title: title),
  ),
);

class FileViewerPage extends ConsumerStatefulWidget {
  const FileViewerPage({super.key, required this.path, required this.title});

  final String path;
  final String title;

  @override
  ConsumerState<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends ConsumerState<FileViewerPage> {
  PdfControllerPinch? _pdf;
  Uint8List? _image;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await ref.read(secureStorageProvider).read(key: tokenKey);
      // ponytail: a plain Dio, not the app's — that one logs every body and
      // copies GETs into the offline cache, which is wrong for file bytes.
      final dio = Dio(
        BaseOptions(
          baseUrl: ref.read(dioProvider).options.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final res = await dio.get<List<int>>(
        widget.path,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'authorization': ?token},
        ),
      );
      final bytes = Uint8List.fromList(res.data ?? const []);
      // Sniff the bytes: older uploads are served as octet-stream.
      final isPdf =
          bytes.length > 4 && String.fromCharCodes(bytes.take(4)) == '%PDF';
      if (!mounted) return;
      setState(() {
        if (isPdf) {
          _pdf = PdfControllerPinch(document: PdfDocument.openData(bytes));
        } else {
          _image = bytes;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String get _errorText {
    final e = _error;
    if (e is DioException && e.response != null) {
      return e.response!.statusCode == 404
          ? 'This file is no longer on the server.'
          : 'The server would not open this file (${e.response!.statusCode}).';
    }
    return 'Could not load the file. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final pdf = _pdf;
    final image = _image;
    return Scaffold(
      backgroundColor: image != null ? Colors.black : const Color(0xFFEEF1F6),
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (pdf != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: PdfPageNumber(
                  controller: pdf,
                  builder: (_, _, page, count) =>
                      Text(count == null ? '' : '$page / $count'),
                ),
              ),
            ),
        ],
      ),
      body: _error != null
          ? _Message(text: _errorText, onRetry: _load)
          : pdf != null
          ? PdfViewPinch(controller: pdf, padding: 8)
          : image != null
          ? InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: Image.memory(
                  image,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const _Message(
                    text:
                        'This file is not a photo or PDF, so it can\'t be shown here.',
                    dark: true,
                  ),
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry, this.dark = false});

  final String text;
  final VoidCallback? onRetry;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 40,
              color: dark ? Colors.white70 : AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: dark ? Colors.white : AppColors.textMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
