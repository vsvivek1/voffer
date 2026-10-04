import 'dart:math';

import 'market.dart';

/// A point on the map, in degrees.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// Great-circle distance to [other] in kilometres.
  double distanceKmTo(GeoPoint other) {
    const earthRadiusKm = 6371.0;
    double rad(double deg) => deg * pi / 180;
    final dLat = rad(other.lat - lat);
    final dLng = rad(other.lng - lng);
    final a =
        pow(sin(dLat / 2), 2) +
        cos(rad(lat)) * cos(rad(other.lat)) * pow(sin(dLng / 2), 2);
    return 2 * earthRadiusKm * asin(sqrt(a));
  }
}

/// A firm's shop. It shares its id with the firm's account.
class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.location,
    this.phone,
    this.hours,
    this.logoUrl,
    this.country = Country.india,
  });

  final String id;
  final String name;
  final String category;
  final String address;
  final GeoPoint location;
  final String? phone;

  /// Free text such as "Mon–Sat, 9am–9pm".
  final String? hours;
  final String? logoUrl;
  final Country country;

  factory Shop.fromMap(Map<String, dynamic> map) => Shop(
    id: map['id'] as String,
    name: map['name'] as String,
    category: (map['category'] ?? 'Other') as String,
    address: map['address'] as String,
    location: GeoPoint(
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
    ),
    phone: map['phone'] as String?,
    hours: map['hours'] as String?,
    logoUrl: map['logo_url'] as String?,
    country: Country.fromCode(map['country'] as String?),
  );
}

/// Fields a firm fills in when setting up or editing its shop.
class ShopDetails {
  const ShopDetails({
    required this.name,
    required this.category,
    required this.address,
    required this.location,
    this.phone,
    this.hours,
    this.logoUrl,
    this.country = Country.india,
  });

  final String name;
  final String category;
  final String address;
  final GeoPoint location;
  final String? phone;
  final String? hours;
  final String? logoUrl;
  final Country country;
}

/// Places a customer can pick when they don't share their location.
const citiesByCountry = <Country, Map<String, GeoPoint>>{
  Country.india: indiaCities,
  Country.usa: usaCities,
};

const cities = <String, GeoPoint>{...indiaCities, ...usaCities};

const indiaCities = <String, GeoPoint>{
  'Kochi': GeoPoint(9.9312, 76.2673),
  'Thiruvananthapuram': GeoPoint(8.5241, 76.9366),
  'Kozhikode': GeoPoint(11.2588, 75.7804),
  'Bengaluru': GeoPoint(12.9716, 77.5946),
  'Chennai': GeoPoint(13.0827, 80.2707),
  'Hyderabad': GeoPoint(17.3850, 78.4867),
  'Mumbai': GeoPoint(19.0760, 72.8777),
  'Delhi': GeoPoint(28.6139, 77.2090),
};

const usaCities = <String, GeoPoint>{
  'New York': GeoPoint(40.7128, -74.0060),
  'Los Angeles': GeoPoint(34.0522, -118.2437),
  'Chicago': GeoPoint(41.8781, -87.6298),
  'Houston': GeoPoint(29.7604, -95.3698),
  'Dallas': GeoPoint(32.7767, -96.7970),
  'San Francisco': GeoPoint(37.7749, -122.4194),
  'Seattle': GeoPoint(47.6062, -122.3321),
  'Miami': GeoPoint(25.7617, -80.1918),
};
