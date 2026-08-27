/// Booking-window rules for delivery dates.
///
/// Business rule: an order cannot be scheduled more than 3 calendar months
/// into the future. The backend is the authority (it rejects out-of-window
/// dates with 400); this exists so the picker can't offer an invalid date in
/// the first place and the user gets an inline message instead of a failed
/// request.
///
/// Kept in sync with `src/helper/deliveryDateHelper.js` on the server —
/// including the month-end clamping, which is the easy part to get wrong.
library;

/// How far ahead an order may be booked.
const int kMaxOrderMonthsAhead = 3;

/// Add whole calendar months, clamping to the last valid day of the target
/// month.
///
/// GOTCHA: `DateTime(y, m + 3, d)` does NOT do this — it normalises overflow,
/// so 30 Nov + 3 months becomes 2 March rather than 28 Feb, which would let the
/// picker offer two days past the cap that the server then rejects.
DateTime addMonthsClamped(DateTime date, int months) {
  final target = date.month - 1 + months;
  final year = date.year + (target ~/ 12);
  final month = (target % 12) + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day < lastDay ? date.day : lastDay);
}

/// Midnight today, with the time component stripped so comparisons are by day.
DateTime startOfToday([DateTime? now]) {
  final n = now ?? DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// The latest delivery date a user may currently pick.
DateTime maxOrderDate([DateTime? now]) =>
    addMonthsClamped(startOfToday(now), kMaxOrderMonthsAhead);

/// Whether [date] falls inside the bookable window (today .. +3 months).
bool isOrderDateAllowed(DateTime date, [DateTime? now]) {
  final day = DateTime(date.year, date.month, date.day);
  return !day.isBefore(startOfToday(now)) && !day.isAfter(maxOrderDate(now));
}
