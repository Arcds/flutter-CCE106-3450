import 'package:intl/intl.dart';

/// Date keys use the venue-local calendar day, e.g. `2026-11-27`.
String dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

String shortDate(DateTime date) => DateFormat('EEE, MMM d').format(date);

String weekdayShort(DateTime date) => DateFormat('EEE').format(date);

String dayNumber(DateTime date) => DateFormat('d').format(date);

String hourLabel(int hour) {
  final normalized = hour % 24;
  final suffix = normalized < 12 ? 'AM' : 'PM';
  final display = normalized % 12 == 0 ? 12 : normalized % 12;
  return '$display:00 $suffix';
}

String timeRangeLabel(int startHour, int durationHours) =>
    '${hourLabel(startHour)} – ${hourLabel(startHour + durationHours)}';

String peso(num amount) => '₱${NumberFormat('#,##0').format(amount)}';

String countdownLabel(Duration remaining) {
  if (remaining.isNegative) return 'Expired';
  final minutes = remaining.inMinutes;
  final seconds = remaining.inSeconds % 60;
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m left';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')} left';
}

DateTime slotStart(String date, int startHour) =>
    DateTime.parse('$date ${startHour.toString().padLeft(2, '0')}:00:00');
