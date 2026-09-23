import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/client_api_provider.dart';
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

/// The filter applied to the cube test list.
///
/// Value type with `==` defined on the NORMALISED fields, because it keys a
/// `FutureProvider.family`: without that, an untrimmed keystroke or a different
/// `DateTime` instance for the same day would be a new cache entry and refetch
/// on every rebuild.
class CubeTestFilter {
  const CubeTestFilter({
    this.query = '',
    this.from,
    this.to,
    this.status = CubeTestStatusFilter.all,
  });

  /// Free text — matched server-side against order code, project, site,
  /// product and grade.
  final String query;

  /// Casting-date range.
  final DateTime? from;
  final DateTime? to;

  final CubeTestStatusFilter status;

  bool get hasQuery => query.trim().isNotEmpty;
  bool get hasDate => from != null || to != null;
  bool get hasStatus => status != CubeTestStatusFilter.all;
  bool get isActive => hasQuery || hasDate || hasStatus;

  int get activeCount =>
      (hasQuery ? 1 : 0) + (hasDate ? 1 : 0) + (hasStatus ? 1 : 0);

  CubeTestFilter copyWith({
    String? query,
    DateTime? from,
    DateTime? to,
    CubeTestStatusFilter? status,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return CubeTestFilter(
      query: query ?? this.query,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      status: status ?? this.status,
    );
  }

  CubeTestFilter cleared() => const CubeTestFilter();

  /// The backend only understands ISO `yyyy-MM-dd`; anything else is silently
  /// ignored server-side, so format here rather than at the call site.
  static String? _iso(DateTime? d) {
    if (d == null) return null;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String? get fromIso => _iso(from);
  String? get toIso => _iso(to);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CubeTestFilter &&
          other.query.trim() == query.trim() &&
          other.fromIso == fromIso &&
          other.toIso == toIso &&
          other.status == status;

  @override
  int get hashCode => Object.hash(query.trim(), fromIso, toIso, status);
}

/// Live filter for the Cube Tests screen, shared so the header, the result
/// count and the list all read the same state.
class CubeTestFilterNotifier extends Notifier<CubeTestFilter> {
  @override
  CubeTestFilter build() => const CubeTestFilter();

  void setQuery(String value) => state = state.copyWith(query: value);

  void setStatus(CubeTestStatusFilter status) =>
      state = state.copyWith(status: status);

  void setRange(DateTime? from, DateTime? to) => state = state.copyWith(
    from: from,
    to: to,
    clearFrom: from == null,
    clearTo: to == null,
  );

  void clearDates() => state = state.copyWith(clearFrom: true, clearTo: true);

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
