import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/access_provider.dart';
import '../../../../core/providers/client_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/file_viewer.dart';
import '../../data/models/cube_test_model.dart';
import '../../providers/cube_test_providers.dart';

/// One order's cube testing reports, as in the field app. Reached from the
/// Cube tests tab and from the order screen.
///
/// Owners and site engineers (cubeTests.manage) log tests, edit them and add
/// result files at any time; other roles only read. There is deliberately no
/// delete-test button: the server does not let a client delete a test.
class OrderCubeTestsPage extends ConsumerWidget {
  const OrderCubeTestsPage({super.key, required this.orderId});

  /// Order code, e.g. ORD-2026-0037.
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(orderCubeTestsProvider(orderId));
    final canManage = ref.can('cubeTests.manage');

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/orders/$orderId/cube-tests/add'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add test'),
            )
          : null,
      body: Column(
        children: [
          CubePageHeader(
            title: 'Cube test reports',
            subtitle: testsAsync.maybeWhen(
              data: (t) => t.isEmpty
                  ? '$orderId · no samples yet'
                  : '$orderId · ${t.length} sample${t.length == 1 ? '' : 's'}',
              orElse: () => orderId,
            ),
          ),
          Expanded(
            child: testsAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  SkeletonCard(lines: 4),
                  SizedBox(height: 14),
                  SkeletonCard(lines: 4),
                ],
              ),
              error: (e, _) => ErrorState(
                message: 'We could not load the cube tests for this order.',
                onRetry: () => ref.invalidate(orderCubeTestsProvider(orderId)),
              ),
              data: (tests) {
                if (tests.isEmpty) {
                  return EmptyState(
                    icon: Icons.science_outlined,
                    title: 'No cube tests yet',
                    message: canManage
                        ? 'Log a cube test when a sample is cast, then attach '
                              'the result sheet once it has been tested.'
                        : 'Reports show here once a test is logged.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(orderCubeTestsProvider(orderId));
                    await ref
                        .read(orderCubeTestsProvider(orderId).future)
                        .catchError((_) => <CubeTest>[]);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    // Bottom padding clears the FAB.
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                    itemCount: tests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => FadeSlideIn(
                      index: i,
                      child: _TestCard(
                        orderId: orderId,
                        test: tests[i],
                        canManage: canManage,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.orderId,
    required this.test,
    required this.canManage,
  });

  final String orderId;
  final CubeTest test;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CubeIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      test.period.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    CubeDueBadge(test: test),
                  ],
                ),
              ),
              if (canManage)
                IconButton(
                  tooltip: 'Edit test',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  onPressed: () => context.push(
                    '/orders/$orderId/cube-tests/edit',
                    extra: test,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          // The title already says the period.
          CubeTestRows(test: test, showPeriod: false),
          const SizedBox(height: 10),
          CubeTestFiles(
            orderId: orderId,
            test: test,
            canAdd: canManage,
            canRemove: canManage,
          ),
        ],
      ),
    );
  }
}

/// The key/value rows of a cube test, same order as the field app's card.
class CubeTestRows extends StatelessWidget {
  const CubeTestRows({
    super.key,
    required this.test,
    this.product = '',
    this.showPeriod = true,
  });

  final CubeTest test;
  final String product;
  final bool showPeriod;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showPeriod)
          DetailRow(
            icon: Icons.timelapse_rounded,
            label: 'Period',
            value: test.period.label,
          ),
        DetailRow(
          icon: Icons.event_outlined,
          label: 'Casting date',
          value: test.castingDateLabel,
        ),
        DetailRow(
          icon: Icons.science_outlined,
          label: 'Testing date',
          value: test.testDateLabel,
        ),
        DetailRow(
          icon: Icons.scale_outlined,
          label: 'Quantity',
          value: test.quantity,
        ),
        if (product.isNotEmpty)
          DetailRow(
            icon: Icons.inventory_2_outlined,
            label: 'Product',
            value: product,
          ),
        if (test.addedAtLabel.isNotEmpty)
          DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Added on',
            value: test.addedAtLabel,
          ),
        if (test.addedByLabel.isNotEmpty)
          DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Logged by',
            value: test.addedByLabel,
          ),
      ],
    );
  }
}

/// A test's result files. Tap one to open it in the app. With [canAdd] more
/// can be added at any time; with [canRemove] the files a client contact added
/// can be removed (the server refuses the lab's and the office's).
class CubeTestFiles extends ConsumerStatefulWidget {
  const CubeTestFiles({
    super.key,
    required this.orderId,
    required this.test,
    this.canAdd = false,
    this.canRemove = false,
  });

  final String orderId;
  final CubeTest test;
  final bool canAdd;
  final bool canRemove;

  @override
  ConsumerState<CubeTestFiles> createState() => _CubeTestFilesState();
}

class _CubeTestFilesState extends ConsumerState<CubeTestFiles> {
  bool _busy = false;

  Future<void> _add() async {
    final files = await pickCubeTestFiles(context);
    if (files.isEmpty || !mounted) return;
    await _run(
      () => ref
          .read(clientApiProvider)
          .saveCubeTest(
            widget.orderId,
            cubeTestId: widget.test.id,
            files: files,
          ),
      '${files.length} file${files.length == 1 ? '' : 's'} added',
    );
  }

  Future<void> _remove(CubeTestAttachment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this file?'),
        content: Text(a.displayName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerFg),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => ref
          .read(clientApiProvider)
          .deleteCubeTestAttachment(widget.orderId, widget.test.id, a.id),
      'File removed',
    );
  }

  Future<void> _run(Future<void> Function() call, String done) async {
    // Taken before the await: the card can be rebuilt or gone by the time the
    // upload finishes, and both lists must still refresh.
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    try {
      await call();
      refreshCubeTests(container, widget.orderId);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(cubeTestErrorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = widget.test.attachments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'Files',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (files.isNotEmpty) ...[
              const SizedBox(width: 6),
              CountBubble(files.length),
            ],
            const Spacer(),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (widget.canAdd)
              TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Add files'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (files.isEmpty)
          _FileTile(
            icon: Icons.hourglass_empty_rounded,
            title: 'No report attached yet',
            muted: true,
          )
        else
          for (final a in files)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _FileTile(
                icon: a.displayName.toLowerCase().endsWith('.pdf')
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_rounded,
                title: a.displayName,
                subtitle: a.subtitle,
                onTap: () =>
                    openServerFile(context, a.fileUrl, title: a.displayName),
                onRemove: widget.canRemove && a.addedByClient && a.id.isNotEmpty
                    ? () => _remove(a)
                    : null,
              ),
            ),
      ],
    );
  }
}

/// One file row: name (ellipsised, never overflowing), who added it, and a
/// remove button or a chevron.
class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.muted = false,
    this.onTap,
    this.onRemove,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool muted;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = muted ? AppColors.textMuted : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: EdgeInsets.fromLTRB(12, 6, onRemove == null ? 10 : 0, 6),
        decoration: BoxDecoration(
          color: muted ? AppColors.background : AppColors.infoBg,
          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg,
                      fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Remove file',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.dangerFg,
                ),
                onPressed: onRemove,
              )
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}

/// Pick result files (PDF, JPG, PNG). Files over the server's 10 MB limit are
/// skipped with a message, and at most [max] come back (the server takes 10
/// per request).
Future<List<({String path, String name})>> pickCubeTestFiles(
  BuildContext context, {
  int max = 10,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final res = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    allowMultiple: true,
  );
  final picked = (res?.files ?? const <PlatformFile>[])
      .where((f) => f.path != null)
      .toList();
  final ok = picked.where((f) => f.size <= 10 * 1024 * 1024).toList();
  final note = ok.length > max
      ? 'Up to $max files at a time'
      : ok.length < picked.length
      ? 'Files over 10 MB were skipped'
      : null;
  if (note != null) messenger.showSnackBar(SnackBar(content: Text(note)));
  return [for (final f in ok.take(max)) (path: f.path!, name: f.name)];
}

/// The server's own message (date rules, "your role doesn't allow this" …),
/// else a friendly fallback.
String cubeTestErrorText(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (e.response == null) {
      return 'No connection — try again when you are online';
    }
  }
  return 'Something went wrong — please try again';
}

/// Gradient header with a back button, matching the Cube tests tab.
class CubePageHeader extends StatelessWidget {
  const CubePageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppStyles.radiusXl),
          bottomRight: Radius.circular(AppStyles.radiusXl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 18),
          child: Row(
            children: [
              const BackButton(color: Colors.white),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The science-flask tile at the start of every cube test card.
class CubeIcon extends StatelessWidget {
  const CubeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppStyles.radiusMd),
      ),
      child: const Icon(
        Icons.science_rounded,
        size: 20,
        color: AppColors.primary,
      ),
    );
  }
}

/// Whether the scheduled test date has arrived. Shared by both cube test lists.
class CubeDueBadge extends StatelessWidget {
  const CubeDueBadge({super.key, required this.test});

  final CubeTest test;

  @override
  Widget build(BuildContext context) {
    final days = test.daysUntilDue;
    if (days > 0) return StatusBadge('in $days day${days == 1 ? '' : 's'}');
    if (days == 0) return const StatusBadge('Due today', tone: Tone.warn);
    return const StatusBadge('Tested', tone: Tone.ok);
  }
}
