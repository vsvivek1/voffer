import 'package:geolocator/geolocator.dart';

import '../models/shop.dart';

class LocationException implements Exception {
  LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Finds where the device is. Swapped for a fake in tests.
abstract class LocationService {
  /// The device's position, asking for permission if needed. Throws
  /// [LocationException] when location is off or permission is refused.
  Future<GeoPoint> current();
}

/// Used when no location provider is wired up: always asks the user to pick
/// a city instead.
class NoLocationService implements LocationService {
  const NoLocationService();

  @override
  Future<GeoPoint> current() async =>
      throw LocationException('Location is not available on this device.');
}

class FixedLocationService implements LocationService {
  const FixedLocationService(this.point);
  final GeoPoint point;

  @override
  Future<GeoPoint> current() async => point;
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  @override
  Future<GeoPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Turn on location to see offers near you.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationException('Location permission was not given.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return GeoPoint(position.latitude, position.longitude);
  }
}
