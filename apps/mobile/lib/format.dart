import 'package:intl/intl.dart';

import 'config.dart';

final _money = NumberFormat.simpleCurrency(name: AppConfig.currencyCode);
final _date = DateFormat('d MMM, h:mm a');

String formatMoney(num value) => _money.format(value);

String formatDate(DateTime value) => _date.format(value.toLocal());

String formatTimeLeft(DateTime expiresAt, {DateTime? now}) {
  final left = expiresAt.difference(now ?? DateTime.now());
  if (left.isNegative) return 'Expired';
  if (left.inDays >= 1) return '${left.inDays}d left';
  if (left.inHours >= 1) return '${left.inHours}h left';
  return '${left.inMinutes.clamp(1, 59)}m left';
}
