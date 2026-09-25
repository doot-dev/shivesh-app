import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Debounced search field for the orders and cube test lists.
///
/// Sits on the brand gradient header, so it is styled as a translucent pill
/// that turns solid white on focus — the app's default InputDecoration is
/// built for light backgrounds and disappears here.
///
/// The debounce is the point: [onQueryChanged] fires ~350ms after typing
/// stops, not on every keystroke, so typing "ORD-2026" makes one request
/// instead of eight.
class OrderSearchBar extends StatefulWidget {
  const OrderSearchBar({
    super.key,
    required this.onQueryChanged,
    this.hintText = 'Search order, project or grade',
  });

  final ValueChanged<String> onQueryChanged;
  final String hintText;

  @override
  State<OrderSearchBar> createState() => _OrderSearchBarState();
}

class _OrderSearchBarState extends State<OrderSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Cancel first: a pending callback after dispose would touch a dead
    // provider scope.
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final has = value.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) widget.onQueryChanged(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _hasText = false);
    widget.onQueryChanged('');
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focused = _focus.hasFocus;

    return AnimatedContainer(
      duration: AppStyles.fast,
      curve: AppStyles.curve,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: focused ? 1 : 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: focused ? 1 : 0.42),
          width: 1.2,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: const Color(0xFF0B1B4D).withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 20,
            color: focused ? AppColors.primary : Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _debounce?.cancel();
                widget.onQueryChanged(v);
              },
              cursorColor: AppColors.primary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: focused ? AppColors.textPrimary : Colors.white,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                // Must be explicit. The global inputDecorationTheme sets
                // filled: true with a WHITE fill; without this override
                // it paints a square-cornered white rectangle inside the
                // translucent pill (only visible when unfocused, because
                // the focused pill is white too).
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.hintText,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: focused
                      ? AppColors.textMuted
                      : Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
          if (_hasText)
            GestureDetector(
              onTap: _clear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: focused ? AppColors.textMuted : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
