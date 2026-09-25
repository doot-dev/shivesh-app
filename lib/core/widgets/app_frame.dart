import 'package:flutter/material.dart';

import '../network/offline_cache.dart';
import '../theme/app_colors.dart';

/// Wraps every screen (MaterialApp.builder), so no page has to handle it:
///
///  - Edge to edge on every size: phones, a Fold's cover and inner screens,
///    tablets. Nothing is letterboxed; pages stretch to the width they get.
///  - Very large system font sizes are capped, so a phone set to the largest
///    font does not push rows off a small screen (Fold cover screen ~300dp).
///  - While the network is down and screens show saved data, a strip says so.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // The widget tree keeps the same shape online and offline: changing it
    // would remount the Navigator and drop the user's screen.
    return ValueListenableBuilder<bool>(
      valueListenable: offlineNotifier,
      builder: (context, offline, _) {
        // The strip takes the status-bar inset, so screens must not add it again.
        final data = offline ? mq.removePadding(removeTop: true) : mq;
        return Column(
          children: [
            if (offline) const _OfflineStrip(),
            Expanded(
              key: const ValueKey('app'),
              child: MediaQuery(
                data: data.copyWith(
                  textScaler: data.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.3,
                  ),
                ),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textPrimary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Offline — showing saved data',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
