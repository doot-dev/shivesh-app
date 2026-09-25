import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
import '../../../core/widgets/month_bar.dart';
import '../data/models/cube_test_model.dart';

/// Which cube tests to show on the "Cube Tests" tab.
///
/// `all` is everything, `due` is tests whose date has arrived (results the
/// client can expect), `upcoming` is still scheduled.
enum CubeTestStatusFilter { all, due, upcoming }

extension CubeTestStatusFilterX on CubeTestStatusFilter {
  /// Wire value for the `status` query param. Null for [all] — the backend
  /// treats a missing param as no filter.
  String? get apiValue {
    switch (this) {
      case CubeTestStatusFilter.all:
        return null;
      case CubeTestStatusFilter.due:
        return 'due';
      case CubeTestStatusFilter.upcoming:
        return 'upcoming';
    }
  }

  String get label {
    switch (this) {
      case CubeTestStatusFilter.all:
        return 'All';
      case CubeTestStatusFilter.due:
        return 'Tested';
      case CubeTestStatusFilter.upcoming:
        return 'Scheduled';
    }
  }
}

/// The filter applied to the cube test list: search text, status and the
/// casting month (defaults to this month).
///
/// Value type with `==` defined on the NORMALISED fields, because it keys a
/// `FutureProvider.family`: without that, an untrimmed keystroke would be a
/// new cache entry and refetch on every rebuild.
class CubeTestFilter {
  CubeTestFilter({
    this.query = '',
    DateTime? month,
    this.status = CubeTestStatusFilter.all,
  }) : month = monthOf(month ?? DateTime.now());

  /// Free text — matched server-side against order code, project, site,
  /// product and grade.
  final String query;

  /// First day of the casting month shown.
  final DateTime month;

  final CubeTestStatusFilter status;

  bool get hasQuery => query.trim().isNotEmpty;
  bool get hasStatus => status != CubeTestStatusFilter.all;

  /// The month always applies, so "filtered" means search or status.
  bool get isActive => hasQuery || hasStatus;

  CubeTestFilter copyWith({
    String? query,
    DateTime? month,
    CubeTestStatusFilter? status,
  }) => CubeTestFilter(
    query: query ?? this.query,
    month: month ?? this.month,
    status: status ?? this.status,
  );

  /// Drop search and status, keep the month.
  CubeTestFilter cleared() => CubeTestFilter(month: month);

  String get fromIso => monthFromIso(month);
  String get toIso => monthToIso(month);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CubeTestFilter &&
          other.query.trim() == query.trim() &&
          other.month == month &&
          other.status == status;

  @override
  int get hashCode => Object.hash(query.trim(), month, status);
}

/// Live filter for the Cube Tests screen, shared so the header, the result
/// count and the list all read the same state.
class CubeTestFilterNotifier extends Notifier<CubeTestFilter> {
  @override
  CubeTestFilter build() => CubeTestFilter();

  void setQuery(String value) => state = state.copyWith(query: value);

  void setStatus(CubeTestStatusFilter status) =>
      state = state.copyWith(status: status);

  void setMonth(DateTime month) => state = state.copyWith(month: month);

  void clear() => state = state.cleared();
}

final cubeTestFilterProvider =
    NotifierProvider<CubeTestFilterNotifier, CubeTestFilter>(
      CubeTestFilterNotifier.new,
    );

/// Every cube test across this client's orders, server-filtered.
///
/// Filtering is server-side rather than in the list so a client with hundreds
/// of samples is not downloading all of them just to hide most.
final allCubeTestsProvider =
    FutureProvider.family<List<CubeTestEntry>, CubeTestFilter>((ref, filter) {
      return ref
          .read(clientApiProvider)
          .getAllCubeTests(
            query: filter.query,
            dateFrom: filter.fromIso,
            dateTo: filter.toIso,
            status: filter.status.apiValue,
          );
    });
