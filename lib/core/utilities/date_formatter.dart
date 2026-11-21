import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _shortDate = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');

  static String formatShort(DateTime dt) => _shortDate.format(dt);
  static String formatDateTime(DateTime dt) => _dateTime.format(dt);
}
