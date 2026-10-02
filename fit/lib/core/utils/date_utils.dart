import 'package:intl/intl.dart';

/// Date helpers. All day-scoped records are keyed by a `yyyy-MM-dd` string
/// produced by [DateKeys.of] so lookups are O(1) Hive key reads.
class DateKeys {
  DateKeys._();

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  /// Returns the storage key (`yyyy-MM-dd`) for the calendar day of [d].
  static String of(DateTime d) => _fmt.format(d);

  /// Parses a `yyyy-MM-dd` key back into a local midnight [DateTime].
  static DateTime parse(String key) => _fmt.parse(key);

  /// Midnight (00:00 local) of the day containing [d].
  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Last instant of the day containing [d].
  static DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// True if [a] and [b] fall on the same calendar day.
  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// The [n] calendar days ending at (and including) [end], oldest first.
  static List<DateTime> lastNDays(DateTime end, int n) =>
      List.generate(n, (i) => startOfDay(end).subtract(Duration(days: n - 1 - i)));

  /// Whole years between [dob] and [now] (used for age-based formulas).
  static int ageFrom(DateTime dob, [DateTime? now]) {
    final n = now ?? DateTime.now();
    var age = n.year - dob.year;
    if (n.month < dob.month || (n.month == dob.month && n.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Human label: "Today", "Yesterday", "Tomorrow" or e.g. "Mon, 3 Jun".
  static String friendly(DateTime d, [DateTime? now]) {
    final today = startOfDay(now ?? DateTime.now());
    final diff = startOfDay(d).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(d);
  }

  /// Formats minutes as "7h 05m".
  static String hm(num minutes) {
    final m = minutes.round();
    final h = m ~/ 60;
    final r = (m % 60).toString().padLeft(2, '0');
    return '${h}h ${r}m';
  }

  /// Formats a time of day as "22:45".
  static String clock(DateTime d) => DateFormat('HH:mm').format(d);
}
