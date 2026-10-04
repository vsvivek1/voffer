import 'package:intl/intl.dart';

final _money = <String, NumberFormat>{};
final _date = DateFormat('d MMM, h:mm a');

/// [value] in [currency], an ISO 4217 code such as INR or USD.
String formatMoney(num value, String currency) => _money
    .putIfAbsent(currency, () => NumberFormat.simpleCurrency(name: currency))
    .format(value);

String formatDate(DateTime value) => _date.format(value.toLocal());

String formatTimeLeft(DateTime expiresAt, {DateTime? now}) {
  final left = expiresAt.difference(now ?? DateTime.now());
  if (left.isNegative) return 'Expired';
  if (left.inDays >= 1) return '${left.inDays}d left';
  if (left.inHours >= 1) return '${left.inHours}h left';
  return '${left.inMinutes.clamp(1, 59)}m left';
}

/// Whether distances show in miles, as in the USA, rather than kilometres.
/// Set from the device's region at startup.
bool useMiles = false;

const kmPerMile = 1.609344;

/// Search radius choices, in kilometres, in round numbers of the current
/// unit.
List<double> get radiusOptionsKm => useMiles
    ? const [1, 3, 5, 15].map((mi) => mi * kmPerMile).toList()
    : const [2.0, 5.0, 10.0, 25.0];

/// The radius the feed starts with.
double get defaultRadiusKm => radiusOptionsKm[2];

String formatRadius(double km) =>
    useMiles ? '${(km / kmPerMile).round()} mi' : '${km.round()} km';

String formatDistance(double km) {
  if (useMiles) {
    final mi = km / kmPerMile;
    if (mi < 0.1) return '0.1 mi';
    if (mi < 10) return '${mi.toStringAsFixed(1)} mi';
    return '${mi.round()} mi';
  }
  if (km < 1) return '${(km * 1000).round().clamp(50, 999) ~/ 50 * 50} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
