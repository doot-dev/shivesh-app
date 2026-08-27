import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/client_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/order_date_rules.dart';
import '../../../home/data/models/home_models.dart';
import '../../../home/providers/home_providers.dart';
import '../../../orders/providers/orders_providers.dart';
import '../../providers/create_order_providers.dart';

class CreateOrderPage extends ConsumerStatefulWidget {
  const CreateOrderPage({super.key});

  @override
  ConsumerState<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends ConsumerState<CreateOrderPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedProjectName;
  String? _selectedProjectId;
  String? _selectedProduct;
  String? _selectedGrade;

  final _projectFieldKey = GlobalKey<FormFieldState<String>>();
  final _productFieldKey = GlobalKey<FormFieldState<String>>();
  final _gradeFieldKey = GlobalKey<FormFieldState<String>>();

  final _quantityController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // Orders can only be booked up to 3 months out, so the calendar greys out
    // anything beyond that rather than letting the server reject it later.
    final first = startOfToday();
    final last = maxOrderDate();
    final current = _selectedDate;
    final initial = (current != null && isOrderDateAllowed(current))
        ? current
        : first;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Select delivery date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _openBottomSheet({
    required String title,
    required List<String> items,
    required String? currentValue,
    required void Function(String) onSelected,
    required GlobalKey<FormFieldState<String>> fieldKey,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchableBottomSheet(
        title: title,
        items: items,
        selectedValue: currentValue,
      ),
    );
    if (result != null) {
      onSelected(result);
      fieldKey.currentState?.didChange(result);
    }
  }

  Future<void> _selectProject(List<ProjectSummary> projects) async {
    final names = projects.map((p) => p.name).toList();
    await _openBottomSheet(
      title: 'Select Project',
      items: names,
      currentValue: _selectedProjectName,
      onSelected: (name) {
        final project = projects.firstWhere((p) => p.name == name);
        setState(() {
          _selectedProjectName = name;
          _selectedProjectId = project.id;
          // Reset downstream selections when project changes
          _selectedProduct = null;
          _selectedGrade = null;
          _productFieldKey.currentState?.didChange(null);
          _gradeFieldKey.currentState?.didChange(null);
        });
      },
      fieldKey: _projectFieldKey,
    );
  }

  Future<void> _selectProduct(List<String> products) async {
    await _openBottomSheet(
      title: 'Select Product',
      items: products,
      currentValue: _selectedProduct,
      onSelected: (v) => setState(() {
        if (v != _selectedProduct) {
          _selectedProduct = v;
          _selectedGrade = null;
          _gradeFieldKey.currentState?.didChange(null);
        }
      }),
      fieldKey: _productFieldKey,
    );
  }

  Future<void> _selectGrade(List<String> grades) async {
    await _openBottomSheet(
      title: 'Select Grade',
      items: grades,
      currentValue: _selectedGrade,
      onSelected: (v) => setState(() => _selectedGrade = v),
      fieldKey: _gradeFieldKey,
    );
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedDate == null) {
      _showSnack('Please select a delivery date');
      return;
    }
    // Belt and braces: the picker already caps the range, but a date chosen
    // before midnight rolled over can fall out of the window while the form
    // is still open.
    if (!isOrderDateAllowed(_selectedDate!)) {
      _showSnack(
        'Orders can only be booked up to $kMaxOrderMonthsAhead months ahead '
        '(latest ${DateFormat('MMM dd, yyyy').format(maxOrderDate())})',
      );
      return;
    }
    if (_selectedTime == null) {
      _showSnack('Please select a delivery time');
      return;
    }

    if (_selectedProjectId == null) {
      _showSnack('Please select a project');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final timeStr = _selectedTime!.format(context);

      await ref
          .read(clientApiProvider)
          .createOrder(
            projectId: _selectedProjectId!,
            productName: _selectedProduct!,
            productGrade: _selectedGrade!,
            quantity: '${_quantityController.text.trim()} m3',
            date: dateStr,
            time: timeStr,
          );

      ref.invalidate(activeOrdersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed successfully!'),
            backgroundColor: AppColors.accent,
          ),
        );
        context.pop();
      }
    } on DioException catch (e) {
      final msg =
          (e.response?.data as Map?)?['message'] as String? ??
          'Failed to place order';
      _showSnack(msg);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final projectProductsAsync = _selectedProjectId != null
        ? ref.watch(projectProductsProvider(_selectedProjectId!))
        : null;

    // Derive product names and grades from the project-specific product list
    final productNames = projectProductsAsync?.value
        ?.map((p) => p.productName)
        .toSet()
        .toList();
    final gradeOptions =
        (_selectedProduct != null && projectProductsAsync?.value != null)
        ? projectProductsAsync!.value!
              .where((p) => p.productName == _selectedProduct)
              .map((p) => p.productGrade)
              .toList()
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text('Create Order'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            // ── Project Name ──────────────────────────────────────────────
            _FieldLabel('Project Name'),
            const SizedBox(height: 8),
            projectsAsync.when(
              loading: () => const _LoadingField(),
              error: (_, __) => const _ErrorField('Failed to load projects'),
              data: (projects) => _SelectableField(
                fieldKey: _projectFieldKey,
                value: _selectedProjectName,
                hint: 'Select project',
                onTap: () => _selectProject(projects),
                validator: (v) => v == null ? 'Please select a project' : null,
              ),
            ),
            const SizedBox(height: 20),

            // ── Product Name ──────────────────────────────────────────────
            _FieldLabel('Product Name'),
            const SizedBox(height: 8),
            // NOTE: both branches below must share ONE _SelectableField, not two.
            // Giving the same GlobalKey to two widgets in different branches
            // throws "Duplicate GlobalKey detected in widget tree" while Flutter
            // holds the outgoing element during the swap, which breaks the form.
            if (_selectedProjectId != null && projectProductsAsync!.isLoading)
              const _LoadingField()
            else if (_selectedProjectId != null &&
                projectProductsAsync!.hasError)
              const _ErrorField('Failed to load products')
            else
              _SelectableField(
                fieldKey: _productFieldKey,
                value: _selectedProjectId == null ? null : _selectedProduct,
                hint: _selectedProjectId == null
                    ? 'Select a project first'
                    : 'Select product',
                onTap: _selectedProjectId == null
                    ? null
                    : () => _selectProduct(productNames ?? []),
                enabled: _selectedProjectId != null,
                validator: (v) => v == null ? 'Please select a product' : null,
              ),
            const SizedBox(height: 20),

            // ── Product Grade ─────────────────────────────────────────────
            _FieldLabel('Product Grade'),
            const SizedBox(height: 8),
            // Single field for both states — see the GlobalKey note above.
            if (_selectedProduct == null || gradeOptions != null)
              _SelectableField(
                fieldKey: _gradeFieldKey,
                value: _selectedProduct == null ? null : _selectedGrade,
                hint: _selectedProduct != null
                    ? 'Select grade'
                    : _selectedProjectId == null
                        ? 'Select a project first'
                        : 'Select a product first',
                onTap: _selectedProduct == null || gradeOptions == null
                    ? null
                    : () => _selectGrade(gradeOptions),
                enabled: _selectedProduct != null && gradeOptions != null,
                validator: (v) =>
                    v == null ? 'Please select a product grade' : null,
              ),
            const SizedBox(height: 20),

            // ── Quantity ──────────────────────────────────────────────────
            _FieldLabel('Quantity'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Enter quantity in m3',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter quantity';
                }
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Date ──────────────────────────────────────────────────────
            _FieldLabel('Date'),
            const SizedBox(height: 8),
            _TappableField(
              value: _selectedDate != null
                  ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                  : null,
              hint: 'Select date',
              icon: Icons.calendar_today_outlined,
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Orders can be booked up to $kMaxOrderMonthsAhead months ahead '
                    '(till ${DateFormat('MMM dd, yyyy').format(maxOrderDate())})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _QuickSelectRow(
              options: const ['Today', 'Tomorrow'],
              onSelected: (label) {
                final now = DateTime.now();
                setState(() {
                  _selectedDate = label == 'Today'
                      ? DateTime(now.year, now.month, now.day)
                      : DateTime(now.year, now.month, now.day + 1);
                });
              },
              isSelected: (label) {
                if (_selectedDate == null) return false;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final tomorrow = DateTime(now.year, now.month, now.day + 1);
                if (label == 'Today') {
                  return _selectedDate == today;
                }
                return _selectedDate == tomorrow;
              },
            ),
            const SizedBox(height: 20),

            // ── Time ──────────────────────────────────────────────────────
            _FieldLabel('Time'),
            const SizedBox(height: 8),
            _TappableField(
              value: _selectedTime?.format(context),
              hint: 'Select time',
              icon: Icons.access_time_outlined,
              onTap: _pickTime,
            ),
            const SizedBox(height: 10),
            _QuickSelectRow(
              options: const ['9:00 AM', '10:00 AM', '1:00 PM', '4:00 PM'],
              onSelected: (label) {
                const timeMap = {
                  '9:00 AM': TimeOfDay(hour: 9, minute: 0),
                  '10:00 AM': TimeOfDay(hour: 10, minute: 0),
                  '1:00 PM': TimeOfDay(hour: 13, minute: 0),
                  '4:00 PM': TimeOfDay(hour: 16, minute: 0),
                };
                setState(() => _selectedTime = timeMap[label]);
              },
              isSelected: (label) {
                if (_selectedTime == null) return false;
                const timeMap = {
                  '9:00 AM': TimeOfDay(hour: 9, minute: 0),
                  '10:00 AM': TimeOfDay(hour: 10, minute: 0),
                  '1:00 PM': TimeOfDay(hour: 13, minute: 0),
                  '4:00 PM': TimeOfDay(hour: 16, minute: 0),
                };
                final t = timeMap[label];
                return t != null &&
                    _selectedTime!.hour == t.hour &&
                    _selectedTime!.minute == t.minute;
              },
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Place order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ─── Selectable field (opens bottom sheet) ────────────────────────────────────

class _SelectableField extends StatelessWidget {
  const _SelectableField({
    required this.fieldKey,
    required this.value,
    required this.hint,
    required this.onTap,
    this.validator,
    this.enabled = true,
  });

  final GlobalKey<FormFieldState<String>> fieldKey;
  final String? value;
  final String hint;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: fieldKey,
      initialValue: value,
      validator: validator,
      builder: (field) {
        return GestureDetector(
          onTap: enabled ? onTap : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: enabled ? Colors.white : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: field.hasError
                        ? Colors.red.shade400
                        : AppColors.border,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        field.value ?? hint,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: field.value != null
                              ? AppColors.textPrimary
                              : (enabled
                                    ? AppColors.textMuted
                                    : AppColors.border),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: enabled ? AppColors.textMuted : AppColors.border,
                      size: 22,
                    ),
                  ],
                ),
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 14, top: 6),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Loading / error placeholder fields ──────────────────────────────────────

class _LoadingField extends StatelessWidget {
  const _LoadingField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: const Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ErrorField extends StatelessWidget {
  const _ErrorField(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade200, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(color: Colors.red.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Tappable field (date / time) ─────────────────────────────────────────────

class _TappableField extends StatelessWidget {
  const _TappableField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value ?? hint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: value != null
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
              ),
            ),
            Icon(icon, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Quick-select bubble row ──────────────────────────────────────────────────

class _QuickSelectRow extends StatelessWidget {
  const _QuickSelectRow({
    required this.options,
    required this.onSelected,
    required this.isSelected,
  });

  final List<String> options;
  final void Function(String) onSelected;
  final bool Function(String) isSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((label) {
        final selected = isSelected(label);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelected(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 1.2,
                ),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Searchable bottom sheet ───────────────────────────────────────────────────

class _SearchableBottomSheet extends StatefulWidget {
  const _SearchableBottomSheet({
    required this.title,
    required this.items,
    this.selectedValue,
  });

  final String title;
  final List<String> items;
  final String? selectedValue;

  @override
  State<_SearchableBottomSheet> createState() => _SearchableBottomSheetState();
}

class _SearchableBottomSheetState extends State<_SearchableBottomSheet> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items
        .where((item) => item.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: AppColors.textMuted,
                              size: 18,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Items list
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No results found',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 24,
                          endIndent: 24,
                          color: AppColors.border,
                        ),
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          final isSelected = item == widget.selectedValue;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 4,
                            ),
                            title: Text(
                              item,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
