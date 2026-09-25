import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/client_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../orders/providers/orders_providers.dart';
import '../../data/models/cube_test_model.dart';
import '../../providers/cube_test_providers.dart';
import 'order_cube_tests_page.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
final _apiDate = DateFormat('yyyy-MM-dd');

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
bool _sameDay(DateTime a, DateTime b) => _day(a) == _day(b);

/// Log a cube test on an order, or edit one ([test] set) — at any time, like
/// the field app's form. Files picked here upload with the save; more can be
/// added later from the card.
///
/// The server owns the date rules (casting not in the future and not before
/// the delivery date; a custom test date not in the future and not before
/// casting). The pickers only offer dates it accepts, and its message is shown
/// if it still refuses.
class CubeTestFormPage extends ConsumerStatefulWidget {
  const CubeTestFormPage({super.key, required this.orderId, this.test});

  final String orderId;
  final CubeTest? test;

  @override
  ConsumerState<CubeTestFormPage> createState() => _CubeTestFormPageState();
}

class _CubeTestFormPageState extends ConsumerState<CubeTestFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _quantity = TextEditingController(text: widget.test?.quantity);
  late DateTime _casting = _day(widget.test?.castingDate ?? DateTime.now());
  late CubeTestPeriod _period = widget.test?.period ?? CubeTestPeriod.sevenDays;
  late DateTime? _custom = widget.test?.period == CubeTestPeriod.custom
      ? _day(widget.test!.toDate)
      : null;

  /// The order's delivery date, once loaded: the earliest casting date.
  DateTime? _delivery;
  bool _castingPicked = false;
  final _files = <({String path, String name})>[];
  bool _saving = false;

  bool get _editing => widget.test != null;

  @override
  void initState() {
    super.initState();
    // New test: cast on the delivery date, unless that is still ahead.
    ref.read(orderByIdProvider(widget.orderId).future).then((order) {
      final d = DateTime.tryParse(order?.date ?? '');
      if (d == null || !mounted) return;
      setState(() {
        _delivery = d;
        if (!_editing && !_castingPicked && !d.isAfter(DateTime.now())) {
          _casting = d;
        }
      });
    });
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  DateTime? get _testDate => _period == CubeTestPeriod.custom
      ? _custom
      : _casting.add(Duration(days: _period.days!));

  /// A past-or-today date from [first]; clamps so the picker never asserts.
  Future<DateTime?> _pickDate(DateTime initial, DateTime first, String help) {
    final last = _day(DateTime.now());
    if (first.isAfter(last)) first = last;
    return showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
      helpText: help,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _pickCasting() async {
    final d = await _pickDate(
      _casting,
      _delivery ?? DateTime(DateTime.now().year - 2),
      'Casting date',
    );
    if (d == null) return;
    setState(() {
      _casting = d;
      _castingPicked = true;
      if (_custom != null && _custom!.isBefore(d)) _custom = null;
    });
  }

  Future<void> _pickCustom() async {
    final d = await _pickDate(_custom ?? DateTime.now(), _casting, 'Test date');
    if (d != null) setState(() => _custom = d);
  }

  Future<void> _addFiles() async {
    final picked = await pickCubeTestFiles(context, max: 10 - _files.length);
    if (picked.isNotEmpty) setState(() => _files.addAll(picked));
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final custom = _period == CubeTestPeriod.custom;
    if (custom && _custom == null) {
      _toast('Pick the test date for a custom period.');
      return;
    }

    // An edit sends only what changed, so adding a file to an old test never
    // re-checks dates nobody touched.
    final t = widget.test;
    final castingChanged = t == null || !_sameDay(_casting, t.castingDate);
    final periodChanged = t == null || _period != t.period;
    final quantity = _quantity.text.trim();
    final fields = <String, String>{
      if (castingChanged) 'castingDate': _apiDate.format(_casting),
      if (periodChanged) 'period': _period.apiValue,
      if (custom &&
          (castingChanged || periodChanged || !_sameDay(_custom!, t.toDate)))
        'customDate': _apiDate.format(_custom!),
      if (t == null || quantity != t.quantity) 'quantity': quantity,
    };
    if (fields.isEmpty && _files.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _saving = true);
    try {
      await ref
          .read(clientApiProvider)
          .saveCubeTest(
            widget.orderId,
            cubeTestId: t?.id,
            fields: fields,
            files: _files,
          );
      refreshCubeTests(container, widget.orderId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(t == null ? 'Cube test added' : 'Changes saved'),
        ),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(cubeTestErrorText(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final testDate = _testDate;
    // Old rows may carry 14/21 days: keep that chip so the choice shows.
    final periods = {...selectableCubeTestPeriods, ?widget.test?.period};
    // Live copy of the test being edited, so a removed file drops out at once.
    final live = _editing
        ? ref
                  .watch(orderCubeTestsProvider(widget.orderId))
                  .value
                  ?.where((t) => t.id == widget.test!.id)
                  .firstOrNull ??
              widget.test
        : null;
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textMuted,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          CubePageHeader(
            title: _editing ? 'Edit cube test' : 'Add cube test',
            subtitle: widget.orderId,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _Section(
                    title: 'Sample info',
                    children: [
                      const _Label('Casting date'),
                      _PickerField(
                        value: _dateFmt.format(_casting),
                        icon: Icons.calendar_today_outlined,
                        onTap: _pickCasting,
                      ),
                      const SizedBox(height: 16),
                      const _Label('Quantity'),
                      TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Number of cubes, e.g. 6',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter the number of cubes'
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Testing period',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in periods)
                            ChoiceChip(
                              label: Text(p.label),
                              selected: _period == p,
                              showCheckmark: false,
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: _period == p
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                              labelStyle: theme.textTheme.labelMedium?.copyWith(
                                color: _period == p
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) => setState(() => _period = p),
                            ),
                        ],
                      ),
                      if (_period == CubeTestPeriod.custom) ...[
                        const SizedBox(height: 16),
                        const _Label('Test date'),
                        _PickerField(
                          value: _custom == null
                              ? null
                              : _dateFmt.format(_custom!),
                          hint: 'Select test date',
                          icon: Icons.event_outlined,
                          onTap: _pickCustom,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A custom date records a test that has already '
                          'happened, so it cannot be in the future.',
                          style: muted,
                        ),
                      ] else if (testDate != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.infoBg,
                            borderRadius: BorderRadius.circular(
                              AppStyles.radiusSm,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Testing date: ${_dateFmt.format(testDate)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (live != null)
                          CubeTestFiles(
                            orderId: widget.orderId,
                            test: live,
                            canRemove: true,
                          )
                        else
                          Text(
                            'Files',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 8),
                        for (final (i, f) in _files.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.upload_file_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: "Don't upload",
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () =>
                                      setState(() => _files.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                        if (_files.length < 10)
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _addFiles,
                            icon: const Icon(Icons.attach_file_rounded),
                            label: Text(
                              _editing ? 'Add more files' : 'Add files',
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'Result sheets or photos: PDF, JPG or PNG up to '
                          '10 MB each. You can add more at any time.',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_editing ? 'Save changes' : 'Save test'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Tap-to-pick date field, styled like the create-order date field.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.icon,
    required this.onTap,
    this.hint = '',
  });

  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
